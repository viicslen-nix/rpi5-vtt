{ inputs, config, pkgs, lib, ... }:

let
  chromium = inputs.nixpkgs-browser.legacyPackages.${pkgs.system}.ungoogled-chromium;
in {
  # Enable Wayland and graphics
  hardware.graphics.enable = true;

  # Kernel modules for graphics
  boot.kernelModules = [ "vc4" "v3d" ];

  # Install packages needed for Wayland kiosk
  environment.systemPackages = with pkgs; [
    chromium            # Lightweight Chromium without Google dependencies
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
      exec ${chromium}/bin/chromium \
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
        "http://dashboard.local/"
    '';
    mode = "0755";
  };

  # Use the built-in Cage service for kiosk
  services.cage = {
    enable = true;
    user = config.vtt.common.userName;
    program = "/etc/vtt-kiosk-chromium.sh";
    environment = {
      # Pi 5 exposes V3D (render-only) before the VC4 KMS display device.
      WLR_DRM_DEVICES = "/dev/dri/card1";
      XDG_RUNTIME_DIR = "/run/user/1000";
      # Chromium Wayland flags
      NIXOS_OZONE_WL = "1";
    };
  };

  systemd.services.cage-tty1 = {
    wants = [ "nginx.service" "vtt-dashboard.service" ];
    after = [ "nginx.service" "vtt-dashboard.service" ];
  };
}
