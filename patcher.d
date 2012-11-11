import Console  : Console;
import Patch    : Patch;
import EFI      : EFI, EFIContainer, File, UserInterfaceSection, RawSection;
import EFIUtils : find, findAll, printEFI, printFileMapping;

import std.stdio     : writefln, write;
import std.file      : read, filewrite = write;
import std.exception : enforce;
import std.string    : format;

int main(string[] args) {
  Console.Init(args, format("USAGE: %s <INPUT WPH> <OUTPUT WPH> <PATCH FILE>", args[0]));
  string file = Console.GetInput!string("Please enter a filename");

  auto container = EFI.parseCapsule(file);
  debug printEFI(container);
  debug printFileMapping(container);

  //Sanity check
  debug {
    ubyte[] newEFI = EFI.getBinary(container);
    ubyte[] oldEFI = cast(ubyte[])read(file);
    enforce(newEFI.length == oldEFI.length);
    enforce(newEFI == oldEFI);
  }

  string outfile   = Console.GetInput!string("Please enter an output filename");
  string patchfile = Console.GetInput!string("Please enter a patch filename");
  Patch[] patches  = Patch.fromBinary(cast(ubyte[])read(patchfile));
  patch(container, patches);
  ubyte[] modEFI = EFI.getBinary(container);
  enforce(modEFI.length == read(file).length);
  filewrite(outfile, modEFI);

  return 0;
}

void patch(EFIContainer container, Patch[] patches) {
  foreach(file; findAll!File(container)) {
    auto name = find!UserInterfaceSection(file);
    auto raw  = find!RawSection(file);

    if(name !is null && raw !is null) {
      foreach(patch; patches) {
	if(name.fileName == patch.file) {
	  uint found = 0;
	  writefln("%s - Patching %s...", patch.name, name.fileName);
	  foreach(i; 0..raw.data.length - patch.search.length) {
	    if(raw.data[i..i + patch.search.length] == patch.search) {
	      ++found;
	      raw.data[i..i + patch.search.length] = patch.replace;
	    }
	  }
	  enforce(found == patch.occurs, format("%s - Failed. Patched %d/%d", patch.name, found, patch.occurs));
	  writefln("%s - Patched %u occurrences", patch.name, found);
	}
      }
    }
  }
}