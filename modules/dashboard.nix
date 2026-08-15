{ config, pkgs, ... }:

let
  server = pkgs.writeText "vtt-dashboard-server.py" (builtins.readFile ../dashboard/server.py);
  dashboard = pkgs.writeText "vtt-dashboard-index.html" (builtins.readFile ../dashboard/index.html);
  proxy = {
    proxyPass = "http://127.0.0.1:8787";
    extraConfig = ''
      proxy_set_header X-Real-IP $remote_addr;
    '';
  };
in {
  networking.hosts."127.0.0.1" = [ "dashboard.local" ];

  systemd.services.vtt-dashboard = {
    description = "VTT dashboard API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.iw pkgs.iproute2 pkgs.iputils pkgs.wpa_supplicant config.systemd.package ];
    restartTriggers = [ server ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Environment = "VTT_AP_SSID=${config.vtt.common.apSsid}";
      ExecStart = "${pkgs.python3}/bin/python3 ${server}";
      Restart = "on-failure";
      StateDirectory = "vtt-dashboard";
      StateDirectoryMode = "0700";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."dashboard.local" = {
      extraConfig = ''
        allow 127.0.0.1;
        allow ::1;
        allow 192.168.4.0/24;
        deny all;
      '';
      locations = {
        "= /" = {
          extraConfig = "return 302 /dashboard/index.html;";
        };
        "= /dashboard/index.html".alias = dashboard;
        "/api/" = proxy;
        "= /api/setup" = proxy // {
          extraConfig = proxy.extraConfig + ''
            allow 127.0.0.1;
            allow ::1;
            allow 192.168.4.1;
            deny all;
          '';
        };
      };
    };
  };
}
