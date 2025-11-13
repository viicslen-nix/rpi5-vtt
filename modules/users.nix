{ config, pkgs, lib, ... }:

let
  name = "vtt";
in {
  # User configuration
  users.users.${name} = {
    initialPassword = name;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGsA3Du6zHJeLpDVUXN7SnPEvnriYanApMRa5aB554s"
    ];
  };

  # Security and authentication configuration
  security.polkit.enable = true;
  nix.settings.trusted-users = [name];

  # Auto login for getty
  services.getty.autologinUser = name;

  # Configure PAM for passwordless sudo with SSH key authentication
  security.pam.services.sudo = {
    sshAgentAuth = true;
  };

  # Configure sudo settings  
  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ name ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      AllowAgentForwarding = true;
    };
  };

  # Set environment variable for SSH agent auth
  environment.variables = {
    SSH_AUTH_SOCK = "/tmp/ssh-agent-socket";
  };
}