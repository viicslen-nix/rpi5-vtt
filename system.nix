{ inputs, config, pkgs, lib, ... }: let 
  name = "vtt";
  
  # Helper script for WiFi AP management
  wifi-ap-status = pkgs.writeShellScriptBin "wifi-ap-status" ''
    echo "=== WiFi Access Point Status ==="
    echo "Network Interface Status:"
    ${pkgs.iproute2}/bin/ip addr show wlan0
    echo ""
    echo "Hostapd Status:"
    systemctl status hostapd
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
    echo "Available hostnames for clients:"
    echo "  - http://vtt.local:30000"
    echo "  - http://foundry.local:30000"
    echo "  - http://192.168.4.1:30000"
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
      externalInterface = "eth0";  # Assuming ethernet for internet
      internalInterfaces = [ "wlan0" ];
    };
    
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 53 67 68 30000 ];
      allowedUDPPorts = [ 53 67 68 ];
      interfaces.wlan0 = {
        allowedTCPPorts = [ 22 53 67 68 30000 ];
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

  systemd = {
    network = {
      networks = {
        # Ethernet interface for internet connectivity
        "99-ethernet-default-dhcp" = {
          matchConfig.Name = "eth0";
          networkConfig = {
            DHCP = "ipv4";
            MulticastDNS = "yes";
          };
        };
        
        # WiFi interface for access point (don't use DHCP)
        "10-wlan0" = {
          matchConfig.Name = "wlan0";
          networkConfig = {
            Address = "192.168.4.1/24";
            IPForward = "yes";
          };
        };
      };
    };
    
    # This comment was lifted from `srvos`
    # Do not take down the network for too long when upgrading,
    # This also prevents failures of services that are restarted instead of stopped.
    # It will use `systemctl restart` rather than stopping it with `systemctl stop`
    # followed by a delayed `systemctl start`.
    services = {
      systemd-networkd.stopIfChanged = false;
      systemd-resolved.stopIfChanged = false;
    };
  };

  services = {
    getty.autologinUser = name;
    openssh.enable = true;
    
    # WiFi access point
    hostapd = {
      enable = true;
      radios.wlan0 = {
        band = "2g";
        channel = 7;
        networks.wlan0 = {
          ssid = "VTT-Gaming";
          authentication = {
            mode = "wpa2-sha256";
            wpaPasswordFile = "/etc/hostapd.wpa_psk";
          };
        };
      };
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
