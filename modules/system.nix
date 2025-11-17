{ inputs, config, pkgs, lib, ... }:

let
  name = "vtt";
in {
  # Import Raspberry Pi modules
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    usb-gadget-ethernet
  ];  

  # Disable documentation
  documentation.man.enable = false;      

  # Allow unfree packages (helps with binary cache availability)
  nixpkgs.config.allowUnfree = true;

  # Nix build optimization settings
  nix = {
    settings = {
      # Maximize build parallelism
      max-jobs = "auto";  # Use all available cores
      cores = 0;          # Each job uses all cores
      
      # Always prefer binary cache over building from source
      builders-use-substitutes = true;
      
      # Additional substituters for faster builds
      substituters = [
        "https://cache.nixos.org"
        "https://nixos-raspberrypi.cachix.org"
      ];
      
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        # Add your cachix public key once created
      ];
    };
    
    # Enable flakes
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # System configuration
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
  
  # Boot configuration
  boot = {
    # Enable necessary kernel modules for WiFi AP
    kernelModules = [ "brcmfmac" ];
    
    # Enable IP forwarding
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv4.conf.all.forwarding" = 1;
    };
  };
}