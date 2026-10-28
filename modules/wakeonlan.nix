# /etc/nixos/modules/wakeonlan.nix
#
# Wake-on-LAN for every wired NIC, driven entirely through NetworkManager.
#
# The usual NixOS route, `networking.interfaces.<if>.wakeOnLan.enable`,
# programs WoL with a systemd/udev ethtool rule. That is unreliable once
# NetworkManager manages the link: NM re-applies its own Wake-on-LAN policy
# each time it (re)activates a connection and clobbers the earlier setting,
# leaving `ethtool` reporting `Wake-on: d` (see nixpkgs#415213). So we let
# NetworkManager own the setting instead of fighting it.
#
# Import this from a host's `imports` list; it is interface-agnostic, so it
# needs no per-host tweaking (it matches every Ethernet device by type).
{ pkgs, ... }:

{
  networking.networkmanager = {
    # Declarative default: every Ethernet connection NetworkManager manages
    # should wake on the magic packet. 64 == NM_SETTING_WIRED_WAKE_ON_LAN_MAGIC;
    # the numeric form is what NetworkManager.conf connection-defaults expect
    # (the string "magic" is only reliably parsed by nmcli, not here).
    settings.connection-wol = {
      match-device = "type:ethernet";
      "ethernet.wake-on-lan" = 64;
    };

    # Belt and braces: whenever an interface comes up, poke the NIC directly
    # with ethtool. This guarantees the link-level bit is set even if a saved
    # connection profile pins its own wake-on-lan value and shadows the global
    # default above. It runs from NetworkManager's dispatcher, so WoL stays
    # "the NetworkManager way" end to end.
    dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "enable-wol" ''
          iface="$1"
          action="$2"
          [ "$action" = "up" ] || exit 0

          # Only touch wired NICs that actually advertise magic-packet support
          # (the "g" flag in ethtool's "Supports Wake-on:" line). Wireless and
          # virtual interfaces are skipped, and a NIC that cannot do WoL is a
          # no-op rather than an error.
          if ${pkgs.ethtool}/bin/ethtool "$iface" 2>/dev/null \
              | grep -qE '^[[:space:]]*Supports Wake-on:.*g'; then
            ${pkgs.ethtool}/bin/ethtool -s "$iface" wol g || true
          fi
        '';
      }
    ];
  };

  # `ethtool` to inspect/set the NIC directly; `wakeonlan` to send the magic
  # packet from this host to another.
  environment.systemPackages = with pkgs; [
    ethtool
    wakeonlan
  ];
}
