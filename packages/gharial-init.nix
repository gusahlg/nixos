{ lib, makeWrapper, rustPlatform, dbus, systemd, gharialIpcSrc, src }:

rustPlatform.buildRustPackage {
  pname = "gharial-init-rs";
  version = "1";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail '@gharial-ipc@' '${gharialIpcSrc}'
  '';

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram "$out/bin/gharial-init-rs" \
      --prefix PATH : ${lib.makeBinPath [ dbus systemd ]}
  '';
}
