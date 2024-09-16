{ lib, fullSitePathRoot, referenceCSS, referenceSCSS, referencePage, file-gen, ...}:
let
  inherit (file-gen) html;

  e = html.mkElement;
in
[
html.doctype
(e "html" { lang="en"; } [
  (e "head" {} [
    (e "meta" { charset="UTF-8"; } null)
    (e "meta" { name="viewport"; content="width=device-width, initial-scale=1.0"; } null)
    (e "title" {} "Test <Page> :)")
    (e "link" { rel="stylesheet"; href=referenceCSS ./css/style.nix; } null)
    (e "link" { rel="stylesheet"; href=referenceCSS ./css/style2.css; } null)
    (e "link" { rel="stylesheet"; href=referenceSCSS ./css/style3.scss; } null)
    (e "link" { rel="stylesheet"; href=referencePage {
      content = /* css */ ''
        html {
          background: blue;
        }
      '';
      fullSitePath = "/hmmm/this/random/path/lol.css";
    }; } null)
    (e "script" { type="text/javascript"; } (html.mkRaw /* javascript */ ''
      console.log("<> > &lt;&gt;")
    ''))
  ])
  (e "body" {} [
    (e "p" { id="test"; } "<> > &lt;&gt; : escaping by default")
  ])
])
]
