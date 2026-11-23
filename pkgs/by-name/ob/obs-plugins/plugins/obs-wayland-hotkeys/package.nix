{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  nix-update-script,
}:
mkObsPlugin (finalAttrs: {
  pname = "obs-wayland-hotkeys";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "leia-uwu";
    repo = "obs-wayland-hotkeys";
    tag = "v${finalAttrs.version}";
    hash = "sha256-m/AW2glyxJLPWcptZYbZ9Befm4gNmD1V3JDC8hjKtkA=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    qt6.qtbase
  ];

  dontWrapQtApps = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "OBS Studio plugin to integrate OBS hotkeys with the Wayland global shortcuts portal";
    homepage = "https://github.com/leia-uwu/obs-wayland-hotkeys";
    maintainers = with lib.maintainers; [ terrorw0lf ];
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux;
  };
})
