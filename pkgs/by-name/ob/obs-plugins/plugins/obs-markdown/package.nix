{
  lib,
  mkObsPlugin,
  fetchFromGitHub,
  cmake,
}:

mkObsPlugin (finalAttrs: {
  pname = "obs-markdown";
  version = "0.2.7";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-markdown";
    rev = finalAttrs.version;
    hash = "sha256-5ajX/cEa0n12Putx1k3ctl1v9wRzJRhyJNDlmjSMbeU=";
  };

  nativeBuildInputs = [ cmake ];

  postInstall = ''
    rm -rf $out/obs-plugins $out/data
  '';

  meta = {
    description = "Plugin for OBS Studio to add Markdown sources";
    homepage = "https://github.com/exeldro/obs-markdown";
    maintainers = with lib.maintainers; [ flexiondotorg ];
    license = lib.licenses.gpl2Only;
  };
})
