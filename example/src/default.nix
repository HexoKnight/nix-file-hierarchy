pkgs:

{ lib, referencePage, mapContentText, ... }:

let
  # sourcemapping isn't very helpful due to them all being nix store paths
  compileSCSS = path: pkgs.runCommand (builtins.baseNameOf path) {} ''
    ${lib.getExe' pkgs.sass "scss"} --sourcemap=none ${path} $out
  '';
in
{
  referenceHTML = path: mapContentText (lib.removeSuffix "/index.html") (referencePage {
    inherit path;
    defaultDirectoryFile = "index";
    ensureExtension = "html";
    # TODO: test this more
  });

  referenceCSS = path: referencePage {
    inherit path;
    ensureExtension = "css";
    allowDirectory = false;
  };

  referenceSCSS = path: referencePage {
    content.derivation = compileSCSS path;
    inherit path;
    stripExtension = "scss";
    ensureExtension = "css";
    allowDirectory = false;
  };
}
