# macbook

This host is the 13-inch M3 MacBook Air currently installed with NixOS. Its
disk UUIDs are recorded in `hardware-configuration.nix`.

The Apple Silicon module loads the machine-specific peripheral firmware from
`/etc/nixos/firmware/firmware.cpio`. This is a copy of the archive that the
Asahi installer places at `/boot/vendorfw/firmware.cpio`. The local directory
is ignored by Git because the firmware is machine-specific and
non-redistributable. Keep this file in place after cloning the repository.

Apply the configuration with:

```console
sudo nixos-rebuild switch --flake path:/etc/nixos#macbook
```

The Mac uses the same River 0.4, Gharial, typed Rust init, Meander bar,
bindings, launcher and shared development/Home Manager configuration as the
desktop. It leaves out NVIDIA/CUDA, distributed GPU services, gaming packages,
desktop monitor rules, Roblox and Hackatime.
