{
  description = "sighurt NixOS system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    concord.url = "github:chojs23/concord";

    # Keep the window-manager implementation pinned independently from this
    # system configuration. The lock file records the exact source revision.
    gharialSrc = {
      url = "github:gusahlg/gharial/a6c6f14fcc2c3cdcc64fe7e13b458331b8502c2a";
      flake = false;
    };

    # Meander is the low-level Wayland UI toolkit used by the local bar.
    meanderSrc = {
      url = "github:gusahlg/meander/459767a84641002f1be81ede102e6782efa71f48";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, concord, gharialSrc, meanderSrc, ... }:
  {
    nixosConfigurations.sighurt = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit concord gharialSrc meanderSrc; };

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
