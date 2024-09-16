fh-lib:

let
  callLib = file: import file fh-lib;
in
{
  html = callLib ./html;
}
