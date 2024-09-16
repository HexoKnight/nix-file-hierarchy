fh-lib:

let
  inherit (fh-lib) lib;

  inherit (fh-lib.inputs)
    siteRoot
    fullSitePathRoot
    pageDefaults;

  mkPageAttrs = attrs@{
    # default value should not be used for these three
    # (they're only here for arg checking)
    content ? null,
    path ? null,
    fullSitePath ? null,

    defaultDirectoryFile ? pageDefaults.defaultDirectoryFile or "",
    allowDirectory ? pageDefaults.allowDirectory or true,

    stripExtension ? pageDefaults.stripExtension or "nix",
    ensureExtension ? pageDefaults.ensureExtension or "",
  }:
  let
    hasContent = attrs ? content;
    hasPath = attrs ? path;
    hasFullSitePath = attrs ? fullSitePath;
    oneTrue = list: builtins.length (builtins.filter (x: x) list) == 1;
  in
  assert lib.assertMsg (hasContent || hasPath)
    "mkPage: at least 1 of 'content' or 'path' must be given";
  assert lib.assertMsg (oneTrue [ hasPath hasFullSitePath ])
    "mkPage: exactly 1 of 'path' or 'fullSitePath' must be given";
  assert lib.assertMsg (hasFullSitePath -> builtins.isString fullSitePath)
    "mkPage: 'fullSitePath' must be a string";
  assert lib.assertMsg (hasPath -> builtins.isPath path)
    "mkPage: 'path' must be a path";
  lib.setType "page" ({
    # content will be lazily imported if a path
    content = attrs.content or path;
    fullSitePath = attrs.fullSitePath or (
      let
        isDirectory = builtins.readFileType path == "directory";
      in
      assert lib.assertMsg (lib.path.hasPrefix siteRoot path)
        "page path '${path}' must be within the site root '${siteRoot}'";
      assert lib.assertMsg (isDirectory -> allowDirectory)
        "page path '${path}' is a directory despite 'allowDirectory' being false";
      lib.pipe path (
        lib.optional (defaultDirectoryFile != "" && isDirectory)
          (path: lib.path.append path defaultDirectoryFile)
        ++ [
          (lib.path.removePrefix siteRoot)
          (lib.removePrefix ".")
          (lib.removeSuffix "/.")
        ]
        ++ lib.optional (stripExtension != "") (lib.removeSuffix ("." + stripExtension))
        ++ lib.optional (ensureExtension != "")
          (path: if lib.hasSuffix ensureExtension path then path else path + "." + ensureExtension)
      )
    );
  });

  isPage = lib.isType "page";

  mkPage = page:
    if isPage page then
      page
    else mkPageAttrs (
      if builtins.isPath page then
      {
        path = page;
      }
      else if builtins.isAttrs page then
        page
      else throw "mkPage arg must be a path or an attrset"
    );

  referencePage = page:
    let
      fullPage = mkPage (
        if builtins.isAttrs page
        then builtins.removeAttrs page [ "alterReference" ]
        else page
      );
    in {
      text = toString (lib.path.append fullSitePathRoot ("." + fullPage.fullSitePath));
      pagesReferenced = [ fullPage ];
    };
in
{
  inherit mkPage referencePage;
}
