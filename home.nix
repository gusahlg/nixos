{ lib, ... }:

let
  # Set this to false to disable HDMI-A-1 entirely. With it disabled,
  # there is no second output or cursor boundary to cross.
  enableHdmiOutput = true;
in
{
  imports = [
    ./home/workstation.nix
    ./home/mangohud.nix
    ./home/hackatime.nix
    ./home/roblox.nix
  ];

  services.kanshi = {
    enable = true;
    systemdTarget = "river-session.target";

    settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "DP-2";
              status = "enable";
              mode = "3440x1440@120Hz";
              position = "0,0";
            }
            ({
              criteria = "HDMI-A-1";
              status = if enableHdmiOutput then "enable" else "disable";
            } // lib.optionalAttrs enableHdmiOutput {
              mode = "1920x1080@60Hz";
              position = "3440,0";
            })
          ];
        };
      }
    ];
  };
}
