{ lib, rustPlatform, pkg-config, wayland, libxkbcommon, src }:

rustPlatform.buildRustPackage {
  pname = "gharial";
  version = "0.3.0";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    wayland
    libxkbcommon
  ];

  meta = with lib; {
    description = "External window manager for the River Wayland compositor";
    homepage = "https://github.com/gusahlg/gharial";
    license = with licenses; [ mit asl20 ];
    platforms = platforms.linux;
  };
}
