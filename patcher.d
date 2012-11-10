import Console : Console;
import Patch   : Patch;
import EFI     : EFI, EFIContainer, EFIGUID, File, RawSection, ExtendedSection, CompressedSection, UserInterfaceSection;

import std.stdio : writefln, write;
import std.file : read, filewrite = write;
import std.exception : enforce;
import std.string : format;

int main(string[] args) {
  Console.Init(args);
  string file = Console.GetInput!string("Please enter a filename");

  auto containers = EFI.parse(file);
  debug printEFI(containers);
  debug printFileMapping(containers);

  //Sanity check
  ubyte[] newEFI = EFI.getBinary(containers);
  ubyte[] oldEFI = cast(ubyte[])read(file);
  enforce(newEFI.length == oldEFI.length);
  debug enforce(newEFI == oldEFI);

  string outfile   = Console.GetInput!string("Please enter an output filename");
  string patchfile = Console.GetInput!string("Please enter a patch filename");
  Patch[] patches  = Patch.fromBinary(cast(ubyte[])read(patchfile));
  patch(containers, patches);
  ubyte[] modEFI = EFI.getBinary(containers);
  enforce(modEFI.length == oldEFI.length);
  filewrite(outfile, modEFI);

  return 0;
}

void patch(EFIContainer[] containers, Patch[] patches) {
  foreach(container; containers) {
    if(typeid(container) == typeid(File)) {
      auto name = findName(container.containers);
      auto raw  = findRaw(container.containers);

      if(name !is null) {
	auto filename = (cast(UserInterfaceSection)name).fileName;
	foreach(patch; patches) {
	  if(filename == patch.file) {
	    uint found = 0;
	    writefln("%s - Patching %s...", patch.name, filename);
	    foreach(i; 0..raw.data.length - patch.search.length) {
	      if(raw.data[i..i + patch.search.length] == patch.search) {
		++found;
		raw.data[i..i + patch.search.length] = patch.replace;
	      }
	    }
	    if(found)
	      writefln("%s - Done", patch.name);
	    else
	      writefln("%s - Failed", patch.name);
	  }
	}
      }
    }
    patch(container.containers, patches);
  }
}

RawSection findRaw(EFIContainer[] containers) {
  foreach(c; containers) {
    if(typeid(c) == typeid(RawSection))
      return cast(RawSection)c;
    return findRaw(c.containers);
  }
  return null;
}

void modCheck(EFIContainer[] containers) {
  foreach(c; containers) {
    if(c.guid == EFIGUID(0xF7731B4C, 0x58A2, 0x4DF4, [0x89, 0x80, 0x56, 0x45, 0xD3, 0x9E, 0xCE, 0x58])) {
      RawSection raw = findRaw(c.containers);
      if(raw is null) {
	writefln("COULDN'T FIND RAW SECTION");
	return;
      }
      ubyte[] pattern =[0x75,0x08,0x0F,0xBA,0xE8,0x0F,0x89,0x44,0x24,0x30];
      foreach(i; 0..raw.data.length - pattern.length) {
	if(raw.data[i..i+pattern.length] == pattern)
	  raw.data[i..i+pattern.length] = [0xEB,0x08,0x0F,0xBA,0xE8,0x0F,0x89,0x44,0x24,0x30];
      }
    }
    if(c.guid == EFIGUID(0xCFEF94C4, 0x4167, 0x466A, [0x88, 0x93, 0x87, 0x79, 0x45, 0x9D, 0xFA, 0x86])) {
      RawSection raw = findRaw(c.containers);
      if(raw is null) {
	writefln("COULDN'T FIND RAW SECTION");
	return;
      }
      ubyte[] pattern = [0x00,0x14,0x42,0x00,0x65,0x00,0x6C,0x00,0x6F,0x00,0x77,0x00,0x20,0x00,0x69,0x00,
			 0x73,0x00,0x20,0x00,0x72,0x00,0x65,0x00,0x73,0x00,0x65,0x00,0x72,0x00,0x76,0x00,
			 0x65,0x00,0x64,0x00,0x20,0x00,0x66,0x00,0x6F,0x00,0x72,0x00,0x20,0x00,0x52,0x00,
			 0x44,0x00,0x2C,0x00,0x20,0x00,0x6E,0x00,0x6F,0x00,0x74,0x00,0x20,0x00,0x44,0x00,
			 0x45,0x00,0x4C,0x00,0x4C,0x00,0x4F,0x00,0x49,0x00,0x4C,0x00,0x20,0x00,0x72,0x00,
			 0x65,0x00,0x71,0x00,0x75,0x00,0x65,0x00,0x73,0x00,0x74,0x00,0x2E,0x00,0x00,0x00];
      foreach(i; 0..raw.data.length - pattern.length) {
	if(raw.data[i..i+pattern.length] == pattern)
	  raw.data[i..i+pattern.length] = [0x00,0x14,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,
					   0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,
					   0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,
					   0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,
					   0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,
					   0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x20,0x00,0x00,0x00];
      }
      foreach(i; 0..raw.data.length - 10) {
	if(raw.data[i..i+10] == [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x0A])
	  raw.data[i..i+10] = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x0A];
      }
    }
    modCheck(c.containers);
  }
}

EFIContainer findName(EFIContainer[] containers) {
  foreach(c; containers) {
    if(typeid(c) == typeid(UserInterfaceSection))
      return c;
    if(typeid(c) == typeid(ExtendedSection) || typeid(c) == typeid(CompressedSection))
      return findName(c.containers);
  }
  return null;
}

void printFileMapping(EFIContainer[] containers) {
  foreach(container; containers) {
    if(typeid(container) == typeid(File)) {
      auto name = findName(container.containers);
      if(name !is null)
	writefln("%s => %s", (cast(File)container).header.guid, (cast(UserInterfaceSection)name).fileName);
    }
    printFileMapping(container.containers);
  }
}

void printEFI(EFIContainer[] containers, ulong depth = 0) {
  foreach(c; containers)
    printEFI(c, depth + 1);
}

void printEFI(EFIContainer container, ulong depth = 0) {
  foreach(i; 0..depth)
    write("\t");
  writefln("%08X: %s (%u, 0x%08X)", container.offset, container.name(), container.length(), container.length());
  printEFI(container.containers, depth);
}