{
  lib,
  callPackage,
  newScope,
}:

let
  mkObsPlugin = callPackage ./mkObsPlugin.nix { };
in
lib.packagesFromDirectoryRecursive {
  inherit callPackage;
  newScope = scope: newScope ({ inherit mkObsPlugin; } // scope);
  directory = ./plugins;
}
