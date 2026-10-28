{ config, lib, ... }:

let
  # This is sighurt's existing ext4 root. It becomes the persistent backing
  # store, so enabling impermanence is a zero-copy migration: the current
  # /nix, /home and declared state are already in the right locations.
  persistentDevice = "/dev/disk/by-uuid/a95305fb-da56-4748-84df-4a1689d910fd";
  userHome = "/home/gusahlg";
in
{
  # Keep this a hard guarantee: if either account definition moves, evaluation
  # must fail rather than booting with the real home on the disposable root.
  assertions = [
    {
      assertion = config.users.users.gusahlg.home == userHome;
      message = "gusahlg's NixOS home must remain at ${userHome} so it is persistent.";
    }
    {
      assertion = config.home-manager.users.gusahlg.home.homeDirectory == userHome;
      message = "gusahlg's Home Manager home must remain at ${userHome} so it is persistent.";
    }
  ];

  # The machine starts from an empty root on every boot. The limit is not
  # preallocated; it only caps how much RAM transient root state may consume.
  fileSystems."/" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
    neededForBoot = true;
    options = [
      "defaults"
      "size=8G"
      "mode=755"
    ];
  };

  # Mount the former root at /persist, then expose its Nix store at /nix.
  # Both mounts are required in the initrd before NixOS activation runs.
  fileSystems."/persist" = {
    device = persistentDevice;
    fsType = "ext4";
    neededForBoot = true;
    options = [ "x-gvfs-hide" ];
  };

  fileSystems."/nix" = {
    device = "/persist/nix";
    fsType = "none";
    neededForBoot = true;
    depends = [ "/persist" ];
    options = [
      "bind"
      "x-gvfs-hide"
    ];
  };

  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      # User data is the conservative persistence boundary. This includes the
      # large Steam/game libraries, repositories, app profiles and credentials
      # already present in gusahlg's home. Since the home itself is mounted,
      # this recursively covers current and future paths such as ~/repos,
      # ~/.ssh, ~/.config, ~/.local/share/flatpak, ~/.var/app and Home
      # Manager's generated files and state.
      {
        directory = userHome;
        user = "gusahlg";
        group = "users";
        mode = "0700";
        allowTrash = true;
      }

      # Locally maintained system configuration and connection profiles.
      {
        directory = "/etc/nixos";
        user = "gusahlg";
        group = "users";
        mode = "0755";
      }
      {
        directory = "/etc/NetworkManager/system-connections";
        mode = "0700";
      }

      # Host and service identity/state. Caches and coredumps are deliberately
      # omitted so they are discarded on reboot.
      "/var/lib/NetworkManager"
      {
        directory = "/var/lib/tailscale";
        mode = "0700";
      }
      "/var/lib/nixos"
      # System Flatpak applications, runtimes, remotes and repository data.
      # Per-user Flatpak state is covered by the persistent home above.
      "/var/lib/flatpak"
      "/var/lib/cups"
      {
        directory = "/var/spool/cups";
        group = "lp";
        mode = "0710";
      }

      # DynamicUser services keep private StateDirectory data here. On this
      # host that includes Ollama's model store.
      {
        directory = "/var/lib/private";
        mode = "0700";
      }

      "/var/lib/lastlog"
      "/var/lib/systemd/linger"
      "/var/lib/systemd/rfkill"
      "/var/lib/systemd/timers"
      {
        directory = "/var/lib/systemd/timesync";
        user = "systemd-timesync";
        group = "systemd-timesync";
        mode = "0755";
      }
      "/var/log"

      # tuigreet's --remember option stores its selection in this directory.
      {
        directory = "/var/cache/tuigreet";
        user = "greeter";
        group = "greeter";
        mode = "0755";
      }
    ];

    files = [
      # Stable host identity. User passwords are declared from files under
      # /persist/secrets, so /etc/shadow must be rebuilt rather than persisted.
      "/etc/machine-id"
      "/etc/adjtime"

      # Keep the SSH host identity stable across reboots.
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"

      "/var/lib/logrotate.status"
      "/var/lib/systemd/random-seed"
    ];
  };
}
