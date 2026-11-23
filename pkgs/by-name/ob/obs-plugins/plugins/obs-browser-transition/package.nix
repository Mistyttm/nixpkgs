{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-browser-transition";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-browser-transition";
    tag = finalAttrs.version;
    hash = "sha256-m5UDqnqipkybXAZqS7c2Sj/mJKrDBkXElyc0I+c1BmE=";
  };

  nativeBuildInputs = [ cmake ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = {
    description = "Plugin for OBS Studio to show a browser source during scene transition";
    homepage = "https://github.com/exeldro/obs-browser-transition";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
})
