{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-noise";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "FiniteSingularity";
    repo = "obs-noise";
    rev = "v${finalAttrs.version}";
    hash = "sha256-koU3xqGZ3gWBGd+EMDG/GkarSB9rZibFasprMSqVFg8=";
  };

  nativeBuildInputs = [ cmake ];

  meta = {
    description = "Plug-in for noise generation and noise effects for OBS";
    homepage = "https://github.com/FiniteSingularity/obs-noise";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    license = lib.licenses.gpl2Only;
  };
})
