{ pkgs, fh-lib }:

fh-lib.mkSite pkgs {
  # this would be `/site/path` for "example.com/site/path"
  fullSitePathRoot = /. + (builtins.placeholder "out");
  siteRoot = ./site;
  siteRootPageArgs = {
    defaultDirectoryFile = "index.html";
  };
  dereferenceLinks = true;
  extraArgs = import ./src pkgs;
}
