{ lib, withInputs, ...}:

pkgs:

{
  /**
    The path representing the root of the file heirarchy.

    Generally this will be something like `./site` where
    ./site contains a hierarchy approximately representing
    the result.
  */
  siteRoot,
  /**
    Extra arguments passed to the root mkPage when `getRootPages` is unset
  */
  siteRootPageArgs ? {},

  /**
    A function taking page inputs and producing an attrset of
    the root pages of the file heirarchy.
    The set of pages produced in the result will be the set of
    pages transitively referenced by these ones.

    The resulting attrset's names are paths that the content specified
    in the respective values will be created at.

    This defaults to importing `siteRoot` as a page using args
    from `siteRootPageArgs`.

    # Example
    ```nix
    { extraArgs, ... }:
    {
      "/index.html" = ./site/index.nix;
      "/other/resource.foo" = extraArgs.otherResource;
      ...
    }
    ```
  */
  getRootPages ? { mkPage, ... }:
    let
      rootPage = mkPage ({ path = siteRoot; } // siteRootPageArgs);
    in {
      ${rootPage.fullSitePath} = rootPage.content;
    },

  /**
    Allow `siteRoot` to be a store path.
    This is usually a mistake so it is disabled by default.
  */
  allowFullSitePathInStore ? false,

  /**
    The root of the site used in links. Must be an absolute path

    For example referencing `${siteRoot}/foo/bar`
    will produce a link to `${fullSitePathRoot}/foo/bar`
  */
  fullSitePathRoot ? /.,

  /**
    Whether to resolve all symlinks when constructing
    the final file hierarchy in the nix store.
    this is mainly useful if the heirarchy
  */
  dereferenceLinks ? false,

  /**
    default arguments to mkPage
  */
  pageDefaults ? {},
  /**
    extra arguments passed to all pages

    if this is a function, it is passed the these same args
    as each page minus individual extraArgs attrs
    (due to infinite recursion)
  */
  extraArgs ? {}
}:

# pages are passed the following arguments:
# - lib # obvious enough
# - fh-lib (and each individual attr separately)
# - extraArgs (and each indiviual attr separately)
# - siteRoot, fullSitePathRoot, pageDefaults # as passed into mkSite

let
  inputs = inputsWithoutExtraArgs // finalExtraArgs;

  inputsWithoutExtraArgs = {
    inherit lib siteRoot fullSitePathRoot pageDefaults;
    extraArgs = finalExtraArgs;
    fh-lib = fh-libPublic;
  } // fh-libPublic;

  # could pass full `inputs` to `extraArgs` with lib.extends
  # but then `extraArgs` couldn't destructure it's argument
  finalExtraArgs =
    if builtins.isFunction extraArgs then
      extraArgs inputsWithoutExtraArgs
    else
      extraArgs;

  fh-libPublic = fh-libWithInputs.public;

  fh-libWithInputs = withInputs inputs;


  inherit (fh-libWithInputs) equalContents mkContent;

  #TODO: maybe also record which pages referenced them

  extractReferencedPages' = { evaluatedPages ? {}, toBeEvaluatedPages ? {}, currentPage }:
  let
    content = mkContent currentPage.content;

    referencedPages = lib.pipe (content.result.pagesReferenced or []) [
      (builtins.groupBy (page: page.fullSitePath))
      (lib.filterAttrs (fullSitePath: pages:
        let
          contents = map (page: page.content) pages;
          pageIsCurrent = currentPage.fullSitePath == fullSitePath;

          pageFoundPreviously = (evaluatedPages // toBeEvaluatedPages) ? ${fullSitePath};
          comparativeContent =
            if pageIsCurrent then
              content
            else if pageFoundPreviously then
              (evaluatedPages // toBeEvaluatedPages).${fullSitePath}
            else builtins.head contents;
          unequalContents = builtins.filter (content: !equalContents comparativeContent content) contents;
        in
        assert lib.assertMsg (unequalContents == []) ''
          page at '${fullSitePath}' has conflicting definitions:
          ${lib.escapeShellArg comparativeContent}
          vs
          ${lib.concatMapStringsSep "\n" lib.escapeShellArg unequalContents}
        '';
        # TODO: actually display origin of conflicting definitions
        ! pageIsCurrent && ! pageFoundPreviously
      ))
      (builtins.mapAttrs (_fullSitePath: pages: (builtins.head pages).content))
    ];
  in
  extractReferencedPages {
    evaluatedPages = evaluatedPages // {
      ${currentPage.fullSitePath} = content;
    };
    toBeEvaluatedPages = toBeEvaluatedPages // referencedPages;
  };

  extractReferencedPages = { evaluatedPages ? {}, toBeEvaluatedPages }:
    if toBeEvaluatedPages == {} then
      evaluatedPages
    else
      let
        nextPage = rec {
          fullSitePath = builtins.head (builtins.attrNames toBeEvaluatedPages);
          content = toBeEvaluatedPages.${fullSitePath};
        };
      in
      extractReferencedPages' {
        inherit evaluatedPages;
        toBeEvaluatedPages = builtins.removeAttrs toBeEvaluatedPages [ nextPage.fullSitePath ];
        currentPage = nextPage;
      };

  allPages = extractReferencedPages {
    toBeEvaluatedPages =
      assert lib.assertMsg (lib.path.hasStorePathPrefix fullSitePathRoot -> allowFullSitePathInStore) ''
        `fullSitePathRoot` is a nix store path: '${toString fullSitePathRoot}'
        So all page references will point to the nix store. This is probably a
        mistake but if it is intentional enable `allowFullSitePathInStore` in mkSite
      '';
      getRootPages inputs;
  };
  allFullSitePaths = builtins.attrNames allPages;

  pageContents = builtins.mapAttrs (fullSitePath: content:
    let
      conflictingFullSitePaths = builtins.filter (otherFullSitePath:
        fullSitePath != otherFullSitePath && (
          lib.hasPrefix fullSitePath otherFullSitePath ||
          lib.hasPrefix otherFullSitePath fullSitePath
        )
      ) allFullSitePaths;
    in
    assert lib.assertMsg (conflictingFullSitePaths == []) ''
      page at '${fullSitePath}' conflicts with pages at:
      ${lib.concatMapStringsSep "\n" lib.escapeShellArg conflictingFullSitePaths}
    '';
    lib.attrsets.removeAttrs content.result [ "pagesReferenced" ]
  ) allPages;
in
pkgs.runCommand "site" {
  __structuredAttrs = true;
  inherit pageContents;
} ''
  echo $out
  ${lib.getExe pkgs.miller} -x --from "$NIX_ATTRS_JSON_FILE" --json put '
    for (fullSitePath, content in $pageContents) {
      dir = "'$out'" . fullSitePath;
      exec("mkdir", [ "-p", exec("dirname", [ dir ], {}) ], {});
      if (haskey(content, "text")) {
        print >dir, content.text;
      }
      else { # haskey(content, "path")
        ${if dereferenceLinks
          then ''exec("cp", [ "-r", "-T", content.path, dir ], {});''
          else ''exec("ln", [ "-s", "-T", content.path, dir ], {});''
        }
      }
    }
  '
''
