{ config, pkgs, lib, ... }:

let
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
  # System packages and utilities
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

  # USB device auto-mounting configuration
  services.udisks2 = {
    enable = true;
    settings = {
      "udisks2.conf" = {
        udisks2 = {
          modules = ["*"];
          modules_blacklist = [""];
        };
        defaults = {
          encryption = "luks2";
        };
      };
    };
  };

  # Mount options and partition rules
  services.udev.extraRules = ''
    # Ignore partitions with "Required Partition" GPT partition attribute
    # On our RPis this is firmware (/boot/firmware) partition
    ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
      ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
      ENV{UDISKS_IGNORE}="1"
  '';
}