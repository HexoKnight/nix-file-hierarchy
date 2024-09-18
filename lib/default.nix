lib:

let
  withInputs = inputs: lib.fix (
    lib.extends
      (_final: _prev: { inherit inputs; })
      fh-lib
  );

  extraExtension = lib.composeManyExtensions (
    lib.mapAttrsToList (name: file: final: prev:
      let
        extraLib = import file final;
        total = public // extraLib;
        public = extraLib.public or {};

        extraTotal = total // { ${name} = total; };
        extraPublic = public // { ${name} = public; };
      in
      extraTotal // {
        public = prev.public // extraPublic;
      }
    ) {
      content = ./content.nix;
      pages = ./pages.nix;
    }
  );

  getPublicRecursive = lib.mapAttrsRecursiveCond
    (a: ! a ? public)
    (_: v: if lib.isAttrs v then v.public else v);

  fh-lib = lib.extends extraExtension (fh-lib: {
    inherit lib;

    inherit withInputs;

    mkSite = import ./mkSite.nix fh-lib;

    file-gen = import ./file-gen fh-lib;

    public = {
      inherit (fh-lib) mkSite;
      file-gen = getPublicRecursive fh-lib.file-gen;
    };
  });
in
lib.fix fh-lib
