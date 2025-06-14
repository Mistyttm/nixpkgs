{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  makeDesktopItem,
  yarnConfigHook,
  nodejs,
  fetchYarnDeps,
  jq,
  electron_35,
  element-web,
  sqlcipher,
  callPackage,
  desktopToDarwinBundle,
  useKeytar ? true,
  # command line arguments which are always set
  commandLineArgs ? "",
}:

let
  pinData = import ./element-desktop-pin.nix;
  inherit (pinData.hashes) desktopSrcHash desktopYarnHash;
  executableName = "element-desktop";
  electron = electron_35;
  keytar = callPackage ./keytar {
    inherit electron;
  };
  seshat = callPackage ./seshat { };
in
stdenv.mkDerivation (
  finalAttrs:
  builtins.removeAttrs pinData [ "hashes" ]
  // {
    pname = "element-desktop";
    name = "${finalAttrs.pname}-${finalAttrs.version}";
    src = fetchFromGitHub {
      owner = "element-hq";
      repo = "element-desktop";
      rev = "v${finalAttrs.version}";
      hash = desktopSrcHash;
    };

    offlineCache = fetchYarnDeps {
      yarnLock = finalAttrs.src + "/yarn.lock";
      sha256 = desktopYarnHash;
    };

    nativeBuildInputs = [
      yarnConfigHook
      nodejs
      makeWrapper
      jq
    ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ desktopToDarwinBundle ];

    inherit seshat;

    # Only affects unused scripts in $out/share/element/electron/scripts. Also
    # breaks because there are some `node`-scripts with a `npx`-shebang and
    # this shouldn't be in the closure just for unused scripts.
    dontPatchShebangs = true;

    buildPhase = ''
      runHook preBuild

      yarn --offline run build:ts
      yarn --offline run i18n
      yarn --offline run build:res

      rm -rf node_modules/matrix-seshat node_modules/keytar-forked
      ${lib.optionalString useKeytar "ln -s ${keytar} node_modules/keytar-forked"}
      ln -s $seshat node_modules/matrix-seshat

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # resources
      mkdir -p "$out/share/element"
      ln -s '${element-web}' "$out/share/element/webapp"
      cp -r '.' "$out/share/element/electron"
      cp -r './res/img' "$out/share/element"
      rm -rf "$out/share/element/electron/node_modules"
      cp -r './node_modules' "$out/share/element/electron"
      cp $out/share/element/electron/lib/i18n/strings/en_EN.json $out/share/element/electron/lib/i18n/strings/en-us.json
      ln -s $out/share/element/electron/lib/i18n/strings/en{-us,}.json

      # icons
      for icon in $out/share/element/electron/build/icons/*.png; do
        mkdir -p "$out/share/icons/hicolor/$(basename $icon .png)/apps"
        ln -s "$icon" "$out/share/icons/hicolor/$(basename $icon .png)/apps/element.png"
      done

      # desktop item
      mkdir -p "$out/share"
      ln -s "${finalAttrs.desktopItem}/share/applications" "$out/share/applications"

      # executable wrapper
      # LD_PRELOAD workaround for sqlcipher not found: https://github.com/matrix-org/seshat/issues/102
      makeWrapper '${electron}/bin/electron' "$out/bin/${executableName}" \
        --set LD_PRELOAD ${sqlcipher}/lib/libsqlcipher.so \
        --add-flags "$out/share/element/electron" \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
        --add-flags ${lib.escapeShellArg commandLineArgs}

      runHook postInstall
    '';

    # The desktop item properties should be kept in sync with data from upstream:
    # https://github.com/element-hq/element-desktop/blob/develop/package.json
    desktopItem = makeDesktopItem {
      name = "element-desktop";
      exec = "${executableName} %u";
      icon = "element";
      desktopName = "Element";
      genericName = "Matrix Client";
      comment = finalAttrs.meta.description;
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      startupWMClass = "Element";
      mimeTypes = [
        "x-scheme-handler/element"
        "x-scheme-handler/io.element.desktop"
      ];
    };

    postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
      cp build/icon.icns $out/Applications/Element.app/Contents/Resources/element.icns
    '';

    passthru = {
      # run with: nix-shell ./maintainers/scripts/update.nix --argstr package element-desktop
      updateScript = ./update.sh;

      # TL;DR: keytar is optional while seshat isn't.
      #
      # This prevents building keytar when `useKeytar` is set to `false`, because
      # if libsecret is unavailable (e.g. set to `null` or fails to build), then
      # this package wouldn't even considered for building because
      # "one of the dependencies failed to build",
      # although the dependency wouldn't even be used.
      #
      # It needs to be `passthru` anyways because other packages do depend on it.
      inherit keytar;
    };

    meta = with lib; {
      description = "Feature-rich client for Matrix.org";
      homepage = "https://element.io/";
      changelog = "https://github.com/element-hq/element-desktop/blob/v${finalAttrs.version}/CHANGELOG.md";
      license = licenses.asl20;
      teams = [ teams.matrix ];
      platforms = electron.meta.platforms ++ lib.platforms.darwin;
      mainProgram = "element-desktop";
    };
  }
)
