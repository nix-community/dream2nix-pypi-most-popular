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
    systems,
  }: let
    lib = nixpkgs.lib;
    eachSystem = lib.genAttrs (import systems);

    limit = 500;
    mostPopular =
      lib.listToAttrs
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

    skippedPackages = {
      "dataclasses" = "in pythons stdlib since python 3.8";
      "pypular" = "removed from pypi; https://tomaselli.page/blog/pypular-removed-from-pypi.html";
      "great-expectations" = "TODO versioneer is broken with python3.12";
      "opencv-python" = "TODO missing build inputs";
      "opt-einsum"  = "TODO versioneer is broken with python3.12";
      "pandas" = "TODO something about the numpy import breaks locking";
      "pydata-google-auth" = "TODO versioneer is broken with python3.12";
      "scipy" = "TODO f2py, a fortran tool failed during locking";
    };
    skippedPackageNames = lib.attrNames skippedPackages;
    overrides = import ./overrides.nix {inherit lib;};
    requirements = lib.filterAttrs (n: v: !(builtins.elem n skippedPackageNames)) mostPopular;
    makePackage = {
      name,
      version,
      system,
    }: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      dream2nix.lib.evalModules {
        packageSets.nixpkgs = pkgs;
        packageSets.local = {maturin = pkgs.callPackage ./maturin.nix {};};
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
            mkDerivation.nativeBuildInputs = with config.deps.python.pkgs; [setuptools wheel];
            pip = {
              ignoredDependencies = ["wheel" "setuptools"];
              requirementsList = ["${name}==${version}"];
              pipFlags = ["--no-binary" name];
            };
          })
          (overrides.${name} or {})
        ];
      };

    packagesToCheck = eachSystem (system: lib.mapAttrs (name: version: makePackage {inherit name version system;}) requirements);

    validated = eachSystem (system: let
      partitioned = builtins.partition (
        package: let
          result = builtins.tryEval package.config.lock.isValid;
        in
          result.success && result.value
      ) (builtins.attrValues packagesToCheck.${system});
      packages = lib.listToAttrs (map (p: {
          name = p.config.name;
          value = p;
        })
        partitioned.right);
      toLock = map (p: p.config.name) partitioned.wrong;
      lockScripts = lib.genAttrs toLock (name: packagesToCheck.${system}.${name}.lock);
    in {
      inherit packages lockScripts;
    });
  in {
    packages = packagesToCheck;

    checks = eachSystem (system: validated.${system}.packages);
    lockScripts = eachSystem (system: validated.${system}.lockScripts);
    inherit skippedPackages;
    apps = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lockAll = pkgs.writeShellApplication {
        name = "lock-all";
        runtimeInputs = [pkgs.nix-eval-jobs pkgs.coreutils pkgs.parallel pkgs.jq];
        text = ''
          nix-eval-jobs --flake .#lockScripts.${system} \
           | parallel --pipe "jq -r .drvPath" \
           | parallel --jobs "$(nproc)" "nix build --no-link --print-out-paths {}^out" \
           | parallel --jobs "$(nproc)" "{}/bin/refresh"
        '';
      };
      report = pkgs.writers.writePython3Bin "report" {
        libraries = [
          pkgs.python3.pkgs.jinja2
          pkgs.python3.pkgs.requests
        ];
        flakeIgnore = [ "E501" ];  # lines too long
      } ./report.py;
    in {
      lock-all = {
        type = "app";
        program = lib.getExe lockAll;
      };
      report = {
        type = "app";
        program = lib.getExe report;
      };
    });

    devShells = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3.withPackages (ps: [
        ps.python-lsp-server
        ps.python-lsp-ruff
        ps.pylsp-mypy
        ps.ipython
        ps.requests
        ps.jinja2
      ]);
    in {
      default = pkgs.mkShell {
        packages = [python pkgs.ruff pkgs.mypy pkgs.black];
      };
    });
  };
}
