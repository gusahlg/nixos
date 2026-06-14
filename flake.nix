{
  description = "sighurt NixOS system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    concord.url = "github:chojs23/concord";
  };

  outputs = { self, nixpkgs, home-manager, concord, ... }:
  {
    nixosConfigurations.sighurt = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit concord; };

      modules = [
        ./hosts/desktop/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.gusahlg = import ./home.nix;
        }
      ];
    };

    nixosConfigurations.sighurt-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./hosts/server/configuration.nix
      ];
    };
  };
}
