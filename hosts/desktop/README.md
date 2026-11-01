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

## Sighurt updates

The `sighurtSrc` input follows GitHub's `main` branch, with its exact commit
recorded in `flake.lock`. Rebuilding uses that locked commit. To fetch a newer
Sighurt commit without updating the other inputs, run `nix flake update sighurtSrc`
in `/etc/nixos`, then rebuild. The package enables both GUI and TUI frontends
and the Servo, WPE and Wasm engines.

## Storage headroom

The SSD currently backs both `/nix` and the persistent home; the RAM-backed `/`
is not the filesystem to check before a rebuild. `check-storage` checks the
SSD containing `/nix/store` and the HDD at `/data`, requiring 200 GiB available
on each by default. It verifies the HDD's UUID and refuses to proceed if that
drive is missing. Use `check-storage 50` to check a different minimum in GiB.

For large system rebuilds, use:

```console
sudo safe-rebuild switch --flake /etc/nixos#sighurt
```

Before the first rebuild installs the new system packages, the migration
also provides the helpers in `~/.local/bin`. Use
`sudo ~/.local/bin/safe-rebuild switch --flake /etc/nixos#sighurt` for that
first rebuild.

`safe-rebuild` and the updated `switch-reboot` refuse to start below 200 GiB
available on either drive. The helper serializes rebuilds, ensures the existing
32 GiB disk swap file is active, and explicitly sets one build job, two cores,
the HDD build directory and the garbage collection thresholds. This also
protects the first rebuild before the new system generation is activated.
Plain `nixos-rebuild` is still available and does not run these helper checks.
The check is an initial headroom check, not a prediction of a build's peak size.

Nix also attempts collection below 100 GiB, aiming for 200 GiB free. These
thresholds cannot reclaim Cargo targets, games or models, or store paths still
referenced by profiles and GC roots. An hourly systemd timer warns through
the journal and logged-in terminals when headroom falls below 100 GiB.

SMART monitoring covers detected drives and keeps its state under persistent
`/var/lib/smartmontools`. Inspect warnings with `journalctl -u smartd` and
space warnings with `journalctl -u storage-space-warning`.

## Build memory and temporary storage

The 2026-10-29 rebuild failure was a kernel out-of-memory kill of Nix, while
the SSD still had 319 GiB available. This host has 16 GiB RAM and zram swap;
zram stores compressed pages in RAM and cannot substitute for disk capacity.
A private 32 GiB swap file at `/persist/swap/swapfile` now provides overflow
capacity. Its priority is below zram's. It is already active, is declared in
`swapDevices` for future boots, and the helper can activate it after a reboot
even before the first successful system rebuild. Swapping can slow builds.

Nix's temporary build directories now use `/data/nixos-data/nix-builds`, on
the HDD. The directory is root-owned, mode 0711, and is never world-writable.
The daemon requires the HDD mount. Final store outputs remain on the SSD.
Default build parallelism is one derivation with two cores; individual build
systems may have their own limits. Free space is finite, and collection cannot
remove live outputs, so these settings provide headroom rather than an
unconditional guarantee for builds of any size.

## Bulk storage

Before this change, the NVMe SSD held the running NixOS installation and
its complete persistent home. The HDD still held an unmounted Arch Linux
installation. Application defaults under the home directory therefore used
the SSD; the two drives did not automatically share space.

The 3 TB WD HDD is mounted by UUID at `/data`. Its old Arch Linux OS, game
installations and replaceable caches were removed on 2026-10-26. Personal
files were retained in `/data/nixos-data/gusahlg/arch-keepsakes-20261026`;
`~/Arch-keepsakes` and `~/Arch-recordings` provide convenient access. The
recordings were renamed on the same filesystem, preserving their original
inodes and contents.

The approved relocation keeps existing application paths through symlinks:

| Existing path | HDD destination |
| --- | --- |
| `~/models` | `/data/nixos-data/gusahlg/models` |
| `~/Games` | `/data/nixos-data/gusahlg/Games` |
| `~/.local/share/Steam/steamapps/common` | `/data/nixos-data/gusahlg/steam-common` |
| `~/.local/share/Steam/steamapps` | `/data/nixos-data/gusahlg/steamapps` |

Nix, active repository sources, the Steam client, shader caches
and Proton compatibility data remain on the SSD. The latter two are kept
under `~/.local/share/steam-ssd-cache` with links from `steamapps`. Steam's
installation manifests, downloads and staging directories share the HDD
with its game content, so update-time renames stay on the same filesystem.
Game and model loading from the HDD can take longer. The HDD mount uses
`nofail` and automount, so
a missing HDD does not stop the OS booting; accessing the relocated folders
then fails rather than silently putting new bulk data on the SSD.

On 2026-10-29, 167.6 GiB of regenerable Cargo build outputs were removed from
the `sighurt`, `watt-start` and `simulation` repositories, after checking that
the directories were genuine Cargo caches and not in use. Those three
repositories' `target` paths now link to their separate directories under
`/data/nixos-data/gusahlg/cargo-targets`, so future builds use the HDD. Their
source files were retained. Other projects' build caches remain on the SSD.

The migration copies ownership, hard links, ACLs, extended attributes and
sparse files; compares file checksums and metadata; flushes the HDD; and only
then redirects the original path and removes the verified SSD copy. Logs and
per-folder completion records are in `/data/nixos-data/maintenance`. A folder
is finished only when its `relocation-*.json` file says `"phase": "done"`.
A configuration snapshot from before migration is in
`/data/nixos-data/backups/nixos-config-before-migration-20261026`.

Until the first successful system rebuild installs this mount in the system
generation, the current default boot entry includes a verified
`systemd.mount-extra` argument for `/data`. Its original entry is saved under
`/boot/storage-migration-backup`. Older rollback entries are unchanged; when
booting one, mount the HDD explicitly if its `/data` mount is absent. The
permanent mount is declared in `storage.nix`.
