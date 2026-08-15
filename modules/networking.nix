{ config, pkgs, lib, ... }:

let
  name = config.vtt.common.userName;
in {
  # Core networking configuration
  networking = {
    hostId = "8821e309";
    hostName = name;
    useNetworkd = true;
    
    # Disable wireless client mode since we're setting up as AP
    wireless = {
      enable = false;
      iwd.enable = false;
    };
    
    # Enable IP forwarding for internet sharing
    nat = {
      enable = true;
      externalInterface = "end0";  # Raspberry Pi 5 ethernet interface
      internalInterfaces = [ "wlan0" ];
    };
    
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 67 68 80 30000 ];
      allowedUDPPorts = [ 53 67 68 ];
      # Allow forwarding for NAT
      extraCommands = ''
        iptables -A FORWARD -i wlan0 -o end0 -j ACCEPT
        iptables -A FORWARD -i end0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -w -C FORWARD -i wlan0 -o wlan-upstream -j ACCEPT 2>/dev/null || iptables -w -A FORWARD -i wlan0 -o wlan-upstream -j ACCEPT
        iptables -w -C FORWARD -i wlan-upstream -o wlan0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -w -A FORWARD -i wlan-upstream -o wlan0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -w -t nat -C POSTROUTING -o wlan-upstream -j MASQUERADE 2>/dev/null || iptables -w -t nat -A POSTROUTING -o wlan-upstream -j MASQUERADE
      '';
      extraStopCommands = ''
        iptables -w -D FORWARD -i wlan0 -o wlan-upstream -j ACCEPT 2>/dev/null || true
        iptables -w -D FORWARD -i wlan-upstream -o wlan0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
        iptables -w -t nat -D POSTROUTING -o wlan-upstream -j MASQUERADE 2>/dev/null || true
      '';
      interfaces.wlan0 = {
        allowedTCPPorts = [ 22 53 67 68 80 30000 ];
        allowedUDPPorts = [ 53 67 68 ];
      };
    };
  };

  # Network interface configuration
  systemd.network = {
    enable = true;
    links."10-wlan-upstream" = {
      matchConfig.PermanentMACAddress = "50:3d:d1:29:b7:62";
      linkConfig.Name = "wlan-upstream";
    };

    networks = {
      # Ethernet interface (DHCP client)
      "10-end0" = {
        matchConfig.Name = "end0";
        networkConfig = {
          DHCP = "yes";
          IPv4Forwarding = true;
          IPv6Forwarding = false;
        };
        dhcpV4Config = {
          RouteMetric = 1024;
          UseDNS = false;  # Don't use DHCP DNS to avoid conflicts with dnsmasq
        };
      };
      
      # WiFi interface for access point (don't use DHCP)
      "10-wlan0" = {
        matchConfig.Name = "wlan0";
        addresses = [
          {
            Address = "192.168.4.1/24";
          }
        ];
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = false;
        };
      };

      "20-wlan-upstream" = {
        matchConfig.Name = "wlan-upstream";
        networkConfig = {
          DHCP = "ipv4";
          IPv4Forwarding = true;
          IPv6Forwarding = false;
        };
        dhcpV4Config = {
          RouteMetric = 2048;
          UseDNS = false;
        };
      };
    };
  };

  # Prevent network services from stopping during rebuilds
  systemd.services = {
    systemd-networkd.stopIfChanged = false;
    systemd-resolved.stopIfChanged = false;

    wpa_supplicant-wlan-upstream = {
      description = "WPA supplicant for USB WiFi uplink";
      wantedBy = [ "multi-user.target" "sys-subsystem-net-devices-wlan\\x2dupstream.device" ];
      bindsTo = [ "sys-subsystem-net-devices-wlan\\x2dupstream.device" ];
      after = [ "sys-subsystem-net-devices-wlan\\x2dupstream.device" ];
      unitConfig.ConditionPathExists = "/sys/class/net/wlan-upstream";
      path = [ pkgs.iw pkgs.wpa_supplicant ];
      preStart = ''
        install -d -m 0700 /var/lib/vtt-dashboard
        if [ ! -e /var/lib/vtt-dashboard/wpa_supplicant.conf ]; then
          printf '%s\n' 'ctrl_interface=DIR=/run/wpa_supplicant' 'update_config=1' > /var/lib/vtt-dashboard/wpa_supplicant.conf
          chmod 0600 /var/lib/vtt-dashboard/wpa_supplicant.conf
        fi
        iw dev wlan-upstream set power_save off
        iw dev wlan-upstream set txpower auto
      '';
      serviceConfig = {
        ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -i wlan-upstream -c /var/lib/vtt-dashboard/wpa_supplicant.conf";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
