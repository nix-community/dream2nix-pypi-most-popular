{
  config,
  lib,
  dream2nix,
  ...
}: let
  mostPopular = lib.splitString "\n" (lib.readFile ./500-most-popular-pypi-packages.txt);

  toSkip = [
    #"psycopg2"
    "pypular"
    "rpds-py"
    "pydantic" "pydantic-core"
  ];

  requirements = lib.filter (v: !(builtins.elem v toSkip)) mostPopular;

in  {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python311;
    inherit
      (nixpkgs)
      pkg-config
      postgresql
      gcc
      stdenv
      coreutils
      cmake
      ninja
      libffi
      gfortran
      openblas
      libxml2
      libxslt
      rustc
      cargo
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
    flattenDependencies = true;
    requirementsList = requirements;
    #pipFlags = [
    #  "--no-binary"
    #  (lib.concatStringsSep "," requirements)
    #];

    nativeBuildInputs = with config.deps; [
      pkg-config
      stdenv.cc
      #python.pkgs.cython_0 # build-time dependency of PyYaml
      postgresql # psycopg2
      coreutils  # Cython
      cmake  # numpy
      ninja  # numy
      libffi.dev # cryptography
      gfortran # scipy
      openblas.dev # scipy
      libxml2.dev # lxml
      libxslt.dev # lxml
      #rustc # pydantic / maturin
      #cargo # pydantic / maturin
    ] ++ lib.optionals stdenv.isDarwin [
      xcbuild # numpy
      darwin.cctools # pandas
      #libiconv-darwin # pydantic
    ];
  };
}
