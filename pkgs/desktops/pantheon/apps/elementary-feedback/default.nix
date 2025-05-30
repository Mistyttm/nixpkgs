{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  meson,
  ninja,
  vala,
  gtk4,
  glib,
  granite7,
  libadwaita,
  libgee,
  wrapGAppsHook4,
  appstream,
}:

stdenv.mkDerivation rec {
  pname = "elementary-feedback";
  version = "8.0.1";

  src = fetchFromGitHub {
    owner = "elementary";
    repo = "feedback";
    rev = version;
    sha256 = "sha256-D0x0jKYEB6Bo8ETgVCjgdOItc+VJYlrr8N9lI/Z3eXU=";
  };

  patches = [
    # The standard location to the metadata pool where metadata
    # will be read from is likely hardcoded as /usr/share/metainfo
    # https://github.com/ximion/appstream/blob/v0.15.2/src/as-pool.c#L117
    # https://www.freedesktop.org/software/appstream/docs/chap-Metadata.html#spec-component-location
    ./fix-metadata-path.patch
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    vala
    wrapGAppsHook4
  ];

  buildInputs = [
    appstream
    granite7
    gtk4
    libadwaita
    libgee
    glib
  ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "GitHub Issue Reporter designed for elementary OS";
    homepage = "https://github.com/elementary/feedback";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    teams = [ teams.pantheon ];
    mainProgram = "io.elementary.feedback";
  };
}
