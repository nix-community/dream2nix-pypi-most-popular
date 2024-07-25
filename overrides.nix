{lib, ...}: let
  withCC = {config, ...}: {
    deps = {nixpkgs, ...}: {
      inherit (nixpkgs) stdenv;
    };
    pip = {
      nativeBuildInputs = [config.deps.stdenv.cc];
    };
  };

  useWheel = {
    pip.pipFlags = lib.mkForce [];
    buildPythonPackage = {
      pyproject = lib.mkForce null;
      format = lib.mkForce "wheel";
    };
  };

  withLibCPP = {config, ...}: {
    config.pip.env = {
      LD_LIBRARY_PATH = "${config.deps.stdenv.cc.cc.lib}/lib";
    };
  };

  withPkgConfig = {config, ...}: {
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) pkg-config;
      };
      pip = {
        nativeBuildInputs = [config.deps.pkg-config config.deps.python.pkgs.pkgconfig];
      };
      mkDerivation = {inherit (config.pip) nativeBuildInputs;};
    };
  };

  withCMake = {config, ...}: {
    imports = [withCC];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) cmake;
      };
      pip = {
        nativeBuildInputs = [config.deps.cmake];
      };
      mkDerivation = {inherit (config.pip) nativeBuildInputs;};
    };
  };

  withMesonPy = {config, ...}: {
    imports = [withCC];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) ninja;
      };
      pip = {
        nativeBuildInputs = [
          config.deps.ninja
        ];
      };
      mkDerivation.nativeBuildInputs = [
        config.deps.ninja
        config.deps.python.pkgs.meson-python
      ];
    };
  };

  withCython = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.cython];
      };
    };
  };

  withCython0 = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.cython_0];
      };
    };
  };


  withExpandVars = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.expandvars];
      };
    };
  };

  withMaturin = {config, ...}: {
    config = let
      nativeBuildInputs = [
        config.deps.maturin
        config.deps.cargo
        config.deps.rustc
      ] ++ lib.optionals config.deps.stdenv.isDarwin [
        config.deps.iconv
      ];
    in {
      deps = {
        nixpkgs,
          local,
          ...
      }: ({
        inherit (nixpkgs) cargo rustc;
        inherit (local) maturin;
      } // lib.optionalAttrs nixpkgs.stdenv.isDarwin {
        inherit (nixpkgs) iconv;
      });
      pip = {inherit nativeBuildInputs;};
      mkDerivation = {inherit nativeBuildInputs;};
    };
  };

  withFlitCore = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.flit-core];
      };
    };
  };

  withFlitScm = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.flit-scm];
      };
    };
  };

  withHatchling = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.hatchling];
      };
    };
  };

  withHatchVcs = {config, ...}: {
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

  withPbr = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.pbr];
      };
    };
  };

  withPdmBackend = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.pdm-backend];
      };
    };
  };

  withPoetryCore = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.poetry-core];
      };
    };
  };

  withSetuptoolsRust = {config, ...}: {
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) cargo rustc;
      };
      pip.nativeBuildInputs = [
        config.deps.python.pkgs.setuptools-rust
        config.deps.cargo
        config.deps.rustc
      ];
      mkDerivation = {
        nativeBuildInputs = [
          config.deps.python.pkgs.setuptools-rust
          config.deps.cargo
          config.deps.rustc
        ];
      };
    };
  };

  withDistutils = {config, ...}: {
    config = {
      # https://nixpk.gs/pr-tracker.html?pr=328379
      #mkDerivation = lib.mkIf (config.deps.python.pythonAtLeast "3.12") {
      #  nativeBuildInputs = [config.deps.python.pkgs.distutils];
      #};
    };
  };

  withSetuptoolsScm = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.setuptools-scm];
      };
    };
  };

  withSKBuild = {config, ...}: {
    config = {
      mkDerivation = {
        nativeBuildInputs = [config.deps.python.pkgs.scikit-build];
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

  withCoreutils = {config, ...}: {
    deps = {nixpkgs, ...}: {
      inherit (nixpkgs) coreutils;
    };
    mkDerivation.nativeBuildInputs = [config.deps.coreutils];
    pip.nativeBuildInputs = [config.deps.coreutils];
  };

  withSetuptools69 = {config, ...}: let
    setuptools_69_2 = let
      version = "69.2.0";
    in config.deps.python.pkgs.setuptools.overridePythonAttrs {
      inherit version;
      patches = [];
      src = config.deps.fetchPypi {
        pname = "setuptools";
        inherit version;
        hash = "sha256-D/QYP49CzY+jrOoWxFIFUhpO8o9zxjkdiiXpKJMTTy4=";
      };
    };
  in {
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) fetchPypi;
      };
      mkDerivation.nativeBuildInputs = [setuptools_69_2];
    };
  };

in {
  aiofiles = withHatchling;
  aioitertools = withFlitCore;
  alembic = withSetuptools69;
  altair = withHatchling;
  annotated-types = withHatchling;
  anyio = withSetuptoolsScm;
  apache-airflow = {
    imports = [withHatchling];
    config.buildPythonPackage.pythonRelaxDeps = true;
  };
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
  confluent-kafka = {config, ...}: {
    deps = {nixpkgs, ...}: {
      inherit (nixpkgs) rdkafka;
    };
    mkDerivation.buildInputs = [
      config.deps.rdkafka
    ];
  };

  contourpy = {config,...}: {
    imports = [withMesonPy];
    config.mkDerivation.nativeBuildInputs = [
      config.deps.python.pkgs.pybind11
    ];
  };
  crashtest = withPoetryCore;
  cryptography.imports = [withMaturin];
  databricks-sql-connector.imports = [withPoetryCore withDistutils];
  dataclasses-json = {config, ...}: {
    imports = [withPoetryCore];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.poetry-dynamic-versioning];
  };
  datadog = withHatchling;
  delta-spark = useWheel;
  db-contrib-tool = {config, ...}: {
    imports = [withPoetryCore];
    config.buildPythonPackage.pythonRelaxDeps = ["packaging"];
  };
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
  frozenlist.imports = [withExpandVars withCython];
  fsspec = withHatchVcs;
  graphql-core.imports = [withPoetryCore withSetuptools69];
  gremlinpython = {config, ...}: {
    config.buildPythonPackage.pythonRelaxDeps = ["importlib-metadata" "pytest-runner"];
  };
  grpcio-tools = withCC;
  grpcio = withCC;
  h5py = {config, ...}: {
    imports = [withPkgConfig withCython];
    config = {
      deps = {nixpkgs, ...}: {inherit (nixpkgs) hdf5;};
      mkDerivation.buildInputs = [config.deps.hdf5];
    };
  };
  httpcore = withHatchVcs;
  httpx = withHatchVcs;
  hvac = withPoetryCore;
  idna = withFlitCore;
  importlib-metadata = withSetuptoolsScm;
  importlib-resources = withSetuptoolsScm;
  iniconfig = withHatchVcs;
  installer = withFlitCore;
  ipykernel.imports = [withHatchling withLibCPP];
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
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.hatch-jupyter-builder];
  };
  jupyter-server-terminals = withHatchling;
  jupyterlab = {config, ...}: {
    imports = [withHatchling];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.hatch-jupyter-builder];
  };
  jupyterlab-server = withHatchling;
  jupyterlab-pygments = useWheel;

  jupyterlab-widgets = {config, ...}: {
    config = {
      mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.jupyter-packaging];
      mkDerivation.buildInputs = [config.deps.python.pkgs.jupyterlab];
    };
  };

  keyring = withSetuptoolsScm;
  kiwisolver = {config, ...}: {
    imports = [ withSetuptoolsScm ];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.cppy];
  };
  langchain-core = withPoetryCore;
  lazy-object-proxy = withSetuptoolsScm;
  libcst = {
    imports = [withSetuptoolsRust withSetuptoolsScm];
  };
  llvmlite = {config, ...}: {
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) libllvm;
      };
      mkDerivation.nativeBuildInputs = [config.deps.libllvm.dev];
    };
  };

  lockfile = withPbr;

  lxml = {config, ...}: {
    imports = [withPkgConfig withCython];
    config = {
      deps = {nixpkgs, ...}: {
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

  lz4 = {config, ...}: {
    imports = [withPkgConfig withSetuptoolsScm];
  };

  makefun = withSetuptoolsScm;
  markdown-it-py = withFlitCore;
  marshmallow = withFlitCore;
  matplotlib = {config, ...}: {
    imports = [withNumpy withCoreutils withSetuptoolsScm];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) openblas;
      };
      mkDerivation.nativeBuildInputs = [
        config.deps.openblas
        config.deps.python.pkgs.pybind11
      ];
      pip.nativeBuildInputs = [config.deps.openblas];
    };
  };
  mdurl = withFlitCore;
  more-itertools = withFlitCore;
  msgpack = withCython;
  mypy = {config, ...}: {
    config.mkDerivation.propagatedBuildInputs = with config.deps.python.pkgs; [types-setuptools types-psutil];
  };
  mysql-connector-python = useWheel;
  nbclient = withHatchling;
  nbconvert = withHatchling;
  nbformat = {config, ...}: {
    imports = [withHatchling];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.hatch-nodejs-version];
  };
  nest-asyncio = withSetuptoolsScm;
  nodeenv = withSetuptoolsScm;
  notebook = {config, ...}: {
    imports = [withHatchling];
    config.mkDerivation = {
      nativeBuildInputs = [config.deps.python.pkgs.hatch-jupyter-builder];
      buildInputs = [config.deps.python.pkgs.jupyter];
    };
  };
  notebook-shim = withHatchling;
  numpy = {config, ...}: {
    imports = [withMesonPy withCython];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) coreutils;
      };
      pip.nativeBuildInputs = [config.deps.coreutils];
    };
  };
  openai = withHatchVcs;
  opencv-python.imports = [withSKBuild withDistutils];
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
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.versioningit];
  };
  pkgutil-resolve-name = {config, ...}: {
    imports = [ withFlitCore ];
    config.buildPythonPackage.pythonRelaxDeps = [ "flit-core" ];
  };

  pillow = {config, ...}: {
    imports = [ withPkgConfig ];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) zlib libjpeg;
      };
      mkDerivation = {
        buildInputs = [
          config.deps.zlib.dev
          config.deps.libjpeg.dev
        ];
      };
    };
  };

  platformdirs = withHatchVcs;
  plotly = {config, ...}: {
    config.mkDerivation.propagatedBuildInputs = [config.deps.python.pkgs.jupyterlab];
    config.buildPythonPackage.pythonRelaxDeps = [ "jupyterlab" ];
  };
  pluggy = withSetuptoolsScm;
  portalocker = withSetuptoolsScm;
  prettytable = withHatchVcs;
  progressbar2 = withSetuptoolsScm;
  psutil = {config, ...}: {
    config = {
      deps = { nixpkgs,... }: lib.optionalAttrs nixpkgs.stdenv.isDarwin {
        inherit (nixpkgs.darwin.apple_sdk.frameworks) IOKit;
      };
      mkDerivation.nativeBuildInputs = lib.optionals config.deps.stdenv.isDarwin [ config.deps.IOKit ];
    };
  };
  psycopg2 = {config, ...}: {
    imports = [withPkgConfig];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) postgresql openssl;
      };
      pip = {
        nativeBuildInputs = [
          config.deps.postgresql
          config.deps.openssl.dev
        ];
      };
      mkDerivation = {inherit (config.pip) nativeBuildInputs;};
    };
  };
  psycopg2-binary = useWheel;
  ptyprocess = withFlitCore;
  pure-eval = withSetuptoolsScm;
  py = withSetuptoolsScm;
  pyarrow.imports = [withSetuptoolsScm withCython withCMake withCoreutils];
  pydantic = withHatchVcs;
  pydantic-core = withMaturin;
  pydeequ = withPoetryCore;
  pygithub = withSetuptoolsScm;
  pygments = withHatchling;
  pymongo = {config, ...}: {
    imports = [withHatchling];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.hatch-requirements-txt];
  };
  pymssql = {config, ...}: {
    imports = [withCC withCython withSetuptoolsScm];
    config.mkDerivation.nativeBuildInputs = [ config.deps.python.pkgs.tomli ];
  };
  pyparsing = withFlitCore;
  pyodbc = {config, ...}: {
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) unixODBC;
      };
      mkDerivation = {
        buildInputs = [
          config.deps.unixODBC
        ];
      };
    };
  };

  pyproject-hooks = withFlitCore;
  pytest = withSetuptoolsScm;
  pytest-mock = withSetuptoolsScm;
  pytest-runner = withSetuptoolsScm;
  pytest-xdist = withSetuptoolsScm;
  python-dateutil = {
    imports = [withSetuptoolsScm];
    config.buildPythonPackage.pythonRelaxDeps = [ "setuptools_scm" ];
  };
  python-multipart = withHatchling;
  pytzdata = {
    imports = [withPoetryCore];
  };
  pyyaml = withCython0;
  pyzmq = {config, ...}: {
    imports = [withCMake];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) zeromq libsodium;
      };
      mkDerivation.buildInputs = [
        config.deps.zeromq
        config.deps.libsodium
      ];
    };
  };
  rapidfuzz.imports = [withSKBuild withCMake];
  redshift-connector = useWheel;
  referencing = withHatchVcs;
  requests-file = withSetuptoolsScm;
  retry = withPbr;
  rfc3986-validator = {config, ...}: {
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.pytest-runner];
  };
  rich = withPoetryCore;
  rpds-py = withMaturin;
  rsa = withPoetryCore;
  safetensors = withMaturin;
  scikit-image = {config, ...}: {
    imports = [withNumpy withLibCPP withCython];
  };
  scikit-learn.imports = [withNumpy withCoreutils withCython];
  scipy = {config, ...}: {
    imports = [withNumpy];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) gfortran openblas;
      };
      pip.nativeBuildInputs = [
        config.deps.gfortran
        config.deps.openblas
      ];
      mkDerivation.buildInputs = [
        config.deps.gfortran
        config.deps.openblas
      ];
    };
  };
  scramp = {config, ...}: {
    imports = [withHatchling];
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.versioningit];
  };
  seaborn = withFlitCore;
  selenium.imports = [withSetuptoolsRust];
  semver = withSetuptoolsScm;
  sentencepiece.imports = [withCMake];
  setuptools.pip.ignoredDependencies = lib.mkForce ["wheel"];
  shapely = {config, ...}: {
    imports = [withLibCPP withCython];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) geos;
      };
      mkDerivation.buildInputs = [
        config.deps.geos
      ];
    };
  };
  slack-sdk = {config, ...}: {
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.pytest-runner];
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
  thrift.imports = [withDistutils];
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
    config.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.calver];
  };
  typeguard = withSetuptoolsScm;
  typer = withPdmBackend;
  typing-extensions = withFlitCore;
  ujson = withSetuptoolsScm;
  uri-template = withSetuptoolsScm;
  urllib3 = withHatchling;
  uvicorn = withHatchling;
  uvloop = withCython0;
  virtualenv = withHatchVcs;
  wandb = useWheel;
  watchfiles = withMaturin;
  werkzeug = withFlitCore;
  wheel = {
    imports = [withFlitCore];
    config.pip.ignoredDependencies = lib.mkForce ["setuptools"];
  };
  widgetsnbextension = {config, ...}: {
    mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.jupyter-packaging];
  };

  xgboost = {config, ...}: {
    imports = [withCMake];
    config = {
      deps = {nixpkgs, ...}: {
        inherit (nixpkgs) gnumake;
      };
      pip.nativeBuildInputs = [config.deps.gnumake];
      mkDerivation.nativeBuildInputs = [config.deps.gnumake];
    };
  };
  yarl.imports = [withCython withExpandVars];
  zipp = withSetuptoolsScm;
}
