{ pkgs, fh-lib }:

fh-lib.mkSite pkgs {
  fullSitePathRoot = /nix-file-hierarchy;
  siteRoot = ./site;
  siteRootPageArgs = {
    defaultDirectoryFile = "index.html";
  };
  # the github action `actions/upload-pages-artifact@v3`
  # will dereference links for us automatically
  dereferenceLinks = false;
  extraArgs = import ./src pkgs;
}
