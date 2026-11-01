{ pkgs, lib, clangStdenv, rustPlatform, makeWrapper, pkg-config, cmake, gnumake, python3, perl, yasm, nasm, m4
, llvm, llvmPackages, which, libxkbcommon, wayland, vulkan-loader, libGL, libx11, libxcb, libxcursor
, libxrandr, libxi, libxext, libxfixes, libxrender, fontconfig, freetype, alsa-lib, udev
, dbus, openssl, libv4l, ffmpeg_8, glib, harfbuzz, pipewire, libdrm, zlib, zstd, bzip2
, libunwind, libsoup_3, libwpe, glib-networking, gst_all_1, bubblewrap, xdg-dbus-proxy, src }:

let
  # Read the version from the pinned source so it can never drift.
  cargoToml = lib.importTOML "${src}/Cargo.toml";

  # Reuse upstream's WPE source, dependencies and Nix sandbox patch, but install
  # into the store rather than the development shell's machine-local prefix.
  wpe = import "${src}/nix/wpewebkit.nix" { inherit pkgs; };
  wpewebkit = clangStdenv.mkDerivation {
    pname = "wpewebkit";
    inherit (wpe) version src;
    inherit (wpe.shell) nativeBuildInputs buildInputs;
    propagatedBuildInputs = [ glib libsoup_3 libwpe ];
    outputs = [ "out" "dev" ];
    patches = [ wpe.sandboxPatch ];

    postPatch = ''
      patchShebangs .
    '';

    cmakeFlags = [
      "-DPORT=WPE"
      "-DCMAKE_BUILD_TYPE=Release"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_LIBEXECDIR=libexec"
      "-DENABLE_WPE_PLATFORM=ON"
      "-DENABLE_WPE_PLATFORM_WAYLAND=ON"
      "-DENABLE_WPE_PLATFORM_DRM=ON"
      "-DENABLE_WPE_PLATFORM_HEADLESS=ON"
      "-DENABLE_WPE_LEGACY_API=ON"
      "-DENABLE_WPE_QT_API=OFF"
      "-DENABLE_DOCUMENTATION=OFF"
      "-DENABLE_INTROSPECTION=ON"
      "-DENABLE_MINIBROWSER=OFF"
      "-DENABLE_BUBBLEWRAP_SANDBOX=ON"
      "-DBWRAP_EXECUTABLE=${lib.getExe bubblewrap}"
      "-DDBUS_PROXY_EXECUTABLE=${lib.getExe xdg-dbus-proxy}"
    ];

    # Linking WebKit alone takes several GB; serialize its links.
    env.WEBKIT_NINJA_LINK_MAX = "1";
    enableParallelBuilding = true;
  };

  gstPlugins = with gst_all_1; [
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
  ];

  # Loaded at runtime by Servo and the Wasm engine (the upstream shell.nix list).
  runtimeLibs = [
    libxkbcommon wayland vulkan-loader libGL
    libx11 libxcb libxcursor libxrandr libxi libxext libxfixes libxrender
    fontconfig freetype alsa-lib udev dbus openssl libv4l
  ];
in
rustPlatform.buildRustPackage {
  pname = "sighurt";
  version = cargoToml.workspace.package.version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # One `sig` executable with both frontends and all three content engines.
  buildAndTestSubdir = "apps/sighurt-browser";
  buildNoDefaultFeatures = true;
  buildFeatures = [ "frontend-gui" "frontend-tui" "engine-servo" "engine-wasm" "engine-wpe" ];

  # The tests need a Wayland compositor and a pty.
  doCheck = false;

  # Same workaround as nixpkgs' servo: the mozjs crates run `cargo metadata`,
  # which must see the vendored sources and the resolved lockfile.
  postPatch = ''
    # cargoSetupPostUnpackHook writes it outside the source root, with a
    # vendor path relative to it; make that path absolute for the copy.
    mkdir -p $cargoDepsCopy/.cargo
    sed "s|^directory = \"cargo-vendor-dir\"|directory = \"$cargoDepsCopy\"|" \
      ../.cargo/config.toml > $cargoDepsCopy/.cargo/config.toml
    for mozjs_dir in $cargoDepsCopy/mozjs_*/; do
      cp Cargo.lock $mozjs_dir
    done
  '';

  preConfigure = ''
    unset AS
    # WPE's build script uses its own pkg-config variable. Nix's setup hooks
    # have assembled this path, including the development outputs below.
    export SIGHURT_WPE_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
  '';

  nativeBuildInputs = [
    makeWrapper pkg-config cmake gnumake python3 perl yasm nasm m4
    llvm llvmPackages.libstdcxxClang llvmPackages.lld which rustPlatform.bindgenHook
  ];

  buildInputs = runtimeLibs ++ [
    ffmpeg_8 glib harfbuzz pipewire libdrm zlib zstd bzip2 libunwind wpewebkit
  ];

  # Nix's fortify hardening breaks jemalloc's -O0 configure step inside Servo's build.
  hardeningDisable = [ "fortify" ];

  env = {
    # The sandbox has no network; build SpiderMonkey instead of downloading it.
    MOZJS_FROM_SOURCE = "1";
    NIX_CFLAGS_COMPILE = "-Wno-error=format-security";
  };

  postFixup = ''
    wrapProgram "$out/bin/sig" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins}"
  '';

  passthru = { inherit wpewebkit; };

  meta = with lib; {
    description = "Small Wayland browser with compiled-in content engines";
    homepage = "https://github.com/gusahlg/sighurt";
    license = licenses.agpl3Plus;
    platforms = platforms.linux;
    mainProgram = "sig";
  };
}
