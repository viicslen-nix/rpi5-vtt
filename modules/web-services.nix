{ config, pkgs, lib, ... }:

{
  # Nginx reverse proxy for VTT
  services.nginx = {
    enable = true;
    virtualHosts = {
      "vtt.local" = {
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
      "foundry.local" = {
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
      "192.168.4.1" = {
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
    };
  };
}