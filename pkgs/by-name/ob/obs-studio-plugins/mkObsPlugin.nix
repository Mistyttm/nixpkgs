{
  lib,
  nix-update-script,
  obs-studio,
  stdenv,
}:

lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;

  excludeDrvArgNames = [
    "obsWrapperArguments"
    "pluginDataDir"
    "pluginDir"
    "platforms"
  ];

  extendDrvArgs =
    finalAttrs:
    {
      buildInputs ? [ ],
      obsWrapperArguments ? [ ],
      pluginDataDir ? "share/obs/obs-plugins",
      pluginDir ? "lib/obs-plugins",
      platforms ? obs-studio.meta.platforms,
      postInstall ? "",
      passthru ? { },
      meta ? { },
      ...
    }:
    {
      __structuredAttrs = true;
      strictDeps = true;

      buildInputs = [ obs-studio ] ++ buildInputs;

      postInstall = postInstall + ''
        if [[ -d "$out/obs-plugins" ]]; then
          mkdir -p "$out/${pluginDir}"
          mv "$out"/obs-plugins/* "$out/${pluginDir}"/
          rmdir "$out/obs-plugins"
        fi

        if [[ -d "$out/data" ]]; then
          mkdir -p "$out/${pluginDataDir}"
          mv "$out"/data/* "$out/${pluginDataDir}"/
          rmdir "$out/data"
        fi
      '';

      passthru = passthru // {
        inherit obsWrapperArguments;
        updateScript = passthru.updateScript or (nix-update-script { });
      };

      meta = {
        inherit platforms;
      }
      // meta;
    };
}
