{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.vtt.deploy;
  
  deployScript = pkgs.writeScriptBin "deploy-from-github" ''
    #!${pkgs.bash}/bin/bash
    export PATH="${pkgs.gh}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:$PATH"
    ${builtins.readFile ../scripts/deploy-from-github.sh}
  '';

in {
  options.vtt.deploy = {
    enable = mkEnableOption "GitHub deployment script";
    
    autoUpdate = {
      enable = mkEnableOption "automatic system updates from GitHub";
      
      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "When to check for updates (systemd timer format)";
      };
      
      repository = mkOption {
        type = types.str;
        default = "viicslen-nix/rpi5-vtt";
        description = "GitHub repository in OWNER/REPO format";
      };
    };
  };

  config = mkIf cfg.enable {
    # Install the deployment script
    environment.systemPackages = [
      deployScript
      pkgs.gh  # GitHub CLI
      pkgs.nvd # For showing nice diffs (optional but recommended)
    ];

    # Configure automatic updates if enabled
    systemd.services.github-auto-deploy = mkIf cfg.autoUpdate.enable {
      description = "Automatic deployment from GitHub Actions";
      path = [ deployScript pkgs.gh pkgs.git pkgs.coreutils ];
      
      serviceConfig = {
        Type = "oneshot";
        # Run as root since we need to switch system
        User = "root";
        # Set environment variables
        Environment = [
          "REPO_OWNER=${elemAt (splitString "/" cfg.autoUpdate.repository) 0}"
          "REPO_NAME=${elemAt (splitString "/" cfg.autoUpdate.repository) 1}"
          "DRY_RUN=false"
        ];
        # Auto-confirm by running non-interactively
        StandardInput = "null";
      };
      
      script = ''
        echo "yes" | ${deployScript}/bin/deploy-from-github
      '';
    };

    systemd.timers.github-auto-deploy = mkIf cfg.autoUpdate.enable {
      description = "Timer for automatic GitHub deployment";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnCalendar = cfg.autoUpdate.schedule;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    # Ensure gh is authenticated (user must set this up manually)
    assertions = [
      {
        assertion = cfg.autoUpdate.enable -> (cfg.autoUpdate.repository != "");
        message = "vtt.deploy.autoUpdate.repository must be set when auto-update is enabled";
      }
    ];
  };
}
