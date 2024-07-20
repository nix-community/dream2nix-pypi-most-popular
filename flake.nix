{
  inputs = {
    nixpkgs.follows = "dream2nix/nixpkgs";
    dream2nix.url = "github:nix-community/dream2nix";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    self,
    nixpkgs,
    dream2nix,
    systems
  }: let
    lib = nixpkgs.lib;
    eachSystem = lib.genAttrs (import systems);

    limit = 500;
    mostPopular = lib.listToAttrs
      (lib.take limit
        (map
          (line: let
            parts = lib.splitString "==" line;
          in {
            name = lib.elemAt parts 0;
            value = lib.elemAt parts 1;
          })
          (lib.splitString "\n"
            (lib.removeSuffix "\n"
              (lib.readFile ./500-most-popular-pypi-packages.txt)))));

    toSkip = [
      "dataclasses"  # in stdlib from 3.8
      "pypular"  # TODO investigate how this got into the dataset, not even on pypi
      # locking failed
      "shapely"  # libstdc++.6.so
      "ipykernel" # libstdc++.6.so
      "delta-spark"
      "jupyterlab-pygments"
      "matplotlib"
      "mysql-connector-python"
      "numpy" # did withLibCPP work before with stdenv.cc.cc.lib.lib ?
      "pandas"
      "redshift-connector"
      "scikit-image"
      "scikit-learn"
      "scipy"
      "tb-nightly"
      "xgboost"
    ];
    requirements = lib.filterAttrs (n: v: !(builtins.elem n toSkip)) mostPopular;

    overrides = let
      withCC = { config, ...}: {
        deps = { nixpkgs, ... }: {
          inherit (nixpkgs) stdenv;
        };
        pip = {
          nativeBuildInputs = [config.deps.stdenv.cc];
        };
      };

      useWheel.pip.pipFlags = lib.mkForce [];

      withLibCPP = { config, ...}: {
        # TODO FIXME
      };

      withPkgConfig = { config, ...}: {
        imports = [ withCC ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) pkg-config;
          };
          pip = {
            nativeBuildInputs = [config.deps.pkg-config];
          };
        };
      };

      withCMake = { config, ...}: {
        imports = [ withCC ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) cmake;
          };
          pip = {
            nativeBuildInputs = [config.deps.cmake];
          };
        };
      };


      withNinja = { config, ...}: {
        imports = [ withCC ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) ninja;
          };
          pip = {
            nativeBuildInputs = with config.deps; [
              ninja
            ];
          };
        };
      };

      withMaturin = { config, ...}: {
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) cargo rustc;
          };
          pip = {
            nativeBuildInputs = [config.deps.cargo config.deps.rustc];
          };
        };
      };

      withHatchling = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.hatchling];
          };
        };
      };

    in {
      aiofiles = withHatchling;

      contourpy = withNinja;
      grpcio-tools = withCC;
      grpcio = withCC;

      ipykernel = withLibCPP;
      lxml = { config, ...}: {
        imports = [ withPkgConfig ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) libxml2 libxslt;
          };
          pip = {
            nativeBuildInputs = [
              config.deps.libxml2.dev
              config.deps.libxslt.dev
            ];
          };
        };
      };

      matplotlib = withNinja;
      numpy = withNinja;

      orjson = withMaturin;
      pandas = withNinja;
      pendulum = withMaturin;
      pydantic-core = withMaturin;
      pymssql = withCC;
      pyzmq = withCMake;
      psycopg2 = { config, ...}: {
        imports = [ withPkgConfig ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) postgresql;
          };
          pip = {
            nativeBuildInputs = [
              config.deps.postgresql
            ];
          };
        };
      };
      psycopg2-binary = useWheel;
      rpds-py = withMaturin;
      safetensors = withMaturin;
      scikit-image = withNinja;
      scikit-learn = withNinja;
      scipy = { config, ...}: {
        imports = [withNinja];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) gfortran openblas;
          };
          pip = {
            nativeBuildInputs = [
              config.deps.gfortran
              config.deps.openblas
            ];
          };
        };
      };
      setuptools.pip.ignoredDependencies = lib.mkForce [ "wheel" ];
      wheel.pip.ignoredDependencies = lib.mkForce [ "setuptools" ];
      shapely = withLibCPP;
      tensorboard = useWheel;
      tensorboard-data-server = useWheel;
      tensorflow-estimator = useWheel;
      tensorflow-io-gcs-filesystem = useWheel;
      tensorflow = useWheel;
      tokenizers = withMaturin;
      torch = useWheel;
      torchvision = useWheel;
      wandb = useWheel;
      watchfiles = withMaturin;
      xgboost = withCMake;
    };

    makePackage = {name, version, system}:
      dream2nix.lib.evalModules {
        packageSets.nixpkgs = nixpkgs.legacyPackages.${system};
        modules = [
          ({
            config,
              lib,
              dream2nix,
              ...
          }: {
            inherit name version;
            imports = [
              dream2nix.modules.dream2nix.pip
            ];
            paths.lockFile = "locks/${name}.${system}.json";
            paths.projectRoot = ./.;
            paths.package = ./.;

            buildPythonPackage.pyproject = lib.mkDefault true;
            mkDerivation.nativeBuildInputs = with config.deps.python.pkgs; [ setuptools wheel ];
            pip = {
              ignoredDependencies = [ "wheel" "setuptools" ];
              requirementsList = [ "${name}==${version}" ];
              pipFlags = ["--no-binary" name];
            };
          })
          (overrides.${name} or {})
        ];
      };
  in {
    packages = eachSystem (system: lib.mapAttrs (name: version: makePackage {inherit name version system; }) requirements);
    apps = eachSystem(system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lockAll = pkgs.writeShellApplication {
        name = "lock-all";
        text = lib.concatStringsSep "\n"
          (lib.mapAttrsToList
            (name: pkg: ''
              if [ -f ${pkg.config.paths.lockFile} ]
              then
                echo "${name}: lock exists, skipping"
              else
                echo -n '${name}: locking (${lib.getExe pkg.lock}) ... ';
                error_log="locks/$(basename ${pkg.config.paths.lockFile} ".json").error.log"

                if ${lib.getExe pkg.lock} &>lock_out
                then
                  echo "success!";
                  rm "$error_log" || true
                else
                  echo "error!"
                  mv lock_out  "$error_log"
                fi
                rm lock_out || true
              fi
             '')
            self.packages.${system});
      };
    in {
      lock-all = {
        type = "app";
        program = lib.getExe lockAll;
      };
    });

    devShells = eachSystem(system: let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3.withPackages (ps: [
        ps.jinja2
        ps.python-lsp-server
        ps.python-lsp-ruff
        ps.pylsp-mypy
        ps.ipython
      ]);

    in {
      default = pkgs.mkShell {
        packages = [ python pkgs.ruff pkgs.mypy pkgs.black ];
      };
    });

  };
}
