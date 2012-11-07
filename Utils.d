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
  int i = 0;
  for(i = 0; i < len; i += 16) {
    stderr.writef("%04Xh | ", i);
    for(int j = 0; j < 16; ++j)
      stderr.writef("%02X ", data[i + j]);
    stderr.writeln();
  }
  if(len % 16 != 0) {
    stderr.writef("%04Xh | ", i);
    for(int j = 0; j < len % 16; ++j) {
      stderr.writef("%02X ", data[i + j]);
    }
    stderr.writeln();
  }
}

void toStruct(ubyte[] data, void *ptr, size_t len) {
  auto stream = new MemoryStream(data);
  stream.readExact(ptr, len);
}

ubyte[] fromStruct(void *ptr, size_t len) {
  ubyte[] copy = new ubyte[len];
  copy[] = (cast(ubyte*)ptr)[0..len];
  return copy;
}

T calculateChecksum(T)(void *_ptr, ulong len, T start = 0) {
  len /= T.sizeof;
  T *ptr = cast(T*)_ptr;
  foreach(i; 0..len)
    start -= ptr[i];
  return start;
}