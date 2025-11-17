{ lib, config, ... }:

with lib;
let
  cfg = config.vtt.common;
in {
  options.vtt.common = {
    apSsid = mkOption {
      type = types.str;
      default = "VTT-Gaming";
      description = "SSID name for the WiFi access point.";
      example = "My-Table-AP";
    };

    wifiPassphrase = mkOption {
      type = types.str;
      default = "vttgaming";
      description = "WPA2-PSK passphrase for the WiFi access point.";
      example = "supersecret";
    };

    localDomains = mkOption {
      type = types.listOf types.str;
      default = [ "vtt.local" "foundry.local" ];
      description = "Local hostnames that should resolve to this device (used for DNS and reverse proxy).";
      example = [ "table.local" "foundry.local" ];
    };

    userName = mkOption {
      type = types.str;
      default = "vtt";
      description = "Primary local user account name used for services and login.";
      example = "table";
    };

    primaryDomain = mkOption {
      type = types.str;
      default = "vtt.local";
      description = "Primary local domain to use for kiosk and documentation; defaults to the first element of localDomains if set.";
      readOnly = false;
    };
  };

  config = {
    # Derive primaryDomain from localDomains when possible
    vtt.common.primaryDomain = mkDefault (
      let ds = cfg.localDomains; in if ds == [] then "vtt.local" else builtins.head ds
    );
  };
}
