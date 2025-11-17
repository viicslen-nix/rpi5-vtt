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
}
