{inputs, pkgs, lib, ...}: let
  foundry-vtt = inputs.foundry-vtt.packages.${pkgs.system}.default;
in {
  environment.systemPackages = [
    foundry-vtt
  ];

  systemd.services.foundry-vtt = {
    enable = true;
    serviceConfig = {
      ExecStart = lib.getExe foundry-vtt;
    };
  };

  networking.firewall.allowedTCPPorts = [30000];
}
