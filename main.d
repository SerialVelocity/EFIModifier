import Console : Console;
import EFI : EFI, EFIContainer, File, UserInterfaceSection;

import std.stdio : writefln, write;

int main(string[] args) {
  Console.Init(args);
  string file = Console.GetInput!string("Please enter a filename");

  auto containers = EFI.parse(file);
  debug printEFI(containers);
  printFileMapping(containers);

  return 0;
}

EFIContainer findName(EFIContainer[] containers) {
  foreach(c; containers) {
    if(c.name == "Section (UserInterface)")
      return c;
    if(c.name == "Section (GUIDDefined)" || c.name == "Section (Compressed)")
      return findName(c.containers);
  }
  return null;
}

void printFileMapping(EFIContainer[] containers) {
  foreach(container; containers) {
    if(container.name[0..5] == "File ") {
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