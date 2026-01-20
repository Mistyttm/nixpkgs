{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  ffmpeg,
  handbrake ? null,
  mkvtoolnix,
  gtk3,
  libayatana-appindicator,
  wayland,
  libxkbcommon,
  mesa,
  libxcb,
  leptonica,
  glib,
  gobject-introspection,
  libx11,
  libxcursor,
  libxfixes,
  tesseract4,
  libredirect,
}:
let
  # handbrake is broken on darwin, so we need to disable it
  handbrake' = if stdenv.hostPlatform.isDarwin then null else handbrake;
  platform =
    {
      x86_64-linux = "linux_x64";
      aarch64-linux = "linux_arm64";
      x86_64-darwin = "darwin_x64";
      aarch64-darwin = "darwin_arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  hashes = {
    linux_x64 = "sha256-+vD5oaoYh/bOCuk/Bxc8Fsm9UnFICownSKvg9i726nk=";
    linux_arm64 = "sha256-2uPtEno0dSdVBg5hCiUuvBCB5tuTOcpeU2BuXPiqdUU=";
    darwin_x64 = "sha256-8O5J1qFpQxD6fzojxjWnbkS4XQoCZauxCtbl/drplfI=";
    darwin_arm64 = "sha256-oA+nTkO4LDAX5/cGkjNOLnPu0Rss9el+4JF8PBEfsPQ=";
  };

in
stdenv.mkDerivation (finalAttrs: {
  pname = "tdarr-node";
  version = "2.58.02";

  src = fetchzip {
    url = "https://storage.tdarr.io/versions/${finalAttrs.version}/${platform}/Tdarr_Node.zip";
    sha256 = hashes.${platform};
    stripRoot = false;
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    gtk3
    libayatana-appindicator
    wayland
    libxkbcommon
    libxcb
    mesa
    tesseract4
    leptonica
    glib
    gobject-introspection
    libx11
    libxcursor
    libxfixes
    libredirect
  ];

  patchPhase = ''
    rm -rf ./assets/app/ffmpeg
    rm -rf ./assets/app/ccextractor
  '';

  preInstall = ''
    mkdir -p $out/{bin,share/tdarr-node}
  '';

  # TODO: Check on each update to see if the Tdarr_Node_tray gets re-added to the aarch64-linux build. Reach out to upstream?

  installPhase = ''
    runHook preInstall

    # Copy Node contents (source is already unpacked)
    cp -r . $out/share/tdarr-node/

    chmod +x $out/share/tdarr-node/Tdarr_Node
    # Tdarr_Node_Tray is not available on aarch64-linux
    if [ -f $out/share/tdarr-node/Tdarr_Node_Tray ]; then
      chmod +x $out/share/tdarr-node/Tdarr_Node_Tray
    fi

    runHook postInstall
  '';

  postInstall = ''
    makeWrapper $out/share/tdarr-node/Tdarr_Node $out/bin/tdarr-node \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            ffmpeg
            mkvtoolnix
          ]
          ++ lib.optional (handbrake' != null) handbrake'
        )
      } \
      --run "export rootDataPath=\''${rootDataPath:-/var/lib/tdarr/node}" \
      --run "mkdir -p \"\$rootDataPath\"/configs \"\$rootDataPath\"/logs \"\$rootDataPath\"/assets/app/plugins" \
      --run "cd \"\$rootDataPath\"" \
      --set-default ffmpegPath "${ffmpeg}/bin/ffmpeg" \
      --set-default ffprobePath "${ffmpeg}/bin/ffprobe" \
      --set-default mkvpropeditPath "${mkvtoolnix}/bin/mkvpropedit" \
      ${lib.optionalString (
        handbrake' != null
      ) ''--set-default handbrakePath "${handbrake'}/bin/HandBrakeCLI"''}

    # Tdarr_Node_Tray is not available on aarch64-linux
    if [ -f $out/share/tdarr-node/Tdarr_Node_Tray ]; then
      makeWrapper $out/share/tdarr-node/Tdarr_Node_Tray $out/bin/tdarr-node-tray
    fi
  '';

  desktopItems = lib.optionals (stdenv.hostPlatform.system != "aarch64-linux") [
    (makeDesktopItem {
      desktopName = "Tdarr Node Tray";
      name = "Tdarr Node Tray";
      exec = "tdarr-node-tray";
      terminal = false;
      type = "Application";
      icon = "";
      categories = [
        "Utility"
      ];
    })
  ];

  passthru.updateScript = ./update-hashes.sh;

  meta = {
    description = "Distributed transcode automation node using FFmpeg/HandBrake";
    homepage = "https://tdarr.io";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = with lib.maintainers; [ mistyttm ];
    mainProgram = "tdarr-node";
  };
})
