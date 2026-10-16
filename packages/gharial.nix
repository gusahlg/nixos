{ lib, rustPlatform, pkg-config, wayland, libxkbcommon, src }:

let
  # Read the version from the pinned source so it can never drift.
  cargoToml = lib.importTOML "${src}/Cargo.toml";
in
rustPlatform.buildRustPackage {
  pname = "gharial";
  version = cargoToml.workspace.package.version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Only the daemon and its CLI; the workspace also holds an example init
  # whose binary must not land on PATH next to the real one.
  cargoBuildFlags = [ "-p" "gharial" "-p" "gharialctl" ];
  cargoTestFlags = [ "-p" "gharial" "-p" "gharialctl" "-p" "gharial-ipc" ];

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
    mainProgram = "gharial";
  };
}
