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

    packages = forAllSystems (system:
      let
        args = {
          fh-lib = self.lib;
          pkgs = nixpkgs.legacyPackages.${system};
        };

        local-site = import ./example args;

        github-pages-site = import ./example/github-pages-site.nix args;
      in
      {
        inherit local-site github-pages-site;

        default = local-site;
    });
  };
}
