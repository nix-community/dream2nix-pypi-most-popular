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

    toSkip = [];
    packages = lib.filterAttrs (n: v: !(builtins.elem n toSkip)) mostPopular;

    overrides = {
      psycopg2 = { config, ...}: {
        deps = { nixpkgs, ... }: {
          inherit (nixpkgs) pkg-config postgresql;
        };
        pip = {
          nativeBuildInputs = with config.deps; [
            pkg-config
            postgresql
          ];
        };
      };
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
            pip = {
              requirementsList = [ "${name}==${version}" ];
              pipFlags = ["--no-binary" name];
            };
          })
          (overrides.${name} or {})
        ];
      };
  in {
    packages = eachSystem(system:
      lib.mapAttrs (name: version: makePackage {inherit name version system; }) packages
      );

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
    in {
      default = pkgs.mkShell {
      };
    });

  };
}
