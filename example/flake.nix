{
  description = "A static website, built with nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-23.11";
    nix-file-hierarchy = {
      url = "github:HexoKnight/nix-file-hierarchy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-file-hierarchy }:
  let
    lib = nixpkgs.lib;
    forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  in
  {
    packages = forAllSystems (system: rec {
      site = import ./. {
        fh-lib = nix-file-hierarchy.lib;
        pkgs = nixpkgs.legacyPackages.${system};
      };

      default = site;
    });
  };
}
