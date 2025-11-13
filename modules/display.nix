{ config, pkgs, lib, ... }:

{
  # Enable X11 and display manager for kiosk mode
  services.xserver = {
    enable = true;
    displayManager = {
      lightdm = {
        enable = true;
        autoLogin = {
          enable = true;
          user = "vtt";
        };
      };
    };
    
    # Use a minimal window manager
    windowManager.openbox.enable = true;
    
    # Disable desktop environment to keep it minimal
    desktopManager.xterm.enable = false;
  };

  # Install Chromium for kiosk mode browsing
  environment.systemPackages = with pkgs; [
    chromium
    xorg.xset
    xorg.xrandr
  ];

  # Create kiosk startup script
  environment.etc."kiosk-start.sh" = {
    text = ''
      #!/bin/bash
      
      # Wait for X to start
      sleep 3
      
      # Disable screen blanking and power management
      xset s off
      xset -dpms
      xset s noblank
      
      # Set display orientation (adjust if needed)
      # xrandr --output HDMI-A-1 --rotate normal
      
      # Start Chromium in kiosk mode
      chromium \
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
        "http://vtt.local/" &
      
      # Keep the script running to prevent session exit
      wait
    '';
    mode = "0755";
  };

  # Create openbox autostart configuration for vtt user
  system.activationScripts.kioskSetup = ''
    # Create openbox config directory for vtt user
    mkdir -p /home/vtt/.config/openbox
    
    # Create autostart script that launches our kiosk
    cat > /home/vtt/.config/openbox/autostart << 'EOF'
#!/bin/bash
# Launch kiosk mode browser
/etc/kiosk-start.sh &
EOF
    
    # Make it executable
    chmod +x /home/vtt/.config/openbox/autostart
    
    # Set proper ownership
    chown -R vtt:vtt /home/vtt/.config
    
    # Create chromium data directory
    mkdir -p /home/vtt/.chromium-kiosk
    chown -R vtt:vtt /home/vtt/.chromium-kiosk
  '';

  # Enable auto-login for vtt user (already configured above in lightdm)
  # This will automatically start the graphical session on boot

  # Configure audio for the display (optional - for game audio)
  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    support32Bit = true;
  };

  # Add vtt user to audio group
  users.users.vtt.extraGroups = [ "audio" "video" ];

  # Enable GPU acceleration for Raspberry Pi (simplified approach)
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };

  # Ensure graphics drivers are loaded
  boot.kernelModules = [ "vc4" "v3d" ];
  
  # Optional: Configure display resolution (uncomment and adjust as needed)
  # This goes in config.txt via hardware.raspberry-pi configuration
  # hardware.raspberry-pi."5".config-output = {
  #   # Set resolution (uncomment one):
  #   # "hdmi_group" = 1; "hdmi_mode" = 16;  # 1920x1080 60Hz
  #   # "hdmi_group" = 2; "hdmi_mode" = 82;  # 1920x1080 60Hz (computer monitor)
  # };
}