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
    ./modules/display.nix
    
    # Hardware configuration
    ./hardware.nix
    
    # Foundry VTT service configuration  
    ./configuration.nix
  ];
}