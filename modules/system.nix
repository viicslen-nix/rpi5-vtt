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