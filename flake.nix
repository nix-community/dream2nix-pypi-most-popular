{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
      "dataclasses"  # in pythons stdlib since python 3.8
      "pypular" # https://tomaselli.page/blog/pypular-removed-from-pypi.html
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
        config.pip.env = {
          LD_LIBRARY_PATH = "${config.deps.stdenv.cc.cc.lib}/lib";
        };
      };

      withPkgConfig = { config, ...}: {
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) pkg-config;
          };
          pip = {
            nativeBuildInputs = [config.deps.pkg-config config.deps.python.pkgs.pkgconfig];
          };
          mkDerivation = { inherit (config.pip) nativeBuildInputs; };
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
          mkDerivation = { inherit (config.pip) nativeBuildInputs; };
        };
      };


      withMesonPy = { config, ...}: {
        imports = [ withCC ];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) ninja;
          };
          pip = {
            nativeBuildInputs = [
              config.deps.ninja
            ];
          };
          mkDerivation.nativeBuildInputs = [
            config.deps.ninja
            config.deps.python.pkgs.meson
          ];
        };
      };

      withCython = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.cython];
          };
        };
      };

      withExpandVars = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.expandvars];
          };
        };
      };

      withMaturin = { config, ...}: {
        config = let
          nativeBuildInputs = [
            config.deps.maturin
            config.deps.cargo config.deps.rustc
          ];
        in {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) cargo rustc maturin;
          };
          pip = {inherit nativeBuildInputs;};
          mkDerivation = {inherit nativeBuildInputs;};
        };
      };

      withFlitCore = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.flit-core];
          };
        };
      };

      withFlitScm = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.flit-scm];
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

      withHatchVcs = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [
              config.deps.python.pkgs.hatchling
              config.deps.python.pkgs.hatch-vcs
              config.deps.python.pkgs.hatch-fancy-pypi-readme
            ];
          };
        };
      };

      withPbr = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.pbr];
          };
        };
      };

      withPdmBackend = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.pdm-backend];
          };
        };
      };

      withPoetryCore = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.poetry-core];
          };
        };
      };

      withSetuptoolsRust = { config, ...}: {
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) cargo rustc;
          };
          mkDerivation = {
            nativeBuildInputs = [
              config.deps.python.pkgs.setuptools-rust
              config.deps.cargo config.deps.rustc
            ];
          };
        };
      };

      withSetuptoolsScm = { config, ...}: {
        config = {
          mkDerivation = {
            nativeBuildInputs = [config.deps.python.pkgs.setuptools-scm];
          };
        };
      };

      withNumpy = {config, ...}: {
        imports = [withMesonPy withPkgConfig];
        config = let
          python = config.deps.python;
          inherit (python.pkgs) numpy_2 pythran;
          numpyCrossFile = config.deps.writeText "cross-file-numpy.conf" ''
                [properties]
                numpy-include-dir = '${numpy_2}/${python.sitePackages}/numpy/_core/include'
                pythran-include-dir = '${pythran}/${python.sitePackages}/pythran'
                host-python-path = '${python.interpreter}'
                host-python-version = '${python.pythonVersion}'
            '';
        in {
          mkDerivation.propagatedBuildInputs = [numpy_2 pythran];
          pip.env.PIP_CONFIG_SETTINGS = "setup-args=--cross-file=${numpyCrossFile}";
        };
      };


    in {
      aiofiles = withHatchling;
      aioitertools = withFlitCore;
      alembic = {config, ...}:
        let
          version = "69.2.0";
          setuptools_69_2 = config.deps.python.pkgs.setuptools.overridePythonAttrs {
            inherit version;
            patches = [];
            src = config.deps.fetchPypi {
              pname = "setuptools";
              inherit version;
              hash = "sha256-D/QYP49CzY+jrOoWxFIFUhpO8o9zxjkdiiXpKJMTTy4=";
            };
          };
        in {
          deps = {nixpkgs, ...}: {
            inherit (nixpkgs) fetchPypi;
          };
          mkDerivation.nativeBuildInputs = [setuptools_69_2];
        };
      altair = withHatchling;
      annotated-types = withHatchling;
      anyio = withSetuptoolsScm;
      apache-airflow = withHatchling;
      apache-airflow-providers-common-sql = withFlitCore;
      argcomplete = withSetuptoolsScm;
      argon2-cffi = withHatchVcs;
      argon2-cffi-bindings = withSetuptoolsScm;
      arrow = withFlitCore;
      asttokens = withSetuptoolsScm;
      attrs = withHatchVcs;
      awswrangler = withPoetryCore;
      backcall = withFlitCore;
      backoff = withPoetryCore;
      # backports-zoneinfo  # compile error?
      bcrypt = withSetuptoolsRust;
      beautifulsoup4 = withHatchling;
      black = withHatchVcs;
      blinker = withFlitCore;
      bs4 = withHatchling;
      build = withFlitCore;
      cachecontrol = withFlitCore;
      cattrs = withHatchVcs;
      cffi = {config, ...}: {
        deps = {nixpkgs, ...}: {
          inherit (nixpkgs) libffi;
        };
        mkDerivation.buildInputs = [
          config.deps.libffi
        ];
      };
      cleo = withPoetryCore;
      cloudpickle = withFlitCore;
      colorama = withHatchling;
      comm = withHatchling;
      confluent-kafka = {config,...}: {
        deps = {nixpkgs, ...}: {
          inherit (nixpkgs) rdkafka;
        };
        mkDerivation.buildInputs = [
          config.deps.rdkafka
        ];
      };

      contourpy = withMesonPy;
      crashtest = withPoetryCore;
      cryptography = withSetuptoolsRust;
      databricks-sql-connector = withPoetryCore;
      dataclasses-json = {config, ...}: {
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.poetry-dynamic-versioning ];
      };
      datadog = withHatchling;
      delta-spark = useWheel;
      db-contrib-tool = withPoetryCore;
      dnspython = withHatchling;
      docker = withHatchVcs;
      docstring-parser = withPoetryCore;
      docutils = withFlitCore;
      dulwich = withSetuptoolsRust;
      entrypoints = withFlitCore;
      evergreen-py = withPoetryCore;
      exceptiongroup = withFlitScm;
      execnet = withHatchVcs;
      executing = withSetuptoolsScm;
      fastapi = withPdmBackend;
      filelock = withHatchVcs;
      flask = withFlitCore;
      frozenlist = withExpandVars;
      fsspec = withHatchVcs;
      graphql-core = withPoetryCore;
      grpcio-tools = withCC;
      grpcio = withCC;
      h5py.imports = [ withPkgConfig withCython ];
      httpcore = withHatchVcs;
      httpx = withHatchVcs;
      hvac = withPoetryCore;
      idna = withFlitCore;
      importlib-metadata = withSetuptoolsScm;
      importlib-resources = withSetuptoolsScm;
      iniconfig = withHatchVcs;
      installer = withFlitCore;
      ipykernel = withLibCPP;
      isort = withPoetryCore;
      itsdangerous = withFlitCore;
      jaraco-classes = withSetuptoolsScm;
      jaraco-functools = withSetuptoolsScm;
      jeepney = withFlitCore;
      jinja2 = withFlitCore;
      jsonschema = withHatchVcs;
      jsonschema-specifications = withHatchVcs;
      jupyter-client = withHatchling;
      jupyter-core = withHatchling;
      jupyter-events = withHatchling;
      jupyter-server = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.hatch-jupyter-builder ];
      };
      jupyter-server-terminals = withHatchling;
      jupyterlab = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.hatch-jupyter-builder ];
      };
      jupyterlab-server = withHatchling;
      jupyterlab-pygments = useWheel;
      #jupyterlab-widgets = ('jupyter_packaging',)
      keyring = withSetuptoolsScm;
      #kiwisolver = ('cppy',)
      langchain-core = withPoetryCore;
      lazy-object-proxy = withSetuptoolsScm;
      libcst = {
        imports = [withSetuptoolsRust withSetuptoolsScm];
      };
      lockfile = withPbr;

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

      lz4 = { config, ...}: {
        imports = [withPkgConfig withSetuptoolsScm];
      };

      markdown-it-py = withFlitCore;
      marshmallow = withFlitCore;
      matplotlib = {config, ...}: {
        imports = [withNumpy];
        config = {
          deps = {nixpkgs, ...}: {
            inherit (nixpkgs) openblas;
          };
          mkDerivation = {
            nativeBuildInputs = [
              config.deps.openblas
            ];
          };
          pip.nativeBuildInputs = [
            config.deps.openblas
          ];
        };
      };
      mdurl = withFlitCore;
      more-itertools = withFlitCore;
      msgpack = withCython;
      mypy = {config, ...}: {
        mkDerivation.propagatedBuildInputs = with config.deps.python.pkgs; [types-setuptools types-psutil];
      };
      mysql-connector-python = useWheel;
      nbclient = withHatchling;
      nbconvert = withHatchling;
      nbformat = {config, ...}: {
        imports = [withHatchling];
        mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.hatch-nodejs-version ];
      };
      nest-asyncio = withSetuptoolsScm;
      nodeenv = withSetuptoolsScm;
      notebook = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.hatch-jupyter-builder ];
      };
      notebook-shim = withHatchling;
      numpy = {config, ...}: {
        imports = [withMesonPy];
        config = {
          deps = {nixpkgs, ...}: {
            inherit (nixpkgs) coreutils;
          };
          pip.nativeBuildInputs = [ config.deps.coreutils ];
        };
      };
      openai = withHatchVcs;
      #opencv-python = ('skbuild',)
      opentelemetry-api = withHatchling;
      opentelemetry-exporter-otlp-proto-common = withHatchling;
      opentelemetry-exporter-otlp-proto-grpc = withHatchling;
      opentelemetry-exporter-otlp-proto-http = withHatchling;
      opentelemetry-proto = withHatchling;
      opentelemetry-sdk = withHatchling;
      opentelemetry-semantic-conventions = withHatchling;
      orbax-checkpoint = withFlitCore;
      ordered-set = withFlitCore;
      orjson = withMaturin;
      packaging = withFlitCore;
      pandas.imports = [withNumpy];
      pathspec = withFlitCore;
      pendulum = withMaturin;
      pg8000 = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.versioningit ];
      };
      pkgutil-resolve-name = withFlitCore;
      platformdirs = withHatchVcs;
      plotly = {config, ...}: {
        mkDerivation.propagatedBuildInputs = [ config.deps.python.pkgs.jupyterlab ];
      };
      pluggy = withSetuptoolsScm;
      portalocker = withSetuptoolsScm;
      prettytable = withHatchVcs;
      progressbar2 = withSetuptoolsScm;
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
          mkDerivation = { inherit (config.pip) nativeBuildInputs; };
        };
      };
      psycopg2-binary = useWheel;
      ptyprocess = withFlitCore;
      pure-eval = withSetuptoolsScm;
      py = withSetuptoolsScm;
      pyarrow = withCython;
      pydantic = withHatchVcs;
      pydantic-core = withMaturin;
      pydeequ = withPoetryCore;
      pygithub = withSetuptoolsScm;
      pygments = withHatchling;
      pymongo = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.hatch-requirements-txt ];
      };
      pymssql.imports = [ withCC withCython ];
      pyparsing = withFlitCore;
      pyproject-hooks = withFlitCore;
      pytest = withSetuptoolsScm;
      pytest-mock = withSetuptoolsScm;
      pytest-runner = withSetuptoolsScm;
      pytest-xdist = withSetuptoolsScm;
      python-dateutil = withSetuptoolsScm;
      python-multipart = withHatchling;
      pytzdata = withPoetryCore;
      pyyaml = withCython;
      pyzmq = withCMake; #('scikit_build_core',)
      #rapidfuzz = ('skbuild',)
      redshift-connector = useWheel;
      referencing = withHatchVcs;
      requests-file = withSetuptoolsScm;
      retry = withPbr;
      rfc3986-validator = {config, ...}: {
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.pytest-runner ];
      };
      rich = withPoetryCore;
      rpds-py = withMaturin;
      rsa = withPoetryCore;
      safetensors = withMaturin;
      scikit-image = {config,...}: {
        imports = [withNumpy ];
        config.pip.env = {
          LD_LIBRARY_PATH = "${config.deps.stdenv.cc.cc.lib}/lib";
        };
      };
      scikit-learn.imports = [withNumpy];
      scipy = { config, ...}: {
        imports = [withNumpy];
        config = {
          deps = { nixpkgs, ... }: {
            inherit (nixpkgs) gfortran openblas;
          };
          pip.nativeBuildInputs = [
            config.deps.gfortran
            config.deps.openblas
          ];
        };
      };
      scramp = {config, ...}: {
        imports = [withHatchling];
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.versioningit ];
      };
      seaborn = withFlitCore;
      semver = withSetuptoolsScm;
      setuptools.pip.ignoredDependencies = lib.mkForce [ "wheel" ];
      shapely = withLibCPP;
      slack-sdk = {config, ...}: {
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.pytest-runner ];
      };
      sniffio = withSetuptoolsScm;
      snowflake-connector-python = withCython;
      snowflake-sqlalchemy = withHatchling;
      soupsieve = withHatchling;
      sphinx = withFlitCore;
      sqlalchemy = withCython;
      sqlparse = withHatchling;
      stack-data = withSetuptoolsScm;
      starlette = withHatchling;
      statsmodels.imports = [withSetuptoolsScm withCython];
      structlog = withHatchVcs;
      tabulate = withSetuptoolsScm;
      tb-nightly = useWheel;
      tenacity = withSetuptoolsScm;
      termcolor = withHatchVcs;
      terminado = withHatchling;
      tensorboard = useWheel;
      tensorboard-data-server = useWheel;
      tensorflow-estimator = useWheel;
      tensorflow-io-gcs-filesystem = useWheel;
      tensorflow = useWheel;
      threadpoolctl = withFlitCore;
      tinycss2 = withFlitCore;
      tokenizers = withMaturin;
      torch = useWheel;
      torchvision = useWheel;
      tomli = withFlitCore;
      tomlkit = withPoetryCore;
      tox = withHatchVcs;
      tqdm = withSetuptoolsScm;
      traitlets = withHatchling;
      trove-classifiers = {config, ...}: {
        config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.calver ];
      };
      typeguard = withSetuptoolsScm;
      typer = withPdmBackend;
      typing-extensions = withFlitCore;
      ujson = withSetuptoolsScm;
      uri-template = withSetuptoolsScm;
      urllib3 = withHatchling;
      uvicorn = withHatchling;
      uvloop = withCython;
      virtualenv = withHatchVcs;
      wandb = useWheel;
      watchfiles = withMaturin;
      werkzeug = withFlitCore;
      wheel = {
        imports = [ withFlitCore ];
        config.pip.ignoredDependencies = lib.mkForce [ "setuptools" ];
      };
      #widgetsnbextension = ('jupyter_packaging',)
      xgboost = {config,...}: {
        imports = [withCMake];
        config = {
          deps = { nixpkgs, ...}: {
            inherit (nixpkgs) gnumake;
          };
          pip.nativeBuildInputs = [ config.deps.gnumake ];
          mkDerivation.nativeBuildInputs = [ config.deps.gnumake ];
        };
      };
      yarl = withExpandVars;
      zipp = withSetuptoolsScm;
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
