module Patch;

private {
  import std.conv : to;
  import Utils    : toStruct, fromStruct;
}

enum PatchTokenType {
  OpenCurly,
  CloseCurly,
  OpenSquare,
  CloseSquare,
  Equals,
  Comma,
  String,
  Keyword
}

struct PatchToken {
  PatchTokenType type;
  string str;
  this(PatchTokenType type, string str = "") {
    this.type = type;
    this.str = str;
  }
}

struct Patch {
  string name;
  string file;
  ubyte[] search;
  ubyte[] replace;

  ubyte[] toBinary() {
    ubyte[] data;
    uint len = cast(uint)name.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= fromStruct(name.ptr, name.length);

    len = cast(uint)file.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= fromStruct(file.ptr, file.length);

    len = cast(uint)search.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= search;

    len = cast(uint)replace.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= replace;

    return data;
  }

  static Patch[] fromBinary(ubyte[] data) {
    Patch patch;
    uint len;
    size_t offset = 0;
    char[] name, file;

    if(data.length == 0)
      return [];

    toStruct(data[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    name.length = len;
    toStruct(data[offset..$], name.ptr, len);
    offset += len;
    patch.name = to!string(name);

    toStruct(data[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    file.length = len;
    toStruct(data[offset..$], file.ptr, len);
    offset += len;
    patch.file = to!string(file);

    toStruct(data[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    patch.search.length = len;
    toStruct(data[offset..$], patch.search.ptr, len);
    offset += len;

    toStruct(data[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    patch.replace.length = len;
    toStruct(data[offset..$], patch.replace.ptr, len);
    offset += len;

    return patch ~ fromBinary(data[offset..$]);
  }
}