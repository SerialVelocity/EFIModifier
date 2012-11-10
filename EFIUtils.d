module EFIUtils;

private {
  import EFI;
  import std.stdio : write, writefln;
}

T calculateChecksum(T)(void *_ptr, ulong len, T start = 0) {
  len /= T.sizeof;
  T *ptr = cast(T*)_ptr;
  foreach(i; 0..len)
    start -= ptr[i];
  return start;
}

T find(T)(EFIContainer container) {
  foreach(ref c; container.containers) {
    if(typeid(c) == typeid(T))
      return cast(T)c;
    if(typeid(c) == typeid(ExtendedSection) || typeid(c) == typeid(CompressedSection)) {
      auto raw = find!T(c);
      if(raw !is null)
	return raw;
    }
  }
  return null;
}

T[] findAll(T)(EFIContainer container) {
  File[] found;
  foreach(ref c; container.containers) {
    if(typeid(container) == typeid(T))
      found ~= cast(T)container;
    found ~= findAll!T(c);
  }
  return found;
}

void printFileMapping(EFIContainer container) {
  foreach(ref file; findAll!File(container)) {
    auto name = find!UserInterfaceSection(file);
    if(name !is null)
      writefln("%s => %s", file.guid, name.fileName);
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