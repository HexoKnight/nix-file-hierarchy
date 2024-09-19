{ lib, mapContentText, getContentData, setContentDataByPath, mkContent, unsafeGetContentText, ... }@fh-lib:

let
  elementType = "html-element";

  isElement = lib.isType elementType;

  attributeToContent = name: value:
  if value == true then [ " ${name}" ]
  else if value == false then []
  else [
    " ${name}='"
    (escapeContent value)
    "'"
  ];

  # works perfectly for HTML as well
  # (kinda obvious but felt worth noting)
  escapeContent = content: mkRaw (mapContentText lib.escapeXML content);

  /**
    Return the input content as is (ie. without html escaping).
    NOTE: there is no escaping so this can be dangerous if the content contains invalid html

    # Inputs
    `content`
    : Content-like input

    # Type
    ```
    mkRaw :: Content-like -> Content
    ```
  */
  mkRaw = setContentDataByPath [ "htmlMetadata" "raw" ] true;

  elementAttrsToList = {
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

    contentList = map (value:
      let
        content = mkContent value;
      in
      if isElement value then
        elementAttrsToList value
      else if (getContentData content).htmlMetadata.raw or (! metadata.escapeContent) then
        content
      else
        escapeContent content
    ) (lib.flatten content);

    checkedContent = mapContentText (text:
      assert assertChecks contentChecks text;
      text
    ) contentList;

    finalContentList = if contentChecks == [] then contentList else [ checkedContent ];
  in
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
in
rec {
  inherit isElement;

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
    metadata = {
      raw = false;
      escapeContent = true;
    } // metadata;
  };

  /**
    Converts a html element into Content.

    Be aware that although Elements can be converted to Content, the conversion is one-way
    and afterwards, the element is just treated as raw text so can only be properly nested
    within another element using `mkRaw`.

    # Inputs
    `element`
    : html element

    # Type
    ```
    elementToContent :: Element -> Content
    ```
  */
  elementToContent = element: {
    parts = elementAttrsToList element;
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
    Create html content.
    This is literally just a shorthand for:
    ```nix
    [
      doctype
      (elementToContent (element.html <args...>))
    ]
    ```

    # Inputs
    `attributes`
    : attributes to add to the toplevel html element
    `content`
    : content to add to the toplevel html element

    # Type
    ```
    mkHtml :: attrset -> ElementContent -> Content
    ```
  */
  mkHtml = attributes: content: [
    doctype
    (elementToContent (elements.element.html attributes content))
  ];

  inherit mkRaw;

  # there are technically other ways to write the DOCTYPE
  # but this is the only non-legacy way specified by the
  # html standard: https://html.spec.whatwg.org/#syntax-doctype
  doctype = "<!DOCTYPE html>";

  elements = import ./elements.nix fh-lib;

  public = {
    inherit elementToContent addChecks addCheck mkHtml mkRaw doctype;
    inherit (elements) element;
  };
}
