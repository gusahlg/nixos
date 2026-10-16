{ lib, writeText, makeWrapper, rustPlatform, dbus, systemd, gharialSrc, src }:

let
  gharialIpcSrc = "${gharialSrc}/crates/gharial-ipc";
  ipcVersion = (lib.importTOML "${gharialSrc}/Cargo.toml").workspace.package.version;

  # The init's Cargo.lock records gharial-ipc's version; a pin bump would
  # otherwise fail the build until someone edits it by hand. Rewrite that
  # one entry to whatever the pinned source says.
  lockText = builtins.readFile "${src}/Cargo.lock";
  lockedIpc = lib.findFirst (p: p.name == "gharial-ipc")
    (throw "river/gharial-init/Cargo.lock has no gharial-ipc entry")
    (builtins.fromTOML lockText).package;
  lockFile = writeText "Cargo.lock" (builtins.replaceStrings
    [ "name = \"gharial-ipc\"\nversion = \"${lockedIpc.version}\"" ]
    [ "name = \"gharial-ipc\"\nversion = \"${ipcVersion}\"" ]
    lockText);
in
rustPlatform.buildRustPackage {
  pname = "gharial-init-rs";
  version = "1";
  inherit src;

  cargoLock.lockFile = lockFile;

  postPatch = ''
    cp ${lockFile} Cargo.lock
    substituteInPlace Cargo.toml \
      --replace-fail '@gharial-ipc@' '${gharialIpcSrc}'
  '';

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram "$out/bin/gharial-init-rs" \
      --prefix PATH : ${lib.makeBinPath [ dbus systemd ]}
  '';
}
