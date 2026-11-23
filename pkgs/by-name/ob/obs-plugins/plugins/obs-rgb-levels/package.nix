{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-rgb-levels";
  version = "1.0.3";

  src = fetchFromGitHub {
    owner = "wimpysworld";
    repo = "obs-rgb-levels";
    rev = finalAttrs.version;
    hash = "sha256-DXrDyIBe2tp+9M39PLDf/AmX7lBa2teduBC8FG0IK7Y=";
  };

  nativeBuildInputs = [ cmake ];

  meta = {
    description = "Simple OBS Studio filter to adjust RGB levels";
    homepage = "https://github.com/wimpysworld/obs-rgb-levels";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    license = lib.licenses.gpl2Only;
  };
})
