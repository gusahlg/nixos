{
  description = "sighurt NixOS system";

  nixConfig = {
    extra-substituters = [ "https://cache.nixos-cuda.org" ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "";
      inputs.home-manager.follows = "";
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

    playit-nixos-module.url = "github:pedorich-n/playit-nixos-module";
  };

  outputs = { self, nixpkgs, home-manager, impermanence, concord, gharialSrc, meanderSrc, playit-nixos-module, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        # RTX 3070 (sm_86) and RTX 4060 (sm_89).
        cudaCapabilities = [ "8.6" "8.9" ];
      };
    };
  in
  {
    packages.${system}.llama-cpp-cuda-rpc =
      import ./packages/llama-cpp-cuda-rpc.nix { inherit pkgs; };

    # Manual llama.cpp checkout builds (the checklist cmake path) on NixOS.
    devShells.${system}.llama-cpp = pkgs.mkShell.override {
      stdenv = pkgs.cudaPackages.backendStdenv;
    } {
      packages = with pkgs; [
        cmake
        ninja
        git
        pkg-config
        gnumake
        cudaPackages.cuda_nvcc
        cudaPackages.cudatoolkit
        cudaPackages.cuda_cudart
        cudaPackages.libcublas
      ];
      shellHook = ''
        export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
        echo "CUDA+RPC llama.cpp shell. From a llama.cpp checkout:"
        echo "  cmake -B build -DGGML_CUDA=ON -DGGML_RPC=ON"
        echo "  cmake --build build -j"
      '';
    };

    nixosConfigurations.sighurt = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = { inherit concord gharialSrc meanderSrc; };

      modules = [
        impermanence.nixosModules.impermanence
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
        playit-nixos-module.nixosModules.default
        ./hosts/server/configuration.nix
      ];
    };
    nixosConfigurations.louise = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit concord home-manager; };
      modules = [ ./hosts/louise/configuration.nix ];
    };
  };
}
