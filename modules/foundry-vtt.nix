{ inputs, config, pkgs, lib, ... }:

let
  foundry-vtt = inputs.foundry-vtt.packages.${pkgs.system}.default;
in {
  # Foundry VTT Server Configuration
  
  environment.systemPackages = [
    foundry-vtt
  ];

  systemd.services.foundry-vtt = {
    enable = true;
    description = "Foundry VTT Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${lib.getExe foundry-vtt} --dataPath=/home/${config.vtt.common.userName}/foundrydata";
      Restart = "always";
      RestartSec = 10;
      User = config.vtt.common.userName;
      Group = "users";
      # Bind to all interfaces so it's accessible from WiFi clients
      Environment = [
        "FOUNDRY_VTT_HOSTNAME=0.0.0.0"
        "FOUNDRY_VTT_PORT=30000"
      ];
    };
  };
}
