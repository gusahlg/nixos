# Louise's computer

`configuration.nix` contains the hardware-independent system, gaming, desktop,
remote-support, and user setup for Louise's computer. It deliberately does not
reuse `hosts/desktop/hardware-configuration.nix`.

On Louise's computer, generate and add its hardware configuration as
`hosts/louise/hardware-configuration.nix`. Then add this output to `flake.nix`:

```nix
nixosConfigurations.louise = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit concord home-manager; };
  modules = [ ./hosts/louise/configuration.nix ];
};
```

The configuration intentionally remains disconnected from the flake until the
real hardware file exists, preventing an incomplete system from being deployed.
After the first activation, set passwords for both accounts with `passwd`.
