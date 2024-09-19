{ lib, mapContentText, getContentData, setContentDataByPath, mkContent, unsafeGetContentText, ... }@fh-lib:

let
  elementType = "html-element";

  attributeToContent = name: value:
  if value == true then [ " ${name}" ]
  else if value == false then []
  else [
    " ${name}='"
    # works perfectly for HTML as well
    # (kinda obvious but felt worth noting)
    (mapContentText lib.escapeXML value)
    "'"
  ];

  escapeContent = content: lib.pipe content [
    (mapContentText lib.escapeXML)
    (setContentDataByPath [ "htmlMetadata" "escaped" ] true)
  ];

  elementAttrsToContent = {
    name,
    attributes,
    content,

    checks,
    contentChecks,
    metadata,
    ...
  }@attrs:
  let
    assertChecks = checks: arg:
      let
        checkResults = builtins.map (f: f arg) checks;
        failedChecks = lib.filter (f: f != true) checkResults;
        numFailedChecks = lib.length failedChecks;
      in
      lib.assertMsg (numFailedChecks == 0) (lib.concatMapStringsSep "\n" toString (
        [ "${if numFailedChecks == 1 then "a check" else "${numFailedChecks} checks"} for a '${name}' element failed:" ]
        ++ failedChecks
      ));

    rawContentList = lib.toList content;
    escapedContentList = map (value:
      let
        content = mkContent value;
      in
      if (getContentData content).htmlMetadata.escaped or false then
        content
      else
        escapeContent content
    ) rawContentList;

    contentList = if metadata.escapeContent then escapedContentList else rawContentList;

    checkedContent = mapContentText (text:
      assert assertChecks contentChecks text;
      text
    ) contentList;

    finalContentList = if contentChecks == [] then contentList else [ checkedContent ];
  in
  {
    parts =
      assert assertChecks checks attrs;
      [ "<${name}" ]
      ++ lib.mapAttrsToList attributeToContent attributes
      ++ (
        if content == null then
          # / is only required on foreign elements
          # but it's ignored otherwise so may as well
          [ " />" ]
        else
          [ ">" ] ++ finalContentList ++ [ "</${name}>" ]
      );
    data.htmlMetadata = metadata;
  };
in
rec {
  isElement = lib.isType elementType;

  mkElementAttrs = {
    name,
    attributes,
    content,

    checks ? [],
    contentChecks ? [],
    metadata ? {},
  }:
  lib.setType elementType {
    inherit
      name attributes content
      checks contentChecks;
    __toContent = elementAttrsToContent;
    metadata = {
      # the __toContent will handle escaping when necessary
      escaped = true;
      escapeContent = true;
    } // metadata;
  };

  elementToString = { shallow ? true, }: { name, attributes, content, ... }@element:
    if ! shallow then unsafeGetContentText element else
    let
      startTag = "<${name}${if attributes == {} then "" else " ..."}>";
      betweenContent = if content == [] then "" else " ... ";
      endTag = "</${name}>";
    in
    "${startTag}${if content == null then "" else betweenContent + endTag}";

  /**
    Add checks that take the element attrset and return true for success or a string describing the failure.

    # Inputs
    `checks`
    : checks to add
    `element`
    : html element to add the checks to

    # Type
    ```
    addChecks :: [(Element -> true|string)] -> Element -> Element
    ```
  */
  addChecks = checks: element: element // { checks = element.checks ++ checks; };
  addCheck = check: element: addChecks [ check ];

  /**
    Return the input content as is (ie. without html escaping).

    # Inputs
    `content`
    : Content-like input

    # Type
    ```
    mkRaw :: Content-like -> Content
    ```
  */
  mkRaw = content: setContentDataByPath [ "htmlMetadata" "escaped" ] true (mkContent content);

  # there are technically other ways to write the DOCTYPE
  # but this is the only non-legacy way specified by the
  # html standard: https://html.spec.whatwg.org/#syntax-doctype
  doctype = "<!DOCTYPE html>";

  elements = import ./elements.nix fh-lib;

  public = {
    inherit addChecks addCheck mkRaw doctype;
    inherit (elements) element;
  };
}
