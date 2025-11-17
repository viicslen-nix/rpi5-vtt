{
  description = "A very basic flake";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nvmd/nixpkgs/modules-with-keys-unstable";

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs = inputs @ { self, nixpkgs, ... }: {
    nixosConfigurations.vtt = inputs.nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = { 
        inherit inputs;
        inherit (inputs) nixos-raspberrypi;
      };
      modules = [
        ./hardware.nix
        ./configuration.nix
      ];
    };
  };
}
