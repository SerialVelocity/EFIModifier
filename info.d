import Console  : Console;
import EFI      : EFI, File, UserInterfaceSection, RawSection;
import EFIUtils : printEFI, printFileMapping;

import std.exception : enforce;
import std.file      : read;
import std.string    : format;

int main(string[] args) {
  Console.Init(args, format("USAGE: %s <INPUT WPH>", args[0]));
  string file = Console.GetInput!string("Please enter a filename");

  auto containers = EFI.parse(file);

  foreach(container; containers) {
    debug printEFI(container);
    printFileMapping(container);
  }

  //Sanity check
  debug {
    ubyte[] newEFI = EFI.getBinary(containers);
    ubyte[] oldEFI = cast(ubyte[])read(file);
    enforce(newEFI.length == oldEFI.length);
    enforce(newEFI == oldEFI);
  }

  return 0;
}