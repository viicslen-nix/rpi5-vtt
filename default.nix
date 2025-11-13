{ inputs, config, pkgs, lib, ... }:

{
  # Import all modules
  imports = [
    ./modules/system.nix
    ./modules/networking.nix
    ./modules/wifi-ap.nix
    ./modules/web-services.nix
    ./modules/users.nix
    ./modules/utilities.nix
    
    # Hardware configuration
    ./hardware.nix
    
    # Foundry VTT service configuration  
    ./configuration.nix
  ];

  # Create WPA password file for hostapd
  environment.etc."hostapd.wpa_psk".text = ''
    foundrycast
  '';
}