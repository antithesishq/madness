# Defines a rule in the format specified by `man tmpfiles.d` which on boot creates a symlink from the
# FHS (https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) specified location for the ld loader
# to the `madness` meta-loader, which will search the program's RPATH for a libc loader named ld-linux-x86-64.so.2.
# This allows programs linked with a NixOS R(UN)PATH but a FHS loader location to run on this computer as well as on FHS.

{ config, lib, pkgs, ... }:
let

  pre2405 = lib.strings.versionOlder (config.system.nixos.release) "24.05";

  loader = (pkgs.callPackage ./madness.nix { }).loader;
in {
  options.antithesis.madness = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        This option enables the madness meta-loader by installing a symlink from the FHS ld loader location to madness.
      '';
    };
  };

  config = lib.mkIf config.antithesis.madness.enable {
    # if 24.05 or later we can use the built in options to set our custom loader
    environment = lib.optionalAttrs (!pre2405) {
        stub-ld.enable = false;
        ldso = loader;
    };
    # older nixos we need to set the loader manually
    systemd.tmpfiles.rules = lib.optionals pre2405 [ "L+ /lib64/ld-linux-x86-64.so.2 - - - - ${loader}" ];
  };
}
