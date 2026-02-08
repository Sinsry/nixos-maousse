{
  description = "Configuration NixOS Full Unstable";

  #==== Sources ====
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    solaar = {
      #url = "https://flakehub.com/f/Svenum/Solaar-Flake/*.tar.gz"; # For latest stable version
      url = "https://flakehub.com/f/Svenum/Solaar-Flake/0.1.7.tar.gz"; # uncomment line for solaar version 1.1.19
      #url = "github:Svenum/Solaar-Flake/main"; # Uncomment line for latest unstable version
    };
  };

  #==== Configuration ====
  outputs =
    inputs@{ self, nixpkgs, solaar, ... }:
    {
      nixosConfigurations.maousse = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        system = "x86_64-linux";
        modules = [
          solaar.nixosModules.default
          ./configuration-kde.nix
        ];
      };
    };
}
