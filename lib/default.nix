lib:

let
  withInputs = inputs: lib.fix (
    lib.extends
      (_final: _prev: { inherit inputs; })
      fh-lib
  );

  extraExtension = lib.composeManyExtensions (
    map (file: final: _prev: import file final) [
      ./content.nix
      ./pages.nix
    ]
  );

  fh-lib = lib.extends extraExtension (fh-lib: {
    inherit lib;

    inherit withInputs;

    mkSite = import ./mkSite.nix fh-lib;

    file-gen = import ./file-gen fh-lib;

    public = {
      inherit (fh-lib)
        mkSite file-gen
        # content
        getContentData setContentDataByPath mapContentText
        # pages
        mkPage referencePage;
    };
  });
in
lib.fix fh-lib
