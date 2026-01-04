{
  lib,
  python3Packages,
  fetchFromGitHub,
  callPackage,
  makeWrapper,
}:

let
  python3 = python3Packages.python;

  # Pinned flet 0.28.3 - the nixpkgs flet package is broken
  flet = callPackage ./flet.nix { };
in
python3Packages.buildPythonApplication rec {
  pname = "dlss-updater";
  version = "3.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Recol";
    repo = "DLSS-Updater";
    tag = "V${version}";
    hash = "sha256-9i8fMtsMbwf7f2jcc89Ovv9GXlWGsEIiSwr/qbP8FzA=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    pefile
    psutil
    packaging
    appdirs
    flet.flet
    flet.flet-desktop-light
    msgspec
    aiohttp
    aiosqlite
    aiofiles
    pillow
    uvloop
  ];

  pythonRelaxDeps = [
    "flet"
    "flet-desktop"
    "psutil"
    "pillow"
    "aiofiles"
    "aiosqlite"
    "msgspec"
  ];

  # These are build/test tools incorrectly listed as runtime deps in upstream pyproject.toml
  pythonRemoveDeps = [
    "pyinstaller"
    "pytest-codspeed"
  ];

  patches = [
    # Fix logger to write to ~/.local/share/dlss-updater/ instead of install directory
    ./fix-log-path.patch
    # Add __main__.py entry point for running as a module
    ./add-entry-point.patch
    # Fix is_admin/run_as_admin to work on Linux (skip Windows-specific ctypes.windll)
    ./fix-linux-admin-check.patch
  ];

  postPatch = ''
    # The upstream main.py is at root level, not inside the package.
    # Move it into the package so it gets installed properly.
    cp main.py dlss_updater/main.py

    # Update the main.py imports now that it's inside the package
    substituteInPlace dlss_updater/main.py \
      --replace-fail "from dlss_updater." "from ."
  '';

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
        # Create wrapper script since upstream doesn't define a console entry point
        mkdir -p $out/bin
        cat > $out/bin/.dlss-updater-unwrapped << EOF
    #!${python3}/bin/python3
    from dlss_updater.__main__ import *
    if __name__ == "__main__":
        check_prerequisites()
        import flet as ft
        ft.app(target=main)
    EOF
        chmod +x $out/bin/.dlss-updater-unwrapped

        # Wrap with FLET_VIEW_PATH pointing to our patched flet binary
        makeWrapper $out/bin/.dlss-updater-unwrapped $out/bin/dlss-updater \
          --set FLET_VIEW_PATH "${flet.flet-bin}/flet"
  '';

  # Upstream's config.py tries to create directories at module import time,
  # which fails in the Nix sandbox. The package works fine at runtime.
  pythonImportsCheck = [ ];

  # Tests require network access and game installations
  doCheck = false;

  passthru = {
    inherit flet;
  };

  meta = {
    description = "Update DLSS, XeSS, FSR, and DirectStorage DLLs for games on your system";
    homepage = "https://github.com/Recol/DLSS-Updater";
    changelog = "https://github.com/Recol/DLSS-Updater/releases/tag/V${version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ mistyttm ];
    mainProgram = "dlss-updater";
    platforms = [ "x86_64-linux" ];
  };
}
