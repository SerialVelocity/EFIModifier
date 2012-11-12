module Patch;

private {
  import std.conv      : to;
  import std.exception : enforce;
  import std.zlib      : crc32, compress, uncompress;
  import EFIHeaders    : EFIGUID;
  import Utils         : toStruct, fromStruct;
}

enum PatchTokenType {
  OpenRound,
  CloseRound,
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

const uint PatchCurrentVersion = 1;
struct PatchHeader {
  uint patchVersion;
  uint length;
  uint crc32;
}

struct Patch {
  PatchHeader header;
  string name;
  string file;
  EFIGUID guid;
  ubyte[] search;
  ubyte[] replace;
  ubyte[] fileReplace;
  int occurs;

  ubyte[] toBinary() {
    ubyte[] data;
    uint len = cast(uint)name.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= fromStruct(name.ptr, name.length);

    len = cast(uint)file.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= fromStruct(file.ptr, file.length);

    data ~= fromStruct(&guid, guid.sizeof);

    len = cast(uint)search.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= search;

    len = cast(uint)replace.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= replace;

    len = cast(uint)fileReplace.length;
    data ~= fromStruct(&len, len.sizeof);
    data ~= fileReplace;

    data ~= fromStruct(&occurs, occurs.sizeof);

    data                = cast(ubyte[])compress(data);
    header.patchVersion = PatchCurrentVersion;
    header.length       = cast(uint)data.length;
    header.crc32        = crc32(0, data);

    return fromStruct(&header, header.sizeof) ~ data;
  }

  static Patch[] fromBinary(ubyte[] data) {
    Patch patch;
    uint len;
    char[] name, file;

    if(data.length == 0)
      return [];

    toStruct(data[0..$], &patch.header, header.sizeof);
    enforce(patch.header.patchVersion == PatchCurrentVersion, "Unknown patch version, please update the patch and program");
    enforce(header.sizeof + patch.header.length <= data.length, "Malformed patch");
    enforce(crc32(0, data[header.sizeof..header.sizeof + patch.header.length]) == patch.header.crc32, "Corrupted patch");

    ubyte[] patchdata = cast(ubyte[])uncompress(data[header.sizeof..header.sizeof + patch.header.length]);
    size_t offset = 0;

    toStruct(patchdata[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    name.length = len;
    toStruct(patchdata[offset..$], name.ptr, len);
    offset += len;
    patch.name = to!string(name);

    toStruct(patchdata[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    file.length = len;
    toStruct(patchdata[offset..$], file.ptr, len);
    offset += len;
    patch.file = to!string(file);

    toStruct(patchdata[offset..$], &patch.guid, guid.sizeof);
    offset += guid.sizeof;

    toStruct(patchdata[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    patch.search.length = len;
    toStruct(patchdata[offset..$], patch.search.ptr, len);
    offset += len;

    toStruct(patchdata[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    patch.replace.length = len;
    toStruct(patchdata[offset..$], patch.replace.ptr, len);
    offset += len;

    toStruct(patchdata[offset..$], &len, len.sizeof);
    offset += len.sizeof;
    patch.fileReplace.length = len;
    toStruct(patchdata[offset..$], patch.fileReplace.ptr, len);
    offset += len;

    toStruct(patchdata[offset..$], &patch.occurs, occurs.sizeof);
    offset += occurs.sizeof;

    return patch ~ fromBinary(data[header.sizeof + patch.header.length..$]);
  }
}