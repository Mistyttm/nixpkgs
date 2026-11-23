{
  lib,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  mkObsPlugin,
  onnxruntime,
  opencv,
  qt6,
  curl,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-backgroundremoval";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "occ-ai";
    repo = "obs-backgroundremoval";
    tag = finalAttrs.version;
    hash = "sha256-ND4owZCJvJmpuyYY5svGezVvid+Pi9hgU2W8EUv597s=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    onnxruntime
    opencv.cxxdev
    qt6.qtbase
    curl
  ];

  dontWrapQtApps = true;

  cmakeFlags = [
    "-DUSE_SYSTEM_ONNXRUNTIME=ON"
    "-DUSE_SYSTEM_OPENCV=ON"
    "-DENABLE_FRONTEND_API=OFF"
    "-DENABLE_QT=OFF"
  ];

  meta = {
    description = "OBS plugin to replace the background in portrait images and video";
    homepage = "https://github.com/occ-ai/obs-backgroundremoval";
    maintainers = with lib.maintainers; [
      randomizedcoder
      zahrun
    ];
    license = lib.licenses.gpl3Plus;
  };
})
