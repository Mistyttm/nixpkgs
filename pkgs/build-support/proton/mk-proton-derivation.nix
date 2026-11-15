# Builds Proton from source against nixpkgs, without the Steam Linux Runtime.
#
# Upstream's Makefile has an outer mode that starts the Proton SDK image with
# docker/podman and an inner mode (CONTAINER=1) that does the real build. We run the
# inner mode directly, with the Nix sandbox standing in for the container.
#
# The inner build expects a Debian multiarch system. It calls per-arch tools such as
# `i686-linux-gnu-gcc` and selects 32-bit or 64-bit libraries only through
# PKG_CONFIG_LIBDIR=/usr/lib/<multiarch>/pkgconfig. The wrappers below map those onto
# nixpkgs and pkgsi686Linux.
#
# The binaries link against nixpkgs, so `require_tool_appid` is removed from
# toolmanifest.vdf and Steam runs the tool directly in its FHS environment instead
# of inside pressure-vessel.
{
  lib,
  stdenv,
  pkgs,
  pkgsi686Linux,
  pkgsCross,
  runCommand,
  symlinkJoin,
  bash,
  pkg-config-unwrapped,
  wine,
  python3,
  perl,
  fontforge,
  autoconf,
  automake,
  libtool,
  autoconf-archive,
  bison,
  flex,
  gettext,
  gperf,
  meson,
  ninja,
  cmake,
  nasm,
  yasm,
  unzip,
  rsync,
  gitMinimal,
  which,
  glib,
  wayland-scanner,
}:

let
  # No threading library apart from the libc, which on MinGW means the `win32`
  # model. This matches Debian's default mingw-w64 toolchain in the SDK image.
  useWin32ThreadModel = pkgs: pkgs.appendOverlays [ (final: prev: { threads = null; }) ];
  mingwGccs = map (p: (useWin32ThreadModel p).buildPackages.gcc) [
    pkgsCross.mingw32
    pkgsCross.mingwW64
  ];

  # x86_64-hosted rustc with the standard library for both i686 and x86_64
  rustToolchain = pkgsCross.gnu32.buildPackages;

  # Unix-side libraries the SDK image provides, for both arches
  defaultUnixDeps =
    p: with p; [
      alsa-lib
      blas
      dbus
      fontconfig
      freetype
      glib
      gnutls
      krb5
      lapack
      libdrm
      libgbm
      libglvnd
      libpcap
      libpsl
      libpulseaudio
      libunwind
      libusb1
      libx11
      libxcomposite
      libxcursor
      libxext
      libxfixes
      libxi
      libxinerama
      libxkbcommon
      libxml2
      libxpresent
      libxrandr
      libxrender
      libxxf86vm
      nghttp2
      ocl-icd
      opencl-headers
      SDL2
      sqlite
      systemdLibs
      v4l-utils
      vulkan-loader
      wayland
      xorgproto
      zlib
    ];

  mkArch =
    {
      p,
      triplet,
      multiarch,
      unixDeps,
    }:
    let
      deps = unixDeps p;
      salt = lib.replaceStrings [ "-" "." ] [ "_" "_" ] p.stdenv.targetPlatform.config;
      devEnv = symlinkJoin {
        name = "proton-${multiarch}-dev";
        paths = map lib.getDev deps ++ map lib.getLib deps;
      };
      libEnv = symlinkJoin {
        name = "proton-${multiarch}-lib";
        paths = map lib.getLib deps;
      };
    in
    {
      inherit
        p
        triplet
        multiarch
        salt
        devEnv
        libEnv
        ;
      pkgConfigLibdir = "${devEnv}/lib/pkgconfig:${devEnv}/share/pkgconfig";
    };

  # Debian-style triplet names for the unix-side compilers and binutils. The
  # libraries are injected through the cc-wrapper's per-target variables, and the
  # rpath keeps them loadable at runtime since wine dlopen()s most of them.
  mkToolchain =
    arches:
    runCommand "proton-toolchain-wrappers" { } (
      ''
        mkdir -p $out/bin
      ''
      + lib.concatMapStrings (a: ''
        for tool in gcc g++ cc c++ cpp; do
          cat > $out/bin/${a.triplet}-$tool <<'EOF'
        #!${bash}/bin/bash
        export NIX_CFLAGS_COMPILE_${a.salt}="''${NIX_CFLAGS_COMPILE_${a.salt}-} -isystem ${a.devEnv}/include"
        export NIX_LDFLAGS_${a.salt}="''${NIX_LDFLAGS_${a.salt}-} -L${a.libEnv}/lib -rpath ${a.libEnv}/lib"
        EOF
          real=$tool
          [[ $tool == cc ]] && real=gcc
          [[ $tool == c++ ]] && real=g++
          echo "exec ${a.p.stdenv.cc}/bin/$real \"\$@\"" >> $out/bin/${a.triplet}-$tool
          chmod +x $out/bin/${a.triplet}-$tool
        done
        for tool in ar ranlib ld nm strip objcopy objdump readelf; do
          ln -s ${a.p.stdenv.cc.bintools}/bin/$tool $out/bin/${a.triplet}-$tool
        done
      '') arches
      + ''
        # The Makefile always calls the host arch's pkg-config and selects the target
        # through PKG_CONFIG_LIBDIR. Windows targets get no system libraries.
        cat > $out/bin/pkg-config-multiarch <<'EOF'
        #!${bash}/bin/bash
        case "''${PKG_CONFIG_LIBDIR-}" in
          *mingw32*) export PKG_CONFIG_LIBDIR=/var/empty ;;
          ${lib.concatMapStrings (a: ''
            *${a.multiarch}*) export PKG_CONFIG_LIBDIR=${a.pkgConfigLibdir} ;;
          '') arches}
          *) export PKG_CONFIG_LIBDIR=${(lib.head arches).pkgConfigLibdir} ;;
        esac
        exec ${pkg-config-unwrapped}/bin/pkg-config "$@"
        EOF
        chmod +x $out/bin/pkg-config-multiarch
        ${lib.concatMapStrings (a: ''
          ln -s pkg-config-multiarch $out/bin/${a.triplet}-pkg-config
        '') arches}

        # Debian's mingw-w64-tools provides widl; nixpkgs only has wine's
        for t in i686-w64-mingw32 x86_64-w64-mingw32; do
          ln -s ${wine}/bin/widl $out/bin/$t-widl
        done
      ''
    );
in

lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;

  excludeDrvArgNames = [
    "contribSrcs"
    "unixDeps"
  ];

  extendDrvArgs =
    finalAttrs:
    {
      # Files the Makefile would otherwise download into contrib/ (wine-gecko, wine-mono, ...)
      contribSrcs ? [ ],
      # Vendored crates for gst-plugins-rs, from `rustPlatform.fetchCargoVendor`
      cargoDeps ? null,
      # Function from a package set to the unix-side libraries, used for both arches
      unixDeps ? defaultUnixDeps,
      steamDisplayName ? finalAttrs.pname,
      internalToolName ? finalAttrs.pname,
      nativeBuildInputs ? [ ],
      postPatch ? "",
      passthru ? { },
      meta ? { },
      ...
    }:
    let
      arches = [
        (mkArch {
          p = pkgs;
          triplet = "x86_64-linux-gnu";
          multiarch = "x86_64-linux-gnu";
          inherit unixDeps;
        })
        (mkArch {
          p = pkgsi686Linux;
          triplet = "i686-linux-gnu";
          multiarch = "i386-linux-gnu";
          inherit unixDeps;
        })
      ];
      toolchain = mkToolchain arches;
    in
    {
      inherit
        steamDisplayName
        internalToolName
        cargoDeps
        ;

      strictDeps = true;

      nativeBuildInputs = [
        toolchain
        (python3.withPackages (
          ps: with ps; [
            afdko
            fonttools
            mako
            pefile
          ]
        ))
        (perl.withPackages (ps: [ ps.JSON ]))
        fontforge
        autoconf
        automake
        libtool
        autoconf-archive
        bison
        flex
        gettext
        gperf
        meson
        ninja
        cmake
        nasm
        yasm
        unzip
        rsync
        gitMinimal
        which
        glib
        wayland-scanner
        rustToolchain.rustc
        rustToolchain.cargo
      ]
      ++ mingwGccs
      ++ nativeBuildInputs;

      # Upstream builds without hardening, and the mingw side needs libssp for some of it
      hardeningDisable = [ "all" ];

      # The meson/cmake/autoconf calls come from the Makefile, not from setup hooks
      dontUseMesonConfigure = true;
      dontUseCmakeConfigure = true;
      dontUseNinjaBuild = true;
      dontUseNinjaInstall = true;
      dontUseNinjaCheck = true;

      postPatch = ''
        mkdir -p contrib
        for f in ${lib.escapeShellArgs contribSrcs}; do
          cp "$f" "contrib/$(stripHash "$f")"
        done

        # There is no .git in the store, and the timestamp makes the output differ on every build
        substituteInPlace Makefile.in \
          --replace-warn "echo \`date '+%s'\` \`GIT_DIR=\$(abspath \$(SRCDIR)/.git) git describe --tags\`" \
                         "echo $SOURCE_DATE_EPOCH ${finalAttrs.version}"

        patchShebangs --build .
      ''
      + postPatch;

      configurePhase = ''
        runHook preConfigure

        srcDir="$PWD"
        objDir="$NIX_BUILD_TOP/build"
        mkdir -p "$objDir" "$NIX_BUILD_TOP/cargo-home"

        export HOME="$NIX_BUILD_TOP/home"
        export CARGO_HOME="$NIX_BUILD_TOP/cargo-home"
        export CARGO_NET_OFFLINE=true
        export CCACHE_DISABLE=1

        if [[ -n "''${cargoDeps-}" ]]; then
          cp -Lr --reflink=auto "$cargoDeps" "$NIX_BUILD_TOP/cargo-vendor"
          chmod -R u+w "$NIX_BUILD_TOP/cargo-vendor"
          substitute "$NIX_BUILD_TOP/cargo-vendor/.cargo/config.toml" "$CARGO_HOME/config.toml" \
            --subst-var-by vendor "$NIX_BUILD_TOP/cargo-vendor"
        fi

        # What configure.sh would generate, minus the container engine checks
        cat > "$objDir/Makefile" <<EOF
        SRCDIR := $srcDir
        BUILD_NAME := $steamDisplayName
        TARGET_ARCH := x86_64
        INTERNAL_TOOL_NAME := $internalToolName
        CONTAINER_ENGINE := none
        include \$(SRCDIR)/Makefile.in
        EOF

        cd "$objDir"

        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild

        make -j"$NIX_BUILD_CORES" CONTAINER=1 SHELL=${bash}/bin/bash dist

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        # Make it impossible to add to an environment. You should use the appropriate NixOS option.
        # Also leave some breadcrumbs in the file.
        echo "${finalAttrs.pname} should not be installed into environments. Please use programs.steam.extraCompatPackages instead." > $out

        cp -a dist "$steamcompattool"

        # Run directly in Steam's FHS environment instead of the Steam Linux Runtime
        sed -i '/"require_tool_appid"/d' "$steamcompattool/toolmanifest.vdf"

        runHook postInstall
      '';

      outputs = [
        "out"
        "steamcompattool"
      ];

      # The Makefile already strips, and the PE files must not be touched.
      # patchelf --shrink-rpath would drop the libraries wine dlopen()s.
      dontStrip = true;
      dontPatchELF = true;

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
        inherit toolchain;
      }
      // passthru;

      meta = {
        platforms = [ "x86_64-linux" ];
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
