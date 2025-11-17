{inputs, pkgs, lib, config, ...}: {
  # Import all modules
  imports = [
    ./modules/common.nix
    ./modules/system.nix
    ./modules/networking.nix
    ./modules/wifi-ap.nix
    ./modules/web-services.nix
    ./modules/users.nix
    ./modules/utilities.nix
    ./modules/display.nix
    ./modules/foundry-vtt.nix
    ./modules/deploy.nix
  ];

  # Centralized, easy-to-tweak values
  vtt.common = {
    # Primary user used for login and services
    userName = "vtt";

    # WiFi Access Point
    apSsid = "VTT-Gaming";
    wifiPassphrase = "vttgaming";

    # Local hostnames served by dnsmasq and nginx
    localDomains = [ "vtt.local" "foundry.local" ];
  };

  # Enable GitHub deployment script
  vtt.deploy = {
    enable = true;
    
    # Optional: Enable automatic updates (disabled by default)
    # autoUpdate = {
    #   enable = true;
    #   schedule = "daily";  # Check daily for updates
    #   repository = "viicslen-nix/rpi5-vtt";
    # };
  };
}
