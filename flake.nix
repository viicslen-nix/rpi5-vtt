{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    foundry-vtt.url = "git+ssh://git@github.com/viicslen-nix/foundry-vtt.git";
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.vtt = inputs.nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = { inherit inputs; };
      modules = [
        ./system.nix
        ./configuration.nix
      ];
    };
  };
}
