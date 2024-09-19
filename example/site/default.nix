{ lib, fullSitePathRoot, referenceCSS, referenceSCSS, referencePage, file-gen, mapContentText, ...}:
let
  inherit (file-gen) html;

  e = html.element;
in
[
html.doctype
(html.elementToContent (e.html { lang="en"; } [
  (e.head {} [
    (e.meta { charset="UTF-8"; })
    (e.meta { name="viewport"; content="width=device-width, initial-scale=1.0"; })
    (e.title {} "Test <Page> </title> :)")
    (e.link { rel="stylesheet"; href=referenceCSS ./css/style.nix; })
    (e.link { rel="stylesheet"; href=referenceCSS ./css/style2.css; })
    (e.link { rel="stylesheet"; href=referenceSCSS ./css/style3.scss; })
    (e.link { rel="stylesheet"; href=referencePage {
      content = /* css */ ''
        html {
          background: blue;
        }
      '';
      fullSitePath = "/hmmm/this/random/path/lol.css";
    }; })
    (e.script { type="text/javascript"; } (/* javascript */ ''
      console.log("<> > &lt;&gt;")
      // nearly but not quite invalid
      console.log("</script")
    ''))
  ])
  (e.body {} [
    (e.p { id="t<e&st"; } "<> > &lt;&gt; : escaping by default")
  ])
]))
]
