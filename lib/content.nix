fh-lib:

let
  inherit (fh-lib) lib inputs;

  contentType = "content";

  isContent = lib.isType contentType;

  mkContentAttrs = attrs@{
    # default value should not be used for these five
    # (they're only here for arg checking)
    text ? null,
    parts ? null,
    path ? null,
    import ? null,
    derivation ? null,

    data ? {},

    pagesReferenced ? [],
  }:
  let
    hasText = attrs ? text;
    hasParts = attrs ? parts;
    hasPath = attrs ? path;
    hasImport = attrs ? import;
    hasDerivation = attrs ? derivation;
    oneTrue = list: builtins.length (builtins.filter (x: x) list) == 1;
  in
  assert lib.assertMsg (oneTrue [ hasText hasParts hasPath hasImport hasDerivation ])
    "mkContent: exactly 1 of 'text', 'parts', 'path', 'import' or 'derivation' must be given";
  assert lib.assertMsg (attrs ? pagesReferenced -> attrs ? text)
    "mkContent: 'pagesReferenced' can only be set if 'text' is set";

  lib.setType contentType (attrs // {
    inherit data;
    result =
    if hasText then
      { inherit text pagesReferenced; }
    else if hasParts then
      let
        evaledParts = map (part:
          let
            inherit (mkContent part) result;
          in
          # this should be fine as there's not really a good way
          # to guarantee that a path even points to a text file
          # anyway then even if it does, readFile should suffice
          # (along with providing that eval-time guarantee)
          assert lib.assertMsg (result ? text) ''
            all parts must be string-like when contents created from list
            use `builtins.readFile` to insert a file as text
          '';
          result
        ) parts;
        results = lib.zipAttrsWith (_name: values: values) evaledParts;
      in
      {
        text = lib.concatStrings results.text;
        pagesReferenced = lib.unique (builtins.concatLists results.pagesReferenced);
      }
    else if hasPath then
      { inherit path; }
    else if hasImport then
      (mkContent (builtins.import import inputs)).result
    else if hasDerivation then
      { path = derivation.outPath; }
    else abort "unreachable";
  });

  mkContent = content:
    if isContent content then
      content
    else if content ? __toContent then
        mkContent (content.__toContent content)
    else mkContentAttrs (
      if builtins.isString content then
        { text = content; }
      else if builtins.isList content then
        { parts = content; }
      else if builtins.isPath content then
        let
          isNixImport = path:
            builtins.pathExists path &&
            { regular = lib.hasSuffix ".nix" path;
              directory = isNixImport /${path}/default.nix;
            }.${builtins.readFileType path} or false;
        in
        if isNixImport content then
          { import = content; }
        else
          { path = content; }
      else if lib.isDerivation content then
        { derivation = content; }
      else if builtins.isAttrs content then
        content
      else throw "mkContent arg must be a string, a list, a path or an attrset"
    );

  equalContents = left: right:
    let
      leftContent = mkContent left;
      rightContent = mkContent right;
    in
    if leftContent ? path && rightContent ? path then
      leftContent.path == rightContent.path
    else if leftContent ? import && rightContent ? import then
      leftContent.import == rightContent.import
    else if leftContent ? derivation && rightContent ? derivation then
      leftContent.derivation == rightContent.derivation
    else if leftContent ? parts && rightContent ? parts then
      #TODO: maybe compare these using equalContents recursively???
      leftContent.parts == rightContent.parts
    else
      leftContent.result == rightContent.result;

  setAttrValByPath = path: value: attrset:
    lib.recursiveUpdateUntil
      (p: l: r: p == path)
      attrset
      (lib.setAttrByPath path value);

  getContentData = arg: (mkContent arg).data;
  setContentDataByPath = path: value: arg:
    let
      content = mkContent arg;
    in
    content // {
      data = setAttrValByPath path value content.data;
    };

  mapContentText = f: arg:
    let
      content = mkContent arg;
    in
    content // {
      result = content.result // {
        text = f content.result.text;
      };
    };
in
{
  inherit mkContent equalContents;
  public = {
    inherit getContentData setContentDataByPath mapContentText;
  };
}
