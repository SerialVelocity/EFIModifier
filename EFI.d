module EFI;

private {
  import std.file : read;
  import std.stream : MemoryStream;
  import std.exception : enforce;
  import std.bitmanip : bitfields;
  import std.algorithm : reduce;
  import std.conv : to;
  import std.string : format;
  import std.stdio : stderr;

  EFIGUID ZeroGUID     = EFIGUID(0x00000000, 0x0000, 0x0000, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  EFIGUID PadGUID      = EFIGUID(0xFFFFFFFF, 0xFFFF, 0xFFFF, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
  EFIGUID CapsuleGUID  = EFIGUID(0x3B6686BD, 0x0D76, 0x4030, [0xB7, 0x0E, 0xB5, 0x51, 0x9E, 0x2F, 0xC5, 0xA0]);
  EFIGUID VolumeGUID   = EFIGUID(0x7A9354D9, 0x0468, 0x444A, [0x81, 0xCE, 0x0B, 0xF6, 0x17, 0xD8, 0x90, 0xDF]);
  EFIGUID NVVolumeGUID = EFIGUID(0xFFF12B8D, 0x7696, 0x4C8B, [0xA9, 0x85, 0x27, 0x47, 0x07, 0x5B, 0x4F, 0x50]);

  uint sectionAlignment = 4;
  uint fileAlignment    = 8;
}

class EFI {
  static EFIContainer[] parse(string filename) {
    return parse(cast(ubyte[])read(filename));
  }

  static EFIContainer[] parse(ubyte[] data, size_t offset = 0, bool parseSection = false, EFIContainer[] containers = []) {
    if(data.length == 0)
      return containers;

    enforce(data.length >= EFIGUID.sizeof || parseSection);

    EFIGUID guid;
    if(data.length >= EFIGUID.sizeof)
      guid = EFIGUID(data[0..EFIGUID.sizeof]);
    else
      guid = EFIGUID(0, 1, 2, [3, 4, 5, 6, 7, 8, 9, 10]);

    try {
    if(guid == ZeroGUID) {
      auto guid2 = EFIGUID(data[16..32]);
      if(guid2 != VolumeGUID && guid2 != NVVolumeGUID)
	stderr.writefln("WARNING: Unknown type 2: %s", guid2);
      containers ~= Volume.parse(data, offset);
      size_t len = containers[$-1].length();
      return EFI.parse(data[len..$], offset + len, parseSection, containers);
    } else if(guid == CapsuleGUID) {
      containers ~= Capsule.parse(data, offset);
      size_t len = containers[$-1].length();
      return EFI.parse(data[len..$], offset + len, parseSection, containers);
    } else if(guid == PadGUID) {
      containers ~= Padding.parse(data, offset);
      size_t len = containers[$-1].length();
      return EFI.parse(data[len..$], offset + len, parseSection, containers);
    } else {
      //Either file or section (so far)
      uint alignment = 0;
      if(parseSection) {
	containers ~= Section.parse(data, offset);
	alignment = sectionAlignment;
      } else {
	containers ~= File.parse(data, offset);
	alignment = fileAlignment;
      }
      size_t len = containers[$-1].length();
      if(len % alignment != 0 && data.length != len) {
	size_t needed = alignment - len % alignment;
	enforce(data.length >= len + needed);
	containers[$-1].padding = data[len..len + needed];
	//foreach(ref b; data[len..len + needed])
	//  enforce(b == 0x00);
	len += needed;
      }
      return EFI.parse(data[len..$], offset + len, parseSection, containers);
    }
    } catch(Exception e) {
      stderr.writefln("%s (Line: %u)", e.msg, e.line);
      //stderr.writefln("%s", e);
      containers ~= Unknown.parse(data, offset);
      return containers;
    }
  }
}

abstract class EFIContainer {
  EFIContainer[] containers;
  ubyte[] padding;
  size_t offset;

  static EFIContainer parse(ubyte[] data, size_t offset = 0);
  @property size_t length();
  @property string name();
}

struct CapsuleHeader {
  struct {
    EFIGUID guid;
    uint    headerSize;
    uint    flags;
    uint    imageSize;
    uint    seqNum;
    EFIGUID instanceID;
    uint    offsetToSplitInfo;
    uint    offsetToCapsuleBody;
    uint    offsetToOemHeader;
    uint    offsetToAuthorInfo;
    uint    offsetToRevInfo;
    uint    offsetToShortDesc;
    uint    offsetToLongDesc;
    uint    offsetToApplicableDevices;
  }
}

class Capsule : EFIContainer {
  CapsuleHeader header;

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto capsule = new Capsule();
    capsule.offset = offset;
    capsule.header = *cast(CapsuleHeader*)(data[0..header.sizeof].ptr);

    enforce(capsule.header.guid == CapsuleGUID);
    enforce(capsule.header.headerSize == header.sizeof);
    enforce(capsule.header.imageSize == data.length);

    capsule.containers = EFI.parse(data[header.sizeof..$], offset + header.sizeof);
    return capsule;
  }

  @property override
  string name() {
    return "Capsule";
  }

  @property override
  size_t length() {
    return header.imageSize;
  }
}

class Padding : EFIContainer {
  size_t len;

  static auto parse(ubyte[] data, size_t offset = 0) {
    auto padding = new Padding();
    padding.offset = offset;

    padding.len = data.length;
    foreach(i; 0..data.length) {
      if(data[i] != 0xFF) {
	padding.len = i;
	break;
      }
    }

    return padding;
  }

  @property override
  string name() {
    return "Padding";
  }

  @property override
  size_t length() {
    return len;
  }
}

class Unknown : EFIContainer {
  ubyte[] data;

  static auto parse(ubyte[] data, size_t offset = 0) {
    auto unknown = new Unknown();
    unknown.offset = offset;
    unknown.data = data;
    return unknown;
  }

  @property override
  string name() {
    return "Unknown";
  }

  @property override
  size_t length() {
    return data.length;
  }
}

struct VolumeHeader {
  EFIGUID  zeroes;
  EFIGUID  guid;
  ulong    volumeSize;
  char[4]  signature;
  uint     attribs;
  ushort   headerSize;
  ushort   checksum;
  ubyte[3] reserved;
  ubyte    revision;
}

struct Block {
  int numBlocks;
  int blockLength;

  bool isTerminator() {
    return numBlocks == 0 && blockLength == 0;
  }
}

class Volume : EFIContainer {
  VolumeHeader header;
  Block[] blocks;
  ubyte[] data;

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto volume = new Volume();
    volume.offset = offset;
    volume.header = *cast(VolumeHeader*)(data[0..header.sizeof].ptr);

    enforce(volume.header.zeroes     == ZeroGUID);
    //enforce(volume.header.guid       == VolumeGUID
    //     || volume.header.guid       == NVVolumeGUID);
    enforce(volume.header.signature  == ['_', 'F', 'V', 'H']);

    size_t pos = header.sizeof;
    do {
      enforce(data.length - pos >= Block.sizeof);
      volume.blocks ~= *cast(Block*)(data[pos..pos + Block.sizeof].ptr);
      pos += Block.sizeof;
    } while(!volume.blocks[$-1].isTerminator());

    volume.data = data[pos..cast(size_t)volume.header.volumeSize];

    if(volume.header.guid != VolumeGUID)
      return volume;

    enforce(volume.header.headerSize == pos);

    volume.containers = EFI.parse(volume.data, offset + pos);
    enforce(reduce!((x, y) => x + y.length() + y.padding.length)(cast(size_t)0, volume.containers)
            == volume.header.volumeSize - pos);
    return volume;
  }

  @property override
  string name() {
    return "Volume(" ~ to!string(header.guid) ~ ")";
  }

  @property override
  size_t length() {
    return cast(size_t)header.volumeSize;
  }
}

enum FileType : ubyte {
  Raw                 = 0x01,
  Freeform            = 0x02,
  SecurityCore        = 0x03,
  PeiCore             = 0x04,
  PxeCore             = 0x05,
  PeiM                = 0x06,
  Driver              = 0x07,
  CombinedPeiMDriver  = 0x08,
  Application	      = 0x09,
  FirmwareVolumeImage = 0x0B,
  FfsPad	      = 0xF0,
}

struct FileHeader {
  EFIGUID guid;
  ushort  checksum;
  FileType type;
  ubyte attribs;
  mixin(bitfields!(uint,  "fileSize" , 24,
		   ubyte, "state", 8));
}

class File : EFIContainer {
  FileHeader header;
  ubyte[] data;

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto file = new File();
    file.offset = offset;
    file.header = *cast(FileHeader*)(data[0..header.sizeof].ptr);

    enforce(file.header.guid != CapsuleGUID);
    enforce(file.header.guid != VolumeGUID);
    enforce(file.header.guid != ZeroGUID);
    enforce(file.header.fileSize <= data.length);

    file.data = data[header.sizeof..file.header.fileSize];

    switch(file.header.type) {
    case FileType.FirmwareVolumeImage:
    case FileType.Driver:
    case FileType.PxeCore:
    case FileType.PeiM:
    case FileType.Raw:
      file.containers = EFI.parse(file.data, offset + header.sizeof, 1);
      break;
    default:
      break;
    }

    return file;
  }

  @property override
  string name() {
    return format("File (%s)", to!string(header.type));
  }

  @property override
  size_t length() {
    return header.fileSize;
  }
}

enum SectionType : ubyte {
  All                 = 0,
  Compressed          = 1,
  GUIDDefined         = 2,
  PE32                = 0x10,
  PIC                 = 0x11,
  TE                  = 0x12,
  DxeDepex            = 0x13,
  Version             = 0x14,
  UserInterface       = 0x15,
  Compatibility16     = 0x16,
  FirmwareVolumeImage = 0x17,
  FreeformSubtypeGUID = 0x18,
  Raw                 = 0x19,
  PeiDepex            = 0x1B
}

struct SectionHeader {
  mixin(bitfields!(uint,        "fileSize" , 24,
		   SectionType, "type",      8));
}

enum CompressionType : ubyte{
  None     = 0x00,
  Standard = 0x01
}

align(1)
struct CompressedSectionHeader {
  uint uncompressedLength;
  CompressionType type;
}

extern(C) int EfiDecompress(void *src, uint srcSize, void *dst, uint dstSize, void *scratch, uint scratchSize);
extern(C) int TianoDecompress(void *src, uint srcSize, void *dst, uint dstSize, void *scratch, uint scratchSize);

class CompressedSection : Section {
  CompressedSectionHeader header2;
  ubyte[] uncompressed;

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    uint dataStart = header.sizeof + header2.sizeof;
    CompressedSection section = new CompressedSection();
    section.offset = offset;

    section.header = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    section.header2 = *cast(CompressedSectionHeader*)(data[header.sizeof..dataStart].ptr);
    enforce(section.header.fileSize <= data.length);

    switch(section.header2.type) {
    case CompressionType.Standard:
      section.uncompressed = new ubyte[section.header2.uncompressedLength];
      ubyte[] scratch = new ubyte[section.header2.uncompressedLength];

      enforce(TianoDecompress(data[dataStart..section.header.fileSize].ptr, section.header.fileSize - dataStart, section.uncompressed.ptr, section.header2.uncompressedLength, scratch.ptr, section.header2.uncompressedLength) == 0);
      break;
    case CompressionType.None:
      section.uncompressed = data[dataStart..section.header.fileSize];
      break;
    default:
      throw new Exception("Unknown compression!");
    }

    section.containers ~= EFI.parse(section.uncompressed, 0, 1);
    return section;
  }
}

struct ExtendedSectionHeader {
  EFIGUID guid;
  ushort offset;
  ushort attribs;
  uint crc32;
}

class ExtendedSection : Section {
  ExtendedSectionHeader header2;

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    uint dataStart = header.sizeof + header2.sizeof;
    ExtendedSection section = new ExtendedSection();
    section.offset = offset;

    section.header = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    section.header2 = *cast(ExtendedSectionHeader*)(data[header.sizeof..dataStart].ptr);
    enforce(section.header.fileSize <= data.length);

    section.containers = EFI.parse(data[section.header2.offset..section.header.fileSize], offset + dataStart, 1);
    return section;
  }
}

class RawSection : Section {
  ubyte[] data;

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    RawSection section = new RawSection();
    section.offset = offset;
    section.header = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    section.data   = data[header.sizeof..section.header.fileSize];
    return section;
  }
}

class UserInterfaceSection : Section {
  string fileName;
  ubyte[] data;

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    UserInterfaceSection section = new UserInterfaceSection();
    section.offset   = offset;
    section.header   = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    section.data     = data[header.sizeof..section.header.fileSize];
    section.fileName = to!string(cast(char[])(section.data));
    return section;
  }
}

class FVISection : Section {
  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    FVISection section = new FVISection();
    section.offset = offset;
    section.header = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    section.containers = EFI.parse(data[header.sizeof..section.header.fileSize], offset + header.sizeof);
    return section;
  }
}

abstract class Section : EFIContainer {
  SectionHeader header;

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto header = *cast(SectionHeader*)(data[0..header.sizeof].ptr);
    enforce(header.fileSize <= data.length);

    switch(header.type) {
    case SectionType.Compressed:
      return CompressedSection.parse(data, offset);
    case SectionType.FirmwareVolumeImage:
      return FVISection.parse(data, offset);
    case SectionType.GUIDDefined:
      return ExtendedSection.parse(data, offset);
    case SectionType.UserInterface:
      return UserInterfaceSection.parse(data, offset);
    default:
    case SectionType.DxeDepex:
    case SectionType.PeiDepex:
    case SectionType.PE32:
    case SectionType.Raw:
      return RawSection.parse(data, offset);
    }
  }

  @property override
  string name() {
    return format("Section (%s)", to!string(header.type));
  }

  @property override
  size_t length() {
    return header.fileSize;
  }
}

struct EFIGUID {
  uint     data1;
  ushort   data2;
  ushort   data3;
  ubyte[8] data4;

  this(uint data1, ushort data2, ushort data3, ubyte[8] data4) {
    this.data1 = data1;
    this.data2 = data2;
    this.data3 = data3;
    this.data4 = data4;
  }

  this(ubyte[] data) {
    enforce(data.length >= this.sizeof);
    auto stream = new MemoryStream(data);
    stream.read(data1);
    stream.read(data2);
    stream.read(data3);
    stream.readExact(&data4, data4.length);
  }

  string toString() {
    return format("%08X-%04X-%04X-%02X%02X%02X%02X%02X%02X%02X%02X", data1, data2, data3, data4[0], data4[1], data4[2], data4[3], data4[4], data4[5], data4[6], data4[7]);
  }
}