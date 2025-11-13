{ config, pkgs, lib, ... }:

{
  # Enable Wayland and graphics
  hardware.graphics = {
    enable = true;
  };

  # Install packages needed for Wayland kiosk
  environment.systemPackages = with pkgs; [
    chromium
    cage          # Wayland kiosk compositor
    wlr-randr     # Display configuration for wlroots compositors
  ];

  # Create kiosk startup script for Wayland
  environment.etc."kiosk-wayland.sh" = {
    text = ''
      #!/bin/bash
      
      # Set environment variables for Wayland
      export WLR_LIBINPUT_NO_DEVICES=1
      export WAYLAND_DISPLAY=wayland-0
      export QT_QPA_PLATFORM=wayland
      export GDK_BACKEND=wayland
      export MOZ_ENABLE_WAYLAND=1
      export XDG_RUNTIME_DIR="/run/user/1000"
      
      # Wait a moment for system to be ready
      sleep 3
      
      # Start Cage with Chromium in kiosk mode
      exec ${pkgs.cage}/bin/cage -- \
        ${pkgs.chromium}/bin/chromium \
          --kiosk \
          --no-first-run \
          --disable-infobars \
          --disable-features=TranslateUI \
          --disable-ipc-flooding-protection \
          --disable-background-timer-throttling \
          --disable-renderer-backgrounding \
          --disable-backgrounding-occluded-windows \
          --disable-component-extensions-with-background-pages \
          --autoplay-policy=no-user-gesture-required \
          --force-device-scale-factor=1 \
          --disable-dev-shm-usage \
          --disable-software-rasterizer \
          --enable-features=VaapiVideoDecoder \
          --ignore-certificate-errors \
          --ignore-ssl-errors \
          --ignore-certificate-errors-spki \
          --ignore-certificate-errors-ssl \
          --allow-running-insecure-content \
          --disable-web-security \
          --user-data-dir=/home/vtt/.chromium-kiosk \
          --enable-wayland-ime \
          --ozone-platform=wayland \
          "http://vtt.local/"
    '';
    mode = "0755";
  };

  # Create systemd service for kiosk mode
  systemd.services.vtt-kiosk = {
    description = "VTT Kiosk Mode Display";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "vtt";
      Group = "vtt";
      Restart = "always";
      RestartSec = "5";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      
      # Environment variables for Wayland
      Environment = [
        "WLR_LIBINPUT_NO_DEVICES=1"
        "WAYLAND_DISPLAY=wayland-0"
        "QT_QPA_PLATFORM=wayland"
        "GDK_BACKEND=wayland"
        "MOZ_ENABLE_WAYLAND=1"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
      
      ExecStart = "/etc/kiosk-wayland.sh";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Ensure vtt user has access to video/input devices
  users.users.vtt = {
    extraGroups = [ "video" "input" "render" ];
  };

  # Setup user session directories and permissions
  system.activationScripts.kioskSetup = ''
    # Create user runtime directory
    mkdir -p /run/user/1000
    chown vtt:vtt /run/user/1000
    chmod 700 /run/user/1000
    
    # Create chromium data directory
    mkdir -p /home/vtt/.chromium-kiosk
    chown -R vtt:vtt /home/vtt/.chromium-kiosk
  '';

  # Kernel modules for graphics
  boot.kernelModules = [ "vc4" "v3d" ];

  # Disable getty on tty1 since we'll use it for kiosk
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}