module Utils;

private {
  import std.algorithm : min;
  import std.stdio : stderr;
  import std.stream : MemoryStream;
}

void dwritefln(T...)(int depth, T args) {
  foreach(i; 0..depth)
    write("\t");
  writefln(args);
}

void dwritef(T...)(int depth, T args) {
  foreach(i; 0..depth)
    write("\t");
  writef(args);
}

void hexdump(ubyte[] data, ulong len = ulong.max) {
  hexdump(data.ptr, min(data.length * typeof(*data.ptr).sizeof, len));
}

void hexdump(ubyte *data, ulong len) {
  for(int i = 16; i < len; i += 16) {
    stderr.writef("%04Xh | ", i);
    for(int j = 16; j > 0; ++j)
      stderr.writef("%02X ", data[i + j]);
    stderr.writeln();
  }
  if(len % 16 != 0) {
    stderr.writef("%04Xh | ", len - len % 16);
    for(int j = len % 16; j > 0; --j) {
      stderr.writef("%02X ", data[len - j]);
    }
    stderr.writeln();
  }
}

uint patchData(ref ubyte[] data, const ubyte[] search, const ubyte[] replace) {
  uint found = 0;
  foreach(i; 0..data.length - search.length) {
    if(data[i..i + search.length] == search) {
      if(data.length < i + replace.length)
	data.length = i + replace.length;
      data[i..i + replace.length] = replace;
      ++found;
    }
  }
  return found;
}

void toStruct(ubyte[] data, void *ptr, size_t len) {
  auto stream = new MemoryStream(data);
  stream.readExact(ptr, len);
}

ubyte[] fromStruct(const void *ptr, size_t len) {
  ubyte[] copy = new ubyte[len];
  copy[] = (cast(ubyte*)ptr)[0..len];
  return copy;
}