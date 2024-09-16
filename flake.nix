{
  description = "A library for building file hierarchies (think static sites) using nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
  };

  outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;
    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  in
  {
    lib = (import ./lib lib).public;

    packages = forAllSystems (system: rec {
      site = import ./example {
        fh-lib = self.lib;
        pkgs = nixpkgs.legacyPackages.${system};
      };

      default = site;
    });
  };
}
