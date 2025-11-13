{ config, pkgs, lib, ... }:

{
  # WiFi Access Point Configuration
  
  # Manual hostapd configuration (bypassing NixOS module limitations)
  environment.etc."hostapd/hostapd.conf".text = ''
    interface=wlan0
    driver=nl80211
    
    # Network settings
    ssid=VTT-Gaming
    hw_mode=g
    channel=7
    country_code=US
    ieee80211n=1
    ieee80211d=1
    
    # Security settings
    wpa=2
    wpa_passphrase=foundrycast
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP
    rsn_pairwise=CCMP
  '';

  systemd.services.manual-hostapd = {
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

  # DNS and DHCP for access point clients
  services.dnsmasq = {
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
      
      # Only bind to specified interfaces
      bind-interfaces = true;
    };
  };

  # Service dependencies
  systemd.services.dnsmasq = {
    after = [ "manual-hostapd.service" ];
    wants = [ "manual-hostapd.service" ];
  };

  # Configure systemd-resolved to not conflict with dnsmasq
  services.resolved = {
    enable = true;
    dnssec = "false";
    domains = [ "~." ];
    fallbackDns = [ "8.8.8.8" "8.8.4.4" ];
    # Disable the stub resolver so dnsmasq can use port 53
    extraConfig = ''
      DNSStubListener=no
    '';
  };
}