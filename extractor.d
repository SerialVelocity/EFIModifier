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
  if(dumpdir.exists()) {
    stderr.writefln("Dump folder \"%s\" already exists. Please delete the dump first", dumpdir);
    return 1;
  }

  mkdir(dumpdir);
  chdir(dumpdir);

  foreach(file; findAll!File(container)) {
    auto name = find!UserInterfaceSection(file);
    auto raw = find!RawSection(file);
    if(name !is null && raw !is null) {
      enforce(!exists(name.fileName));
      write(name.fileName, raw.data);
    }
  }

  return 0;
}