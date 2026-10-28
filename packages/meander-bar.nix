{
  lib,
  makeWrapper,
  rustPlatform,
  meanderSrc,
  font,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "meander-bar";
  version = "1.0.0";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'MEANDER_ROOT_PLACEHOLDER' '${meanderSrc}'
  '';

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram "$out/bin/meander-bar" \
      --set MEANDER_BAR_FONT '${font}'
  '';

  meta = {
    description = "Minimal per-output Gharial bar built with Meander";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "meander-bar";
  };
}
