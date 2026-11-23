{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-move-transition";
  version = "3.2.1-unstable-2026-10-04";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-move-transition";
    rev = "64590490d87d93cc03baf0b35b90709468d9fb03";
    hash = "sha256-GOXNUwA2ASzDHMjsXSdUYQzqOtEBwmrr3oz5TXueKjY=";
  };

  nativeBuildInputs = [ cmake ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = {
    description = "Plugin for OBS Studio to move source to a new position during scene transition";
    homepage = "https://github.com/exeldro/obs-move-transition";
    maintainers = with lib.maintainers; [ starcraft66 ];
    license = lib.licenses.gpl2Plus;
  };
})
