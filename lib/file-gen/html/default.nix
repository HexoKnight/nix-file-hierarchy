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
    ...
  }:
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
  in
  {
    parts =
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
{
  mkElement = name: attributes: content:
  lib.setType elementType {
    inherit name attributes content;
    __toContent = elementAttrsToContent;
    metadata = {
      escaped = true;
    };
  };

  mkRaw = content: setContentDataByPath [ "htmlMetadata" "escaped" ] true (mkContent content);

  # there are technically other ways to write the DOCTYPE
  # but this is the only non-legacy way specified by the
  # html standard: https://html.spec.whatwg.org/#syntax-doctype
  doctype = "<!DOCTYPE html>";

  public = {
    inherit mkElement mkRaw doctype;
  };
}
