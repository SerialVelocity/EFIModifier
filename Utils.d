module Utils;

private import std.stdio : stderr;
private import std.algorithm : min;

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

void hexdump(ubyte[] data, ulong len = ulong.max) {
  hexdump(data.ptr, min(data.length * typeof(*data.ptr).sizeof, len));
}