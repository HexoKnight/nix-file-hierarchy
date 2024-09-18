{ lib, mapContentText, getContentData, setContentDataByPath, mkContent, ... }:

let
  elementType = "html-element";

  isElement = lib.isType elementType;

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
    metadata,
    checks,
    ...
  }@attrs:
  let
    contentList = lib.toList content;
    escapedContentList = map (value:
      let
        content = mkContent value;
      in
      if (getContentData content).htmlMetadata.escaped or false then
        content
      else
        escapeContent content
    ) contentList;

    checkResults = builtins.map (f: f attrs) checks;
    failedChecks = lib.filter (f: f != true) checkResults;
    numFailedChecks = lib.length failedChecks;
  in
  {
    parts =
      assert lib.assertMsg (numFailedChecks == 0) (lib.concatMapStringsSep "\n" toString
        [ "${if numFailedChecks == 1 then "a check" else "${numFailedChecks} checks"} for a '${name}' element failed:" ]
        ++ failedChecks
      );
      [ "<${name}" ]
      ++ lib.mapAttrsToList attributeToContent attributes
      ++ (
        if content == null then
          # / is only required on foreign elements
          # but it's ignored otherwise so may as well
          [ " />" ]
        else
          [ ">" ] ++ escapedContentList ++ [ "</${name}>" ]
      );
    data.htmlMetadata = metadata;
  };
in
rec {
  mkElementAttrs = {
    name,
    attributes,
    content,

    checks ? [],
    metadata ? {},
  }:
  lib.setType elementType {
    inherit name attributes content checks;
    __toContent = elementAttrsToContent;
    metadata = {
      # the __toContent will handle escaping when necessary
      escaped = true;
    } // metadata;
  };

  mkElement = name: attributes: content: mkElementAttrs {
    inherit name attributes content;
  };

  addChecks = checks: element: element // { checks = element.checks ++ checks; };
  addCheck = check: element: addChecks [ check ];

  mkRaw = content: setContentDataByPath [ "htmlMetadata" "escaped" ] true (mkContent content);

  # there are technically other ways to write the DOCTYPE
  # but this is the only non-legacy way specified by the
  # html standard: https://html.spec.whatwg.org/#syntax-doctype
  doctype = "<!DOCTYPE html>";

  public = {
    inherit mkElement addChecks addCheck mkRaw doctype;
  };
}
