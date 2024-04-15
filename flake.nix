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
    eachSystem = nixpkgs.lib.genAttrs (import systems);
    setup = {
      paths.projectRoot = ./.;
      # can be changed to ".git" or "flake.nix" to get rid of .project-root
      paths.projectRootFile = "flake.nix";
      paths.package = ./.;
    };
    makePackage = system: module: dream2nix.lib.evalModules {
      packageSets.nixpkgs = nixpkgs.legacyPackages.${system};
      modules = [
        setup
        module
      ];
    };
  in {
    packages = eachSystem(system: {
      default = makePackage system ./default.nix;
    });
  };
}
