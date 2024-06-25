{
  description = "Madness is a meta-loader for ELF binaries. It enables you to run programs built for non-Nix systems on NixOS.";

  outputs = _: {
    nixosModules.madness = import ./modules;
  };
}
