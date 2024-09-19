{ lib, file-gen, ... }:

let
  inherit (file-gen.html) isElement mkElementAttrs elementToString;

  mkFunctor = { f, ... }@attrs:
  lib.attrsets.removeAttrs attrs [ "f" ] // {
    __functor = _: f;
  };

  /**
    Create a html element.
    Functions to create specific elements are available as attributes of this 'function'.
    You shouldn't need to use this function for anything other than foreign and custom elements.
    If you do, open an issue.

    The type used in docs is `Element` and it is `Content-like` (ie. it can be converted to Content).

    # Inputs
    `name`
    : name of the element
    `attributes`
    : attrset of attributes to be located in the start tag
    `content`
    : Content (usually a list) that will occur between the start and end tag
      (null is the element is void/self-closing)

    # Type
    ```
    element :: string -> attrset -> Content -> Element
    ```
  */
  element = name: attributes: content: mkElementAttrs {
    inherit name attributes content;
  };

  mkElement = name:
    /**
      Create a normal element.

      # Inputs
      `attributes`
      : attrset of attributes to be located in the start tag
      `content`
      : Content (usually a list) that will occur between the start and end tag.
        Can contain other elements.

      # Type
      ```
      ${name} :: attrset -> Content -> Element
      ```
    */
    attributes: content: mkElementAttrs {
      inherit name attributes content;
    };

  mkVoid = name:
    /**
      Create a void element.

      # Inputs
      `attributes`
      : attrset of attributes to be located in the tag

      # Type
      ```
      ${name} :: attrset -> Element
      ```

      See: https://html.spec.whatwg.org/#void-elements
    */
    attributes: mkElementAttrs {
      inherit name attributes;
      content = null;
    };

  # nix does not have a formfeed escape :/
  formfeed = builtins.fromJSON ''"\f"'';

  # See: https://html.spec.whatwg.org/#cdata-rcdata-restrictions
  rawTextCheck = escapable: { name, content, ... }:
    let
      flatContentList = lib.flatten content;
      htmlContentList = lib.filter (v: isElement v) flatContentList;
    in
    if htmlContentList == [] then
      true
    else ''
      ${if escapable then "An escapable" else "A"} raw text element's content can technically contain elements but they are ignored:
      For more information see: https://html.spec.whatwg.org/#syntax-elements
    first few contained:
      ${lib.concatMapStringsSep "\n" (elementToString {}) (lib.take 3 htmlContentList)}
      ...
    '';
  rawTextContentCheck = name: escapable: text:
    let
      context = 2;

      match = builtins.match "(.*)(</${name}[\t\n${formfeed}\r >/])(.*)" text;

      before = builtins.elemAt match 0;
      invalid = builtins.elemAt match 1;
      after = builtins.elemAt match 2;

      beforeLines = lib.splitString "\n" before;
      beforeContext = lib.concatStringsSep "\n" (lib.sublist (lib.length beforeLines - context) context beforeLines);
      afterLines = lib.splitString "\n" after;
      afterContext = lib.concatStringsSep "\n" (lib.sublist 0 context afterLines);
    in
    if match == null then
      true
      # and before you ask, this is how nixpkgs colours its traces
      # it obviously doesn't change the fact that inserting non-printable
      # characters into source code is terrible... but I'll live
    else ''
      ${if escapable then "An escapable" else "A"} raw text element's content cannot contain the start of it's own end tag: '</${name}'.
      For more information see: https://html.spec.whatwg.org/#cdata-rcdata-restrictions
      The relevant invalid text:
      ...
      ${beforeContext}[1;31m${invalid}[0m${afterContext}
      ...
    '';

  mkEscapableRawText = name:
    /**
      Create an escapable raw text element.

      # Inputs
      `attributes`
      : attrset of attributes to be located in the start tag
      `content`
      : Content (usually a list) that will occur between the start and end tag

      # Type
      ```
      ${name} :: attrset -> Content -> Element
      ```

      See: https://html.spec.whatwg.org/#escapable-raw-text-elements
    */
    attributes: content: mkElementAttrs {
      inherit name attributes content;
      checks = [ (rawTextCheck true) ];
      contentChecks = [ (rawTextContentCheck name true) ];
    };

  mkRawText = name:
    /**
      Create an raw text element.

      # Inputs
      `attributes`
      : attrset of attributes to be located in the start tag
      `content`
      : Content (usually a list) that will occur between the start and end tag

      # Type
      ```
      ${name} :: attrset -> Content -> Element
      ```

      See: https://html.spec.whatwg.org/#raw-text-elements
    */
    attributes: content: mkElementAttrs {
      inherit name attributes content;
      checks = [ (rawTextCheck true) ];
      contentChecks = [ (rawTextContentCheck name false) ];
      metadata.escapeContent = false;
    };
in
{
  element = mkFunctor {
    f = element;

    # should have all (non-deprecated) html elements
    # in order of appearance at https://html.spec.whatwg.org/#toc-semantics

    html = mkElement "html";
    head = mkElement "head";
    title = mkEscapableRawText "title";
    base = mkVoid "base";
    link = mkVoid "link";
    meta = mkVoid "meta";
    style = mkRawText "style";
    body = mkElement "body";
    article = mkElement "article";
    section = mkElement "section";
    nav = mkElement "nav";
    aside = mkElement "aside";
    h1 = mkElement "h1";
    h2 = mkElement "h2";
    h3 = mkElement "h3";
    h4 = mkElement "h4";
    h5 = mkElement "h5";
    h6 = mkElement "h6";
    hgroup = mkElement "hgroup";
    header = mkElement "header";
    footer = mkElement "footer";
    address = mkElement "address";
    p = mkElement "p";
    hr = mkVoid "hr";
    pre = mkElement "pre";
    blockquote = mkElement "blockquote";
    ol = mkElement "ol";
    ul = mkElement "ul";
    menu = mkElement "menu";
    li = mkElement "li";
    dl = mkElement "dl";
    dt = mkElement "dt";
    dd = mkElement "dd";
    figure = mkElement "figure";
    figcaption = mkElement "figcaption";
    main = mkElement "main";
    search = mkElement "search";
    div = mkElement "div";
    a = mkElement "a";
    em = mkElement "em";
    strong = mkElement "strong";
    small = mkElement "small";
    s = mkElement "s";
    cite = mkElement "cite";
    q = mkElement "q";
    dfn = mkElement "dfn";
    abbr = mkElement "abbr";
    ruby = mkElement "ruby";
    rt = mkElement "rt";
    rp = mkElement "rp";
    data = mkElement "data";
    time = mkElement "time";
    code = mkElement "code";
    var = mkElement "var";
    samp = mkElement "samp";
    kbd = mkElement "kbd";
    sub = mkElement "sub";
    sup = mkElement "sup";
    i = mkElement "i";
    b = mkElement "b";
    u = mkElement "u";
    mark = mkElement "mark";
    bdi = mkElement "bdi";
    bdo = mkElement "bdo";
    span = mkElement "span";
    br = mkVoid "br";
    wbr = mkVoid "wbr";
    ins = mkElement "ins";
    del = mkElement "del";
    picture = mkElement "picture";
    source = mkVoid "source";
    img = mkVoid "img";
    iframe = mkElement "iframe";
    embed = mkVoid "embed";
    object = mkElement "object";
    video = mkElement "video";
    audio = mkElement "audio";
    track = mkVoid "track";
    map = mkElement "map";
    area = mkElement "area";
    table = mkElement "table";
    caption = mkElement "caption";
    colgroup = mkElement "colgroup";
    col = mkVoid "col";
    tbody = mkElement "tbody";
    thead = mkElement "thead";
    tfoot = mkElement "tfoot";
    tr = mkElement "tr";
    td = mkElement "td";
    th = mkElement "th";
    form = mkElement "form";
    label = mkElement "label";
    input = mkVoid "input";
    button = mkElement "button";
    select = mkElement "select";
    datalist = mkElement "datalist";
    optgroup = mkElement "optgroup";
    option = mkElement "option";
    textarea = mkEscapableRawText "textarea";
    output = mkElement "output";
    progress = mkElement "progress";
    meter = mkElement "meter";
    fieldset = mkElement "fieldset";
    legend = mkElement "legend";
    details = mkElement "details";
    summary = mkElement "summary";
    dialog = mkElement "dialog";
    script = mkRawText "script";
    noscript = mkElement "noscript";
    template = mkElement "template";
    slot = mkElement "slot";
    canvas = mkElement "canvas";
  };
}
