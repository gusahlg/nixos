{ pkgs, ... }:

let
  checkStorage = import ../../scripts/check-storage.nix { inherit pkgs; };
  safeRebuild = import ../../scripts/safe-rebuild.nix { inherit pkgs; };
in
{
  # The former Arch HDD now holds preserved personal files and bulk data.
  # Keep its existing filesystem and mount it by its stable UUID.
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/e020b0d9-c58d-4687-b229-92d53109620d";
    fsType = "ext4";
    options = [
      "noatime"
      "nodev"
      "nosuid"
      "nofail"
      "x-systemd.automount"
      "x-systemd.device-timeout=15s"
    ];
  };

  # These are best-effort garbage-collection thresholds, not a space quota.
  # Cargo targets, games and model files require their own storage policy.
  nix.settings.min-free = 100 * 1024 * 1024 * 1024;
  nix.settings.max-free = 200 * 1024 * 1024 * 1024;
  nix.settings.max-jobs = 1;
  nix.settings.cores = 2;
  # Build intermediates can dwarf final outputs; keep them off the SSD.
  nix.settings.build-dir = "/data/nixos-data/nix-builds";
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/data/nixos-data/nix-builds" ];
  systemd.tmpfiles.rules = [
    "d /data/nixos-data/nix-builds 0711 root root -"
    "d /persist/swap 0700 root root -"
  ];

  # zram uses RAM itself; disk swap provides additional capacity for evaluation
  # and large browser builds. Its lower priority keeps zram preferred.
  swapDevices = [ {
    device = "/persist/swap/swapfile";
    size = 32 * 1024;
    priority = 0;
  } ];

  environment.systemPackages = [ checkStorage safeRebuild pkgs.smartmontools ];

  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true;
    notifications.x11.enable = false;
  };
  systemd.services.smartd.serviceConfig.StateDirectory = "smartmontools";
  environment.persistence."/persist".directories = [ "/var/lib/smartmontools" ];

  systemd.services.storage-space-warning = {
    description = "Warn when the SSD lacks space for large builds";
    serviceConfig.Type = "oneshot";
    path = [ pkgs.util-linux ];
    script = ''
      if ! ${checkStorage}/bin/check-storage 200; then
        printf '%s\n' 'Storage warning: SSD or HDD build headroom is low, or the HDD is unavailable. Run check-storage before rebuilding.' | wall --nobanner
      fi
    '';
  };

  systemd.timers.storage-space-warning = {
    description = "Check SSD headroom hourly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
    };
  };
}
