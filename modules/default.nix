# VTT Gaming Setup Modules
# This file provides a clean import interface for all VTT configuration modules

{
  # Core system configuration
  system = ./system.nix;
  
  # Network configuration
  networking = ./networking.nix;
  
  # WiFi Access Point
  wifi-ap = ./wifi-ap.nix;
  
  # Web services (nginx reverse proxy)
  web-services = ./web-services.nix;
  
  # User and authentication
  users = ./users.nix;
  
  # Utilities and tools
  utilities = ./utilities.nix;
  
  # Display and kiosk mode
  display = ./display.nix;
}