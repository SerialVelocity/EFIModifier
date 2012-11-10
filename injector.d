import Console  : Console;
import EFI      : EFI, File;
import EFIUtils : find, findAll, printEFI, printFileMapping, UserInterfaceSection, RawSection;

import std.stdio     : stderr;
import std.file      : read, write, mkdir, chdir, exists;
import std.exception : enforce;

int main(string[] args) {
  Console.Init(args);
  string filename = Console.GetInput!string("Please enter a filename");

  auto container = EFI.parseCapsule(filename);
  debug printEFI(container);
  debug printFileMapping(container);

  //Sanity check
  ubyte[] newEFI = EFI.getBinary(container);
  ubyte[] oldEFI = cast(ubyte[])read(filename);
  enforce(newEFI.length == oldEFI.length);
  debug enforce(newEFI == oldEFI);

  auto dumpdir = filename ~ " dump";
  enforce(dumpdir.exists());

  chdir(dumpdir);

  foreach(file; findAll!File(container)) {
    auto name = find!UserInterfaceSection(file);
    auto raw = find!RawSection(file);
    if(name !is null && raw !is null) {
      enforce(exists(name.fileName));
      auto data = cast(ubyte[])read(name.fileName);
      enforce(data.length == raw.data.length);
      raw.data = data;
    }
  }

  auto modfile = filename ~ ".mod";
  enforce(!modfile.exists());

  auto modEFI = EFI.getBinary(container);
  enforce(modEFI.length == oldEFI.length);
  write(modfile, modEFI);

  return 0;
}