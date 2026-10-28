# Machine-specific disk layout generated on the MacBook Air (M3, 2024).
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9db8788b-4718-404e-a6d0-1c9694d398fd";
    fsType = "btrfs";
    options = [ "subvol=nixos-root" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1318-2C36";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
