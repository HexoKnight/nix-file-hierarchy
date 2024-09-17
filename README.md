# nix-file-hierarchy

A nix library to allow building file hierarchies.

By file hierarchy, I more mean a [hierarchical file system](https://en.wikipedia.org/wiki/Hierarchical_file_system)
rather than Unix's [Filesystem Hierarchy Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard).

To be honest I couldn't really think of a nicer name for this.

## Example

See [the example site](example) for how a basic flake for a static html site might look.
This example is [hosted here](https://hexoknight.github.io/nix-file-hierarchy) if you want to check how it looks.
For most of the interesting stuff you will probably want to look through the actual generated source.

The [github action workflow](.github/workflows/deploySite.yaml) and its associated [file](example/github-pages-site.nix)
is also a fairly generic example of how to deploy a nix-file-hierarchy site to github pages.

## Features

- Standard programming abstractions can be used, for example you get
  a templating system more powerful than most static templating systems
  (and with no runtime overhead), essentially for free due to nix
- Files/directories can be nix derivations, allowing for a few fun things:
  - generating files/directories on the fly during the build
  - seamlessly compiling referenced files (eg. converting SCSS to CSS as in [the example](#Example))
- The generated hierarchy can reflect the source hierarchy with minimal effort
- Regular files/directories can be used as is in the generated hierarchy,
  so existing hierarchies can be converted gradually
- library for generating html files in a more 'nixy' way as shown in [the example](example/site/default.nix)
