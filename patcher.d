import Console  : Console;
import Patch    : Patch;
import EFI      : EFI, EFIContainer, File, UserInterfaceSection, RawSection;
import EFIUtils : find, findAll, printEFI, printFileMapping;
import Utils    : patchData;

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

ref ubyte[] getData(File file) {
  auto raw  = find!RawSection(file);
  if(raw !is null)
    return raw.data;
  else
    return file.data;
}

void patch(EFIContainer container, Patch[] patches) {
  foreach(file; findAll!File(container)) {
    auto name = find!UserInterfaceSection(file);

    foreach(patch; patches) {
      if((patch.file !is null && name !is null && name.fileName == patch.file) || patch.guid == file.guid) {
	writefln("%s - Patching %s...", patch.name, patch.file ? patch.file : patch.guid.toString());
	if(patch.fileReplace is null) {
	  auto found = patchData(getData(file), patch.search, patch.replace);
	  enforce(found == patch.occurs, format("%s - Failed. Patched %d/%d", patch.name, found, patch.occurs));
	  writefln("%s - Patched %u occurrences", patch.name, found);
	} else {
	  getData(file) = patch.fileReplace;
	  writefln("%s - Patched whole file", patch.name);
	}
      }
    }
  }
}