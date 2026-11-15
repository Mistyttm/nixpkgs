# Builds Proton from source inside Valve's Proton SDK container image, the same
# environment upstream uses for releases. The result targets the Steam Linux Runtime
# and keeps the `require_tool_appid` in toolmanifest.vdf, so Steam runs it inside
# pressure-vessel like an upstream build.
#
# Upstream's Makefile has an outer mode that starts the SDK image with docker/podman
# and an inner mode (CONTAINER=1) that does the real build. We skip the outer mode
# and run the inner one ourselves, using bubblewrap to enter the unpacked image.
{
  lib,
  stdenvNoCC,
  runCommand,
  bubblewrap,
  skopeo,
  umoci,
}:

lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;

  excludeDrvArgNames = [
    "sdkImage"
    "contribSrcs"
  ];

  extendDrvArgs =
    finalAttrs:
    {
      # A `dockerTools.pullImage` of the STEAMRT_IMAGE pinned in the source's Makefile.in
      sdkImage,
      # Files the Makefile would otherwise download into contrib/ (wine-gecko, wine-mono, ...)
      contribSrcs ? [ ],
      # Vendored crates for gst-plugins-rs, from `rustPlatform.fetchCargoVendor`
      cargoDeps ? null,
      steamDisplayName ? finalAttrs.pname,
      internalToolName ? finalAttrs.pname,
      targetArch ? "x86_64",
      nativeBuildInputs ? [ ],
      postPatch ? "",
      passthru ? { },
      meta ? { },
      ...
    }:
    let
      sdkRootfs =
        runCommand "proton-sdk-rootfs"
          {
            nativeBuildInputs = [
              skopeo
              umoci
            ];
          }
          ''
            skopeo --insecure-policy --tmpdir "$TMPDIR" copy docker-archive:${sdkImage} oci:image:latest
            umoci raw unpack --rootless --image image:latest "$out"
          '';
    in
    {
      inherit
        steamDisplayName
        internalToolName
        targetArch
        cargoDeps
        ;

      strictDeps = true;

      nativeBuildInputs = [ bubblewrap ] ++ nativeBuildInputs;

      outputs = [
        "out"
        "steamcompattool"
      ];

      postPatch = ''
        mkdir -p contrib
        for f in ${lib.escapeShellArgs contribSrcs}; do
          cp "$f" "contrib/$(stripHash "$f")"
        done

        # There is no .git in the store, and the timestamp makes the output differ on every build
        substituteInPlace Makefile.in \
          --replace-warn "echo \`date '+%s'\` \`GIT_DIR=\$(abspath \$(SRCDIR)/.git) git describe --tags\`" \
                         "echo $SOURCE_DATE_EPOCH ${finalAttrs.version}"
      ''
      + postPatch;

      # The build runs with the image as / and the Nix build directory mounted here
      configurePhase = ''
        runHook preConfigure

        buildRoot=/tmp/nix-build
        srcDir="$buildRoot/''${PWD#"$NIX_BUILD_TOP"/}"
        objDir="$buildRoot/build"

        mkdir -p "$NIX_BUILD_TOP"/{build,home,cargo-home}

        if [[ -n "''${cargoDeps-}" ]]; then
          cp -Lr --reflink=auto "$cargoDeps" "$NIX_BUILD_TOP/cargo-vendor"
          chmod -R u+w "$NIX_BUILD_TOP/cargo-vendor"
          substitute "$NIX_BUILD_TOP/cargo-vendor/.cargo/config.toml" "$NIX_BUILD_TOP/cargo-home/config.toml" \
            --subst-var-by vendor "$buildRoot/cargo-vendor"
        fi

        # What configure.sh would generate, minus the container engine checks
        cat > "$NIX_BUILD_TOP/build/Makefile" <<EOF
        SRCDIR := $srcDir
        BUILD_NAME := $steamDisplayName
        TARGET_ARCH := $targetArch
        INTERNAL_TOOL_NAME := $internalToolName
        CONTAINER_ENGINE := none
        include \$(SRCDIR)/Makefile.in
        EOF

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        bwrap \
          --unshare-user --unshare-pid --unshare-ipc --unshare-uts \
          --die-with-parent \
          --ro-bind ${sdkRootfs} / \
          --dev /dev \
          --proc /proc \
          --tmpfs /tmp \
          --bind "$NIX_BUILD_TOP" "$buildRoot" \
          --chdir "$objDir" \
          --clearenv \
          --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
          --setenv HOME "$buildRoot/home" \
          --setenv CARGO_HOME "$buildRoot/cargo-home" \
          --setenv CARGO_NET_OFFLINE true \
          --setenv CCACHE_DISABLE 1 \
          --setenv SOURCE_DATE_EPOCH "$SOURCE_DATE_EPOCH" \
          --setenv LANG C.UTF-8 \
          --setenv TMPDIR /tmp \
          -- \
          make -j"$NIX_BUILD_CORES" CONTAINER=1 dist

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        # Make it impossible to add to an environment. You should use the appropriate NixOS option.
        # Also leave some breadcrumbs in the file.
        echo "${finalAttrs.pname} should not be installed into environments. Please use programs.steam.extraCompatPackages instead." > $out

        cp -a "$NIX_BUILD_TOP/build/dist" "$steamcompattool"

        runHook postInstall
      '';

      # The output is built for the Steam Linux Runtime, not for Nix
      dontStrip = true;
      dontPatchELF = true;
      dontPatchShebangs = true;

      preFixup = ''
        # wineboot re-applies wine.inf when its mtime differs from .update-timestamp.
        # Every file in the Nix store has the same mtime, so that never happens and
        # upgraded prefixes miss anything new in wine.inf, such as new services.
        # Removing the timestamp when the prefix version changes restores the behaviour
        # of a normal install.
        substituteInPlace "$steamcompattool/proton" \
          --replace-fail "            self.upgrade_pfx(old_ver)" \
                         "            self.upgrade_pfx(old_ver)
                  if old_ver != CURRENT_PREFIX_VERSION and file_exists(self.prefix_dir + '.update-timestamp', follow_symlinks=False):
                      os.remove(self.prefix_dir + '.update-timestamp')"
      '';

      requiredSystemFeatures = [ "big-parallel" ];

      passthru = {
        inherit sdkImage sdkRootfs;
      }
      // passthru;

      meta = {
        platforms = [
          {
            x86_64 = "x86_64-linux";
            arm64 = "aarch64-linux";
          }
          .${targetArch}
        ];
        sourceProvenance = with lib.sourceTypes; [
          fromSource
          # wine-gecko and wine-mono are prebuilt by upstream
          binaryNativeCode
          binaryBytecode
        ];
      }
      // meta;
    };
}
