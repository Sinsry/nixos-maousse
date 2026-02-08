{
  description = "Configuration NixOS Full Unstable";

  #==== Sources ====
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  #==== Configuration ====
  outputs =
    inputs@{ self, nixpkgs, ... }:
    {
      nixosConfigurations.maousse = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          ./configuration-kde.nix
        ];
      };
    };
}
