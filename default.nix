{
  config,
  lib,
  dream2nix,
  ...
}: let
  mostPopular = lib.splitString "\n" (lib.readFile ./500-most-popular-pypi-packages.txt);
  requirements = lib.filter (v: v != "psycopg2") mostPopular;

in  {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python3;
    inherit
      (nixpkgs)
      pkg-config
      postgresql
      ;
  };

  name = "500-most-popular";
  version = "1.0.0";

  mkDerivation = {
    src = ./.;
    nativeBuildInputs = [
      config.deps.pkg-config
    ];
  };

  buildPythonPackage = {
    format = "pyproject";
  };

  pip = {
    pypiSnapshotDate = null;
    flattenDependencies = true;
    requirementsList = requirements;

    #overrides = {
    #  psycopg2 = {
    #    imports = [dream2nix.modules.dream2nix.nixpkgs-overrides];
    #    nixpkgs-overrides.enable = true;
    #    mkDerivation.nativeBuildInputs = [
    #      config.deps.pkg-config
    #      config.deps.postgresql
    #    ];
    #  };
    #};
  };
}
