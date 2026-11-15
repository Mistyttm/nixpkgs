{
  lib,
  mkProtonDerivation,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
}:

mkProtonDerivation (finalAttrs: {
  pname = "proton-valve";
  version = "11.0-2e";

  steamDisplayName = "Proton ${finalAttrs.version} (Nix)";

  src = fetchFromGitHub {
    owner = "ValveSoftware";
    repo = "Proton";
    tag = "proton-${finalAttrs.version}";
    fetchSubmodules = true;
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
      against nixpkgs. It runs outside the Steam Linux Runtime.

      (This is intended for use in the `programs.steam.extraCompatPackages` option only.)
    '';
    homepage = "https://github.com/ValveSoftware/Proton";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ mistyttm ];
  };
})
