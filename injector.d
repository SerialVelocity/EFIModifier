import Console  : Console;
import EFI      : EFI, File, FileType, Unknown, UserInterfaceSection, RawSection;
import EFIUtils : find, findAll, printEFI, printFileMapping;

import std.stdio     : stderr;
import std.file      : read, write, mkdir, chdir, exists;
import std.exception : enforce;
import std.string    : format;

int main(string[] args) {
  Console.Init(args, format("USAGE: %s <ORIGINAL WPH>", args[0]));
  string filename = Console.GetInput!string("Please enter a filename");

  auto container = EFI.parseCapsule(filename);
  debug printEFI(container);
  debug printFileMapping(container);

  //Sanity check
  debug {
    ubyte[] newEFI = EFI.getBinary(container);
    ubyte[] oldEFI = cast(ubyte[])read(filename);
    enforce(newEFI.length == oldEFI.length);
    enforce(newEFI == oldEFI);
  }

  auto dumpdir = filename ~ " dump";
  enforce(dumpdir.exists());

  foreach(file; findAll!File(container)) {
    auto ui  = find!UserInterfaceSection(file);
    auto raw = find!RawSection(file);

    string name;
    if(ui is null)
      name = file.guid.toString() ~ ".bin";
    else
      name = ui.fileName;

    ubyte[] data;
    if(raw is null) {
      switch(file.header.type) {
      case FileType.Freeform:
      case FileType.Application:
	data = file.data;
	break;
      case FileType.Raw:
	//Workaround for bug
	//if(file.containers.length == 1 && typeid(file.containers[0]) == typeid(Unknown))
	if(file.containers.length == 1) {
	  foreach(c; file.containers)
	    if(typeid(c) == typeid(Unknown))
	      data = file.data;
	    else
	      goto default;
	}
	break;
      default:
	stderr.writefln("WARNING: %s has no raw data", name);
	printEFI(file);
	continue;
      }
    } else {
      data = raw.data;
    }

    name = dumpdir ~ "/" ~ name;
    enforce(exists(name));
    auto newData = cast(ubyte[])read(name);
    enforce(newData.length == data.length);
    data[] = newData;
  }

  auto modfile = filename ~ ".mod";
  if(modfile.exists()) {
    stderr.writefln("ERROR: \"%s\" exists already. To regenerate the file, delete it", modfile);
    return 1;
  }

  auto modEFI = EFI.getBinary(container);
  enforce(modEFI.length == read(filename).length);
  write(modfile, modEFI);

  return 0;
}