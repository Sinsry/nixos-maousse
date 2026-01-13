{
  description = "Configuration NixOS de maousse";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
  };
};
  outputs = { self, nixpkgs, home-manager, plasma-manager }: {
    nixosConfigurations.maousse = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.sinsry = {

            imports = [ plasma-manager.homeModules.plasma-manager ];

            home.stateVersion = "25.11";

            programs.plasma = {
              enable = true;
              input.keyboard.numlockOnStartup = "on";
              workspace = {
                lookAndFeel = "org.kde.breezedark.desktop";
                colorScheme = "BreezeDark";
                theme = "breeze-dark";
                iconTheme = "Papirus-Dark";
                cursor.theme = "breeze_cursors";
              };
              # Désactiver le retour de lancement
              configFile = {
                "klaunchrc"."BusyCursorSettings"."Bouncing" = false;
                "klaunchrc"."FeedbackStyle"."BusyCursor" = false;
              };
              };
            };
          }
        ];
     };
   };
}
