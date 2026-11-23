{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "obs-plugins";
  version = "0";

  __structuredAttrs = true;
  strictDeps = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    runHook postInstall
  '';

  meta = {
    description = "Dummy package for the OBS Studio plugin package set";
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
