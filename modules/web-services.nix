{ config, pkgs, lib, ... }:

let
  proxyBlock = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:30000";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
  hosts = config.vtt.common.localDomains ++ [ "192.168.4.1" ];
  vhosts = builtins.listToAttrs (map (h: { name = h; value = proxyBlock; }) hosts);
in {
  # Nginx reverse proxy for VTT
  services.nginx = {
    enable = true;
    virtualHosts = vhosts;
  };
}