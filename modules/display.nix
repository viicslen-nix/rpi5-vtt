{ config, pkgs, lib, ... }:

{
  # Enable Wayland and graphics
  hardware.graphics.enable = true;

  # Kernel modules for graphics
  boot.kernelModules = [ "vc4" "v3d" ];

  # Install packages needed for Wayland kiosk
  environment.systemPackages = with pkgs; [
    firefox       # Use Firefox for kiosk
    cage          # Wayland kiosk compositor
    # wlr-randr     # Display configuration for wlroots compositors
  ];

  # Ensure vtt user has access to video/input devices
  users.users.vtt.extraGroups = [ "video" "input" "render" ];

  # Disable getty on tty1 since we'll use it for kiosk
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Wrapper program launched by services.cage
  environment.etc."vtt-kiosk-firefox.sh" = {
    text = ''
      #!/usr/bin/env bash
      # Firefox kiosk launcher (env provided by services.cage.environment)
      sleep 2
      exec ${pkgs.firefox}/bin/firefox --kiosk "http://vtt.local/"
    '';
    mode = "0755";
  };

  # Use the built-in Cage service for kiosk
  services.cage = {
    enable = true;
    user = "vtt";
    program = "/etc/vtt-kiosk-firefox.sh";
    environment = {
      MOZ_ENABLE_WAYLAND = "1";
      GDK_BACKEND = "wayland";
      QT_QPA_PLATFORM = "wayland";
    };
  };
}