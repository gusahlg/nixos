{ lib, ... }:

{
  # tofi-drun caches the desktop-entry list in ~/.cache/tofi-drun and only
  # rebuilds it when an applications directory is *newer* than that cache.
  # On NixOS every applications dir lives in the nix store with an epoch
  # (1970-01-01) mtime, so the cache is never older than its sources and tofi
  # serves a stale list forever — apps installed after the cache was first
  # built (e.g. heroic) never show up in the drun launcher.
  #
  # Dropping the cache on each home-manager activation forces the next tofi-drun
  # launch to regenerate it, so newly installed apps appear after a rebuild.
  home.activation.invalidateTofiDrunCache =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run rm -f "$HOME/.cache/tofi-drun"
    '';
}
