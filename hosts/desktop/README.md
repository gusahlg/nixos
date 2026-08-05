# Gustav's computer
This is for my main stationary all-purpose computer configuration. It is a solid
desktop configuration with a full development stack and nice tools and dependencies
pre-installed.

## Impermanence

Only this host uses impermanence. Its root is an 8 GiB tmpfs, while the former
ext4 root is mounted at `/persist` and its existing `/nix` directory is bind
mounted at `/nix`. This makes the migration zero-copy and keeps the old root
available for recovery.

The complete `/home/gusahlg` directory is intentionally persistent. This is one
recursive persistence boundary, so it includes current and future contents such
as `~/repos`, `~/.ssh`, `~/.config`, application data, and Home Manager's files
and state. Assertions ensure that both NixOS and Home Manager continue to use
that exact home path. System state outside the home is opt-in and documented in
`impermanence.nix`.

Build and install the first impermanent boot generation with:

```console
sudo nixos-rebuild boot --flake path:/etc/nixos#sighurt
```

After rebooting, the previous generation remains selectable from systemd-boot if
the new mount layout does not come up correctly.
