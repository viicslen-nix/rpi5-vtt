{ inputs, config, pkgs, lib, ... }: let 
  name = "vtt";
  
  # Helper script for WiFi AP management
  wifi-ap-status = pkgs.writeShellScriptBin "wifi-ap-status" ''
    echo "=== WiFi Access Point Status ==="
    echo "Network Interface Status:"
    ${pkgs.iproute2}/bin/ip addr show wlan0
    echo ""
    echo "Hostapd Status:"
    systemctl status manual-hostapd
    echo ""
    echo "Connected Clients:"
    ${pkgs.iw}/bin/iw dev wlan0 station dump
    echo ""
    echo "DHCP Leases:"
    if [ -f /var/lib/dhcp/dhcpd.leases ]; then
      cat /var/lib/dhcp/dhcpd.leases
    fi
    echo ""
    echo "Foundry VTT Service Status:"
    systemctl status foundry-vtt
    echo ""
    echo "Nginx Reverse Proxy Status:"
    systemctl status nginx
    echo ""
    echo "Available access methods for clients:"
    echo "  WITHOUT PORT (recommended):"
    echo "    - http://vtt.local/"
    echo "    - http://foundry.local/"
    echo "    - http://192.168.4.1/"
    echo "  WITH PORT (legacy):"
    echo "    - http://vtt.local:30000"
    echo "    - http://foundry.local:30000"
    echo "    - http://192.168.4.1:30000"
    echo ""
    echo "To test DNS resolution from a connected device:"
    echo "  nslookup vtt.local 192.168.4.1"
    echo "  nslookup foundry.local 192.168.4.1"
  '';
in {
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    usb-gadget-ethernet
  ];        
  system = {
    stateVersion = config.system.nixos.release;

    nixos.tags = let
      cfg = config.boot.loader.raspberryPi;
    in [
      "raspberry-pi-${cfg.variant}"
      cfg.bootloader
      config.boot.kernelPackages.kernel.version
    ];
  };
  
  # Enable necessary kernel modules for WiFi AP
  boot.kernelModules = [ "brcmfmac" ];
  
  # Enable IP forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
  };
  
  # Create WPA password file for hostapd
  environment.etc."hostapd.wpa_psk".text = "vttgaming123";
  
  # Create simple hostapd configuration
  environment.etc."hostapd/hostapd.conf".text = ''
    # Basic hostapd configuration for Raspberry Pi 5
    interface=wlan0
    driver=nl80211
    ssid=VTT-Gaming
    hw_mode=g
    channel=7
    wmm_enabled=0
    macaddr_acl=0
    auth_algs=1
    ignore_broadcast_ssid=0
    wpa=2
    wpa_passphrase=vttgaming123
    wpa_key_mgmt=WPA-PSK
    rsn_pairwise=CCMP
  '';

  # Set environment variable for SSH agent auth
  environment.variables = {
    SSH_AUTH_SOCK = "/tmp/ssh-agent-socket";
  };
  
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

  users.users.${name} = {
    initialPassword = name;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGsA3Du6zHJeLpDVUXN7SnPEvnriYanApMRa5aB554s"
    ];
  };

  security.polkit.enable = true;
  nix.settings.trusted-users = [name];

  # Configure PAM for passwordless sudo with SSH key authentication
  security.pam.services.sudo = {
    sshAgentAuth = true;
  };

  # Configure sudo settings  
  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ name ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  systemd = {
    # Service dependencies
    services = {
      dnsmasq = {
        after = [ "manual-hostapd.service" ];
        wants = [ "manual-hostapd.service" ];
      };
      
      # Manual hostapd service
      manual-hostapd = {
        description = "Manual hostapd service";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-networkd.service" ];
        wants = [ "systemd-networkd.service" ];
        serviceConfig = {
          Type = "forking";
          PIDFile = "/run/hostapd.pid";
          ExecStartPre = [
            "${pkgs.kmod}/bin/modprobe brcmfmac"
            "${pkgs.iproute2}/bin/ip link set dev wlan0 up"
          ];
          ExecStart = "${pkgs.hostapd}/bin/hostapd -B -P /run/hostapd.pid /etc/hostapd/hostapd.conf";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          KillMode = "mixed";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
      
      systemd-networkd.stopIfChanged = false;
      systemd-resolved.stopIfChanged = false;
    };
    
    network = {
      networks = {
        # Ethernet interface for internet connectivity
        "99-ethernet-default-dhcp" = {
          matchConfig.Name = "eth0";
          networkConfig = {
            DHCP = lib.mkForce "ipv4";
            MulticastDNS = "yes";
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
  };

  services = {
    getty.autologinUser = name;
    openssh.enable = true;
    
    # Enable SSH agent forwarding
    openssh.settings = {
      AllowAgentForwarding = true;
    };
    
    # Nginx reverse proxy for VTT
    nginx = {
      enable = true;
      virtualHosts = {
        "vtt.local" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:30000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
        "foundry.local" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:30000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
        "192.168.4.1" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:30000";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
    
    # WiFi access point (disabled temporarily for manual setup)
    # hostapd = {
    #   enable = true;
    #   radios.wlan0 = {
    #     band = "2g";
    #     channel = 7;
    #     networks.wlan0 = {
    #       ssid = "VTT-Gaming";
    #       authentication = {
    #         mode = "wpa2-sha1";
    #         wpaPasswordFile = "/etc/hostapd.wpa_psk";
    #       };
    #     };
    #   };
    # };
    
    # Configure systemd-resolved to not conflict with dnsmasq
    resolved = {
      enable = true;
      dnssec = "false";
      domains = [ "~." ];
      fallbackDns = [ "8.8.8.8" "8.8.4.4" ];
      # Disable the stub resolver so dnsmasq can use port 53
      extraConfig = ''
        DNSStubListener=no
      '';
    };

    # DNS and DHCP for access point clients
    dnsmasq = {
      enable = true;
      settings = {
        # Interface to listen on
        interface = "wlan0";
        
        # DHCP range for clients
        dhcp-range = "192.168.4.10,192.168.4.100,24h";
        
        # Set gateway
        dhcp-option = [
          "3,192.168.4.1"  # Gateway
          "6,192.168.4.1"  # DNS server
        ];
        
        # Custom hostname resolution for VTT
        address = [
          "/vtt.local/192.168.4.1"
          "/foundry.local/192.168.4.1"
        ];
        
        # Enable local domain resolution
        local = "/local/";
        domain = "local";
        
        # Don't read /etc/hosts
        no-hosts = true;
        
        # Don't read /etc/resolv.conf
        no-resolv = true;
        
        # Set upstream DNS servers
        server = [
          "8.8.8.8"
          "8.8.4.4"
        ];
        
        # Cache size
        cache-size = 1000;
        
        # Log DHCP requests for debugging
        log-dhcp = true;
        
        # Only bind to our interface
        bind-interfaces = true;
      };
    };

    udev.extraRules = ''
      # Ignore partitions with "Required Partition" GPT partition attribute
      # On our RPis this is firmware (/boot/firmware) partition
      ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
        ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
        ENV{UDISKS_IGNORE}="1"
    '';
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    # Networking tools for debugging
    iw
    hostapd
    dnsmasq
    iptables
    nmap
    tcpdump
    # Custom script for AP status
    wifi-ap-status
  ];
}
