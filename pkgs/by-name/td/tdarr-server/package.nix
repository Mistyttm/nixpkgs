{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  ffmpeg,
  handbrake ? null,
  mkvtoolnix,
  ccextractor,
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
  makeDesktopItem,
  copyDesktopItems,
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
    linux_x64 = "sha256-+nxwSGAkA+BPf481N6KHW7s0iJzoGFPWp0XCbsVEwrI=";
    linux_arm64 = "sha256-tA5VX27XmH3C4Bkll2mJlr1BYz5V7PPvzbJeaDht7uI=";
    darwin_x64 = "sha256-jgHEezqtzUWTIvmxsmV1VgaXY9wHePkg6bQO16eSSGI=";
    darwin_arm64 = "sha256-pcPpqFbqYsXf5Og9uC+eF/1kOQ1ZiletDzkk3qavPS0=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tdarr-server";
  version = "2.58.02";

  src = fetchzip {
    url = "https://storage.tdarr.io/versions/${finalAttrs.version}/${platform}/Tdarr_Server.zip";
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
    mkdir -p $out/{bin,share/tdarr-server}
  '';

  installPhase = ''
    runHook preInstall

    # Copy Server contents (source is already unpacked)
    cp -r . $out/share/tdarr-server/

    chmod +x $out/share/tdarr-server/Tdarr_Server
    # Tdarr_Server_Tray may not be available on all platforms
    if [ -f $out/share/tdarr-server/Tdarr_Server_Tray ]; then
      chmod +x $out/share/tdarr-server/Tdarr_Server_Tray
    fi

    runHook postInstall
  '';

  postInstall = ''
    makeWrapper $out/share/tdarr-server/Tdarr_Server $out/bin/tdarr-server \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            ffmpeg
            mkvtoolnix
            ccextractor
          ]
          ++ lib.optional (handbrake' != null) handbrake'
        )
      } \
      --run "export rootDataPath=\''${rootDataPath:-/var/lib/tdarr/server}" \
      --run "mkdir -p \"\$rootDataPath\"/configs \"\$rootDataPath\"/logs" \
      --run "cd \"\$rootDataPath\"" \
      --set-default ffmpegPath "${ffmpeg}/bin/ffmpeg" \
      --set-default mkvpropeditPath "${mkvtoolnix}/bin/mkvpropedit" \
      --set-default ffprobePath "${ffmpeg}/bin/ffprobe" \
      --set-default ccextractorPath "${ccextractor}/bin/ccextractor" \
      ${lib.optionalString (
        handbrake' != null
      ) ''--set-default handbrakePath "${handbrake'}/bin/HandBrakeCLI"''}

    # Tdarr_Server_Tray may not be available on all platforms
    if [ -f $out/share/tdarr-server/Tdarr_Server_Tray ]; then
      makeWrapper $out/share/tdarr-server/Tdarr_Server_Tray $out/bin/tdarr-server-tray
    fi

    # Install icons from the copied source files (Linux only)
    if [[ "${stdenv.hostPlatform.system}" == *linux* ]]; then
      for size in 192 512; do
        if [ -f $out/share/tdarr-server/public/logo''${size}.png ]; then
          install -Dm644 $out/share/tdarr-server/public/logo''${size}.png \
            $out/share/icons/hicolor/''${size}x''${size}/apps/tdarr-server.png
        fi
      done
    fi
  '';

  desktopItems = lib.optionals (stdenv.isLinux && stdenv.hostPlatform.system != "aarch64-linux") [
    (makeDesktopItem {
      desktopName = "Tdarr Server Tray";
      name = "Tdarr Server Tray";
      exec = "tdarr-server-tray";
      terminal = false;
      type = "Application";
      icon = "tdarr-server";
      categories = [
        "Utility"
      ];
    })
  ];

  passthru.updateScript = ./update-hashes.sh;

  meta = {
    description = "Distributed transcode automation server using FFmpeg/HandBrake";
    homepage = "https://tdarr.io";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = with lib.maintainers; [ mistyttm ];
    mainProgram = "tdarr-server";
  };
})
