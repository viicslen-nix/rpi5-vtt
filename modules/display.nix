{ config, pkgs, lib, ... }:

{
  # Enable Wayland and graphics
  hardware.graphics.enable = true;

  # Kernel modules for graphics
  boot.kernelModules = [ "vc4" "v3d" ];

  # Install packages needed for Wayland kiosk
  environment.systemPackages = with pkgs; [
    ungoogled-chromium  # Lightweight Chromium without Google dependencies
    cage                # Wayland kiosk compositor
    # wlr-randr         # Display configuration for wlroots compositors
  ];

  # Ensure the kiosk user has access to video/input devices
  users.users.${config.vtt.common.userName}.extraGroups = [ "video" "input" "render" ];

  # Disable getty on tty1 since we'll use it for kiosk
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Wrapper program launched by services.cage
  environment.etc."vtt-kiosk-chromium.sh" = {
    text = ''
      #!/usr/bin/env bash
      # Chromium kiosk launcher (env provided by services.cage.environment)
      sleep 2
      exec ${pkgs.ungoogled-chromium}/bin/chromium \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --no-first-run \
        --enable-features=OverlayScrollbar \
        --enable-accelerated-video-decode \
        --enable-gpu-rasterization \
        --enable-zero-copy \
        --disable-smooth-scrolling \
        --disable-background-networking \
        --disable-sync \
        --disable-translate \
        "http://${config.vtt.common.primaryDomain}/"
    '';
    mode = "0755";
  };

  # Use the built-in Cage service for kiosk
  services.cage = {
    enable = true;
    user = config.vtt.common.userName;
    program = "/etc/vtt-kiosk-chromium.sh";
    environment = {
      # Enable Wayland support
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
      # Chromium Wayland flags
      NIXOS_OZONE_WL = "1";
    };
  };
}