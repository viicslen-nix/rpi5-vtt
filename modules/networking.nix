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
    };
  };

  # Prevent network services from stopping during rebuilds
  systemd.services = {
    systemd-networkd.stopIfChanged = false;
    systemd-resolved.stopIfChanged = false;
  };
}