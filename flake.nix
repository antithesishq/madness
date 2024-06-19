{
  description = "TODO";

  outputs = _: {
    nixosModules.madness = import ./modules;
  };
}
