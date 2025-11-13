{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    foundry-vtt.url = "git+ssh://git@github.com/viicslen-nix/foundry-vtt?ref=main";
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
        ./system.nix
	./hardware.nix
        ./configuration.nix
      ];
    };
  };
}
