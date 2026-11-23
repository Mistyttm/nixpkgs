{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
  curl,
  qt6,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-vertical-canvas";
  version = "1.6.8";

  src = fetchFromGitHub {
    owner = "Aitum";
    repo = "obs-vertical-canvas";
    rev = finalAttrs.version;
    hash = "sha256-GwKlckNMwuC9SZq3JzuPXtVEaOp5FMqT+IupyJt6w7w=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    curl
    qt6.qtbase
  ];

  cmakeFlags = [
    "-DBUILD_OUT_OF_TREE=On"
    ''-DCMAKE_CXX_FLAGS="-Wno-error=deprecated-declarations"''
  ];

  dontWrapQtApps = true;

  postInstall = ''
    rm -rf $out/data
    rm -rf $out/obs-plugins
  '';

  meta = {
    description = "Plugin for OBS Studio to add vertical canvas";
    homepage = "https://github.com/Aitum/obs-vertical-canvas";
    maintainers = with lib.maintainers; [
      flexiondotorg
      jonhermansen
    ];
    license = lib.licenses.gpl2Plus;
  };
})
