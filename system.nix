{ inputs, config, pkgs, lib, ... }: let 
  name = "vtt"; 
in {
  imports = with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    usb-gadget-ethernet
  ];        
  system = {
    stateVersion = config.system.nixos.release;

    nixos.tags = let
      cfg = config.boot.loader.raspberryPi;
    in [
      "raspberry-pi-${cfg.variant}"
      cfg.bootloader
      config.boot.kernelPackages.kernel.version
    ];
  };
  
  networking = {
    hostId = "8821e309";
    hostName = name;
    useNetworkd = true;
    wireless = {
      enable = false;
      iwd = {
        enable = true;
        settings = {
          Network = {
            EnableIPv6 = true;
            RoutePriorityOffset = 300;
          };
          Settings.AutoConnect = true;
        };
      };
    };
  };

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

  security.polkit.enable = true;
  nix.settings.trusted-users = [name];

  systemd = {
    network.networks = {
      "99-ethernet-default-dhcp".networkConfig.MulticastDNS = "yes";
      "99-wireless-client-dhcp".networkConfig.MulticastDNS = "yes";
    };
    
    # This comment was lifted from `srvos`
    # Do not take down the network for too long when upgrading,
    # This also prevents failures of services that are restarted instead of stopped.
    # It will use `systemctl restart` rather than stopping it with `systemctl stop`
    # followed by a delayed `systemctl start`.
    services = {
      systemd-networkd.stopIfChanged = false;
      systemd-resolved.stopIfChanged = false;
    };
  };

  services = {
    getty.autologinUser = name;
    openssh.enable = true;

    udev.extraRules = ''
      # Ignore partitions with "Required Partition" GPT partition attribute
      # On our RPis this is firmware (/boot/firmware) partition
      ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
        ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
        ENV{UDISKS_IGNORE}="1"
    '';
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];
}
