{
  lib,
  stdenv,
  fetchFromGitHub,
  writeText,
  fontconfig,
  imlib2,
  libX11,
  libXft,
  libXinerama,
  conf ? null,
}:

stdenv.mkDerivation rec {
  pname = "xnotify";
  version = "0.9.3";

  src = fetchFromGitHub {
    owner = "phillbush";
    repo = "xnotify";
    rev = "v${version}";
    hash = "sha256-RfnmiAEFTPqQZursyVPDIZ6J3KBouvaaxyhTc1liqBc=";
  };

  buildInputs = [
    fontconfig
    imlib2
    libX11
    libXft
    libXinerama
  ];

  postPatch =
    let
      configFile =
        if lib.isDerivation conf || builtins.isPath conf then conf else writeText "config.h" conf;
    in
    lib.optionalString (conf != null) "cp ${configFile} config.h";

  makeFlags = [ "PREFIX=$(out)" ];

  meta = with lib; {
    description = "Tool to read notifications from stdin and pop them up on the screen";
    longDescription = ''
      XNotify displays a notification on the screen. XNotify receives a
      notification specification in stdin and shows a notification for the user
      on the screen.
    '';
    homepage = "https://github.com/phillbush/xnotify";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "xnotify";
  };
}
