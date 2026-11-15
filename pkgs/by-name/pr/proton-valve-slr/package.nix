{
  lib,
  mkProtonSlrDerivation,
  fetchFromGitHub,
  fetchurl,
  dockerTools,
  rustPlatform,
}:

mkProtonSlrDerivation (finalAttrs: {
  pname = "proton-valve-slr";
  version = "11.0-2e";

  steamDisplayName = "Proton ${finalAttrs.version} (Nix, SLR)";

  src = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "Proton";
    tag = "proton-${finalAttrs.version}";
    fetchSubmodules = true;
    hash = lib.fakeHash;
  };

  # STEAMRT_IMAGE in Makefile.in
  sdkImage = dockerTools.pullImage {
    imageName = "registry.gitlab.steamos.cloud/proton/steamrt4/sdk/x86_64";
    imageDigest = "sha256:97526b794ce1a9bed5f891084462260b3a02399569f7438a3a57b5a253001db9";
    finalImageTag = "4.0.20260331.220802-0";
    hash = lib.fakeHash;
  };

  # GECKO_VER, WINEMONO_VER and XALIA_VER in Makefile.in
  contribSrcs = [
    (fetchurl {
      url = "https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86.tar.xz";
      hash = "sha256-LPyNXJSGAuIe/4p4YT4YJvLQM9+WcsrOh/7VboMQr7Y=";
    })
    (fetchurl {
      url = "https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.tar.xz";
      hash = "sha256-/Yj8flN9BY16ir8MHryQxXSJKkZt6GcGom0lRxCoKBQ=";
    })
    (fetchurl {
      url = "https://github.com/madewokherd/wine-mono/releases/download/wine-mono-11.2.0/wine-mono-11.2.0-x86.tar.xz";
      hash = "sha256-yfsuKCOs8wsAC4gGF32w9AdReGE23T+Psr54l7FkPQY=";
    })
    (fetchurl {
      url = "https://github.com/madewokherd/xalia/releases/download/xalia-0.4.9/xalia-0.4.9-net48-mono.zip";
      hash = "sha256-4slKQPaPY2YMwGQFpkG8Tloum5MguWCOAaIf629nCcU=";
    })
  ];

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    sourceRoot = "${finalAttrs.src.name}/gst-plugins-rs";
    hash = lib.fakeHash;
  };

  meta = {
    description = ''
      Compatibility tool for Steam Play based on Wine and additional components, built from source
      in the Proton SDK container for the Steam Linux Runtime.

      (This is intended for use in the `programs.steam.extraCompatPackages` option only.)
    '';
    homepage = "https://github.com/ValveSoftware/Proton";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ mistyttm ];
  };
})
