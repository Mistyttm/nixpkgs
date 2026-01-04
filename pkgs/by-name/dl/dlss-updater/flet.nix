# Pinned flet 0.28.3 for DLSS-Updater
#
# We cannot use the nixpkgs flet package because:
# 1. nixpkgs has flet 0.80.0 which is broken (uses poetry-core but upstream switched to setuptools)
# 2. DLSS-Updater requires flet 0.28.3 specifically
# 3. The flet binary downloads at runtime to ~/.flet/bin, which doesn't work on NixOS
#    because the binaries aren't patched for the Nix dynamic linker
#
# This module provides:
# - flet: Python package from PyPI wheel
# - flet-desktop-light: Native Flutter client for Linux
# - flet-bin: Pre-patched flet binary with autoPatchelfHook
{
  lib,
  python3Packages,
  fetchPypi,
  fetchurl,
  autoPatchelfHook,
  mpv,
  gtk3,
  glib,
  pango,
  harfbuzz,
  cairo,
  gdk-pixbuf,
  libepoxy,
  xorg,
  libGL,
  stdenv,
  gst_all_1,
}:

let
  version = "0.28.3";

  # Extract and patch the flet binary from the upstream tar.gz
  flet-bin = stdenv.mkDerivation {
    pname = "flet-bin";
    inherit version;

    src = fetchurl {
      url = "https://github.com/flet-dev/flet/releases/download/v${version}/flet-linux-amd64.tar.gz";
      hash = "sha256-eMOsVhm3O/T9+EDY0WzzM4mkSEfc2rdGb+m6o+O300U=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib
      mpv
      gtk3
      glib
      pango
      harfbuzz
      cairo
      gdk-pixbuf
      libepoxy
      xorg.libX11
      libGL
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ];

    # libmpv.so.1 is not available in nixpkgs (only libmpv.so.2), but
    # DLSS-Updater doesn't use video playback features so we can ignore it
    autoPatchelfIgnoreMissingDeps = [ "libmpv.so.1" ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      mkdir -p $out
      tar -xzf $src -C $out
    '';

    installPhase = ''
      chmod +x $out/flet/flet
      # Create symlink for libmpv.so.1 -> libmpv.so.2 since nixpkgs only has mpv 0.41+ (libmpv.so.2)
      # but the flet binary expects libmpv.so.1
      ln -s ${mpv}/lib/libmpv.so.2 $out/flet/lib/libmpv.so.1
    '';

    # Fix RPATH to include the flet/lib directory for the libmpv symlink
    postFixup = ''
      patchelf --add-rpath $out/flet/lib $out/flet/lib/libmedia_kit_video_plugin.so
      patchelf --add-rpath $out/flet/lib $out/flet/lib/libmedia_kit_native_event_loop.so
    '';

    meta = {
      description = "Flet desktop client binary";
      homepage = "https://flet.dev/";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  };

  # Flet Python package from PyPI wheel
  flet = python3Packages.buildPythonPackage {
    pname = "flet";
    inherit version;
    format = "wheel";

    src = fetchPypi {
      pname = "flet";
      inherit version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-ZJv8SveTOVbs9Elj32wNmXv/nO6vidPIbZaAOEDKuD4=";
    };

    dependencies = with python3Packages; [
      httpx
      oauthlib
      repath
    ];

    pythonImportsCheck = [ "flet" ];

    meta = {
      description = "Flet for Python - easily build interactive multi-platform apps";
      homepage = "https://flet.dev/";
      license = lib.licenses.asl20;
    };
  };

  # Flet Desktop Light for Linux (contains native Flutter client)
  flet-desktop-light = python3Packages.buildPythonPackage {
    pname = "flet-desktop-light";
    inherit version;
    format = "wheel";

    src = fetchPypi {
      pname = "flet_desktop_light";
      inherit version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "manylinux2014_x86_64.manylinux_2_17_x86_64";
      hash = "sha256-89xHOq6NbPQnDlm7tR6BkGjDQ6SaiDbM7S0X+wNZp/U=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib
      mpv
      gtk3
      glib
      pango
      harfbuzz
      cairo
      gdk-pixbuf
      libepoxy
      xorg.libX11
      libGL
    ];

    dependencies = [
      flet
    ];

    pythonImportsCheck = [ "flet_desktop" ];

    meta = {
      description = "Flet Desktop client in Flutter (light version for Linux)";
      homepage = "https://flet.dev/";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  };

in
{
  inherit
    flet
    flet-desktop-light
    flet-bin
    version
    ;
}
