{
  alsa-lib, autoPatchelfHook, atk, bash, cairo, cups, dbus, dpkg, fetchurl, ffmpeg, glib,
  glibc, gtk3, lib, libappindicator-gtk3, libdrm, libxcb, libxkbfile, libxkbcommon, makeWrapper, mesa,
  nss, nspr, nix-update-script, pango, pkgs, python3, opencomposite, stdenv, systemd,
  vulkan-loader, xorg, depotdownloader, openssl }:
let
  version = "1.5.0-alpha.6";

  src = if stdenv.hostPlatform.system == "x86_64-linux" then
    fetchurl {
      url = "https://cdn.discordapp.com/attachments/1314040014958755941/1315918410504339527/s5Q912D.deb?ex=67592805&is=6757d685&hm=c1ea86af9133eb77eff5fd2cc89081365a80f2e95657f5f639b60eebc7d3da60&";
      hash = "sha256-4fucCYZNFlbUQeotUyzuHN3B+8zHh+qf46dwdH08sos=";
    }
  else
    throw "BSManager is not available for your platform";

  rpath = lib.makeLibraryPath [
    alsa-lib
    atk
    cairo
    cups
    dbus
    ffmpeg
    glib
    glibc
    gtk3
    libappindicator-gtk3
    libdrm
    libxcb
    libxkbcommon
    libxkbfile
    mesa
    mesa.drivers
    nspr
    nss
    pango
    stdenv.cc.cc
    vulkan-loader
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libXtst
    xorg.libxcb
    xorg.libxkbfile
  ];
in stdenv.mkDerivation {
  pname = "bs-manager";
  inherit version;

  system = "x86_64-linux";

  inherit src;

  runtimeDependencies = [
    bash
    opencomposite
    python3
    systemd
    depotdownloader
    openssl
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    ffmpeg
    gtk3
    mesa
    mesa.drivers
    nspr
    nss
    makeWrapper
    openssl.dev
  ];

  buildInputs = [
    dpkg
    ffmpeg
    openssl.dev
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    dpkg -x $src $out
    cp -av $out/usr/* $out
    rm -rf $out/usr

    # Otherwise it looks "suspicious"
    chmod -R g-w $out

    export FONTCONFIG_FILE=${pkgs.makeFontsConf { fontDirectories = []; }}

    patchelf --set-rpath $out/opt/BSManager $out/opt/BSManager/bs-manager

    for file in $(find $out -type f \( -perm /0111 -o -name \*.so\* \)); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath} "$file" || true
    done

    mkdir -p $out/bin
    ln -s $out/opt/BSManager/bs-manager $out/bin/bs-manager

    runHook postInstall
  '';

  postInstall = ''
    # Create a wrapper script to use the correct LD_LIBRARY_PATH
    mv $out/opt/BSManager/resources/assets/scripts/DepotDownloader $out/opt/BSManager/resources/assets/scripts/DepotDownload
    cat > $out/opt/BSManager/resources/assets/scripts/DepotDownloader <<EOF
    #!/bin/sh
    export LD_LIBRARY_PATH=${openssl.out}/lib:$LD_LIBRARY_PATH
    $out/opt/BSManager/resources/assets/scripts/DepotDownload "\$@"
    EOF

    chmod +x $out/opt/BSManager/resources/assets/scripts/DepotDownloader

    # Update the desktop file
    substituteInPlace $out/share/applications/bs-manager.desktop \
      --replace /opt/BSManager/bs-manager \
      "$out/bin/bs-manager"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    changelog = "https://github.com/Zagrios/bs-manager/blob/master/CHANGELOG.md";
    description = "BSManager: Your Beat Saber Assistant";
    homepage = "https://github.com/Zagrios/bs-manager";
    licence = lib.licence.gpl3Only;
    mainProgram = "bs-manager";
    maintainers = with lib.maintainers; [ mistyttm ];
  };
}
