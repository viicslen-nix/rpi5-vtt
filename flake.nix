{
  description = "A very basic flake";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-browser.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    foundry-vtt.url = ./flakes/foundry-vtt;
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs @ { self, nixpkgs, ... }:
    let
      mkVttSystem = modules:
        inputs.nixos-raspberrypi.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            inherit (inputs) nixos-raspberrypi;
          };
          inherit modules;
        };
    in {
      nixosConfigurations = {
        vtt = mkVttSystem [
          ./hardware.nix
          ./configuration.nix
        ];
        vtt-sd = mkVttSystem [
          ./configuration.nix
          ({ lib, ... }: {
            # Keep the image filesystem set small so the installer image does not
            # pull in heavyweight extras like zfs-kernel on ARM.
            boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" ];
          })
          inputs.nixos-raspberrypi.nixosModules.sd-image
        ];
      };
    };
}
