{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-scale-to-sound";
  version = "1.2.5";

  src = fetchFromGitHub {
    owner = "dimtpap";
    repo = "obs-scale-to-sound";
    tag = finalAttrs.version;
    hash = "sha256-El5lwQfc33H9KvjttJyjakzRizjLoGz2MbkiRm4zm8E=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DBUILD_OUT_OF_TREE=On"
  ];

  meta = {
    description = "OBS filter plugin that scales a source reactively to sound levels";
    homepage = "https://github.com/dimtpap/obs-scale-to-sound";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    license = lib.licenses.gpl2Plus;
  };
})
