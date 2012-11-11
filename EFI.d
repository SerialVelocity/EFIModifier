module EFI;

private {
  import std.file      : read, write;
  import std.exception : enforce;
  import std.algorithm : reduce;
  import std.conv      : to;
  import std.string    : format;
  import std.stdio     : stderr;
  import std.zlib      : crc32;
  import Utils         : toStruct, fromStruct;
  import EFIUtils      : calculateChecksum;

  EFIGUID ZeroGUID     = EFIGUID(0x00000000, 0x0000, 0x0000, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  EFIGUID PadGUID      = EFIGUID(0xFFFFFFFF, 0xFFFF, 0xFFFF, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
  EFIGUID CapsuleGUID  = EFIGUID(0x3B6686BD, 0x0D76, 0x4030, [0xB7, 0x0E, 0xB5, 0x51, 0x9E, 0x2F, 0xC5, 0xA0]);
  EFIGUID VolumeGUID   = EFIGUID(0x7A9354D9, 0x0468, 0x444A, [0x81, 0xCE, 0x0B, 0xF6, 0x17, 0xD8, 0x90, 0xDF]);
  EFIGUID NVVolumeGUID = EFIGUID(0xFFF12B8D, 0x7696, 0x4C8B, [0xA9, 0x85, 0x27, 0x47, 0x07, 0x5B, 0x4F, 0x50]);

  const uint  sectionAlignment = 4;
  const ubyte sectionPadFill   = 0x00;
  const uint  fileAlignment    = 8;
  const ubyte filePadFill      = 0xFF;

  extern(C) int TianoDecompress(void *src, uint srcSize, void *dst, uint dstSize, void *scratch, uint scratchSize);
  extern(C) int TianoCompress(void *src, uint srcSize, void *dst, uint *dstSize);
}

public import EFIHeaders;

class EFI {
  static ubyte[] getBinary(EFIContainer container) {
    return container.getBinary();
  }

  static ubyte[] getBinary(EFIContainer[] containers) {
    ubyte[] data;

    foreach(ref container; containers[0..$-1])
      data ~= container.getBinary();

    if(typeid(containers[$-1]) != typeid(Padding))
      data ~= containers[$-1].getBinary();
    else
      data ~= (cast(Padding)containers[$-1]).getBinary(data.length);

    return data;
  }

  static EFIContainer parseCapsule(string filename) {
    auto containers = parse(filename);
    enforce(containers.length == 1 && typeid(containers[0]) == typeid(Capsule));
    return containers[0];
  }

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
      ubyte padFill  = 0;
      if(parseSection)
	containers ~= Section.parse(data, offset);
      else
	containers ~= File.parse(data, offset);
      size_t len = containers[$-1].length();
      return EFI.parse(data[len..$], offset + len, parseSection, containers);
    }
    } catch(Exception e) {
      stderr.writefln("WARNING: Exception caught (harmless): %s (Line: %u)", e.msg, e.line);
      //stderr.writefln("%s", e);
      containers ~= Unknown.parse(data, offset);
      return containers;
    }
  }
}

class Capsule : EFIContainer {
  CapsuleHeader header;

  override
  ubyte[] getBinary() {
    ubyte[] data = fromStruct(&header, header.sizeof);
    data        ~= EFI.getBinary(containers);
    enforce(data.length == header.imageSize);
    return data;
  }

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto capsule = new Capsule();
    capsule.offset = offset;
    toStruct(data, &capsule.header, header.sizeof);

    enforce(capsule.header.guid == CapsuleGUID);
    enforce(capsule.header.headerSize == header.sizeof);
    enforce(capsule.header.imageSize == data.length);

    capsule.containers = EFI.parse(data[header.sizeof..$], 0);
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

  @property override
  EFIGUID guid() {
    return header.guid;
  }
}

class Padding : EFIContainer {
  size_t len;

  override
  ubyte[] getBinary() {
    enforce(this.offset == 0);
    ubyte[] data = new ubyte[len];
    foreach(ref ch; data)
      ch = 0xFF;

    return data;
  }

  ubyte[] getBinary(size_t offset) {
    enforce(this.offset + len - offset >= 0);
    ubyte[] data = new ubyte[this.offset + len - offset];
    foreach(ref ch; data)
      ch = 0xFF;

    return data;
  }

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

  @property override
  EFIGUID guid() {
    return ZeroGUID;
  }
}

class Unknown : EFIContainer {
  ubyte[] data;

  override
  ubyte[] getBinary() {
    return data;
  }

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

  @property override
  EFIGUID guid() {
    return ZeroGUID;
  }
}

class Volume : EFIContainer {
  VolumeHeader header;
  Block[] blocks;
  ubyte[] data;

  override
  ubyte[] getBinary() {
    ubyte[] tail;
    if(header.guid != VolumeGUID) {
      tail = this.data;
    } else {
      tail = EFI.getBinary(containers);

      header.checksum = 0x0000;
      auto checksum  = calculateChecksum!ushort(&header, header.sizeof);
      foreach(block; blocks)
	checksum = calculateChecksum!ushort(&block, block.sizeof, checksum);
      header.checksum = checksum;
    }

    ubyte[] data = fromStruct(&header, header.sizeof);
    foreach(block; blocks)
      data ~= fromStruct(&block, block.sizeof);

    enforce(data.length + tail.length == header.volumeSize);

    return data ~ tail;
  }

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto volume = new Volume();
    volume.offset = offset;
    toStruct(data, &volume.header, header.sizeof);

    enforce(volume.header.zeroes     == ZeroGUID);
    //enforce(volume.header.guid       == VolumeGUID
    //     || volume.header.guid       == NVVolumeGUID);
    enforce(volume.header.signature  == ['_', 'F', 'V', 'H']);

    size_t pos = header.sizeof;
    do {
      enforce(data.length - pos >= Block.sizeof);
      volume.blocks ~= Block();
      toStruct(data[pos..pos + Block.sizeof], &volume.blocks[$-1], Block.sizeof);
      pos += Block.sizeof;
    } while(!volume.blocks[$-1].isTerminator());

    volume.data = data[pos..cast(size_t)volume.header.volumeSize];

    if(volume.header.guid != VolumeGUID)
      return volume;

    enforce(volume.header.headerSize == pos);

    volume.containers = EFI.parse(volume.data, 0);
    enforce(reduce!((x, y) => x + y.length())(cast(size_t)0, volume.containers)
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

  @property override
  EFIGUID guid() {
    return header.guid;
  }
}

class File : EFIContainer {
  FileHeader header;
  ubyte[] data;

  override
  ubyte[] getBinary() {
    ubyte[] tail;
    switch(header.type) {
    case FileType.FirmwareVolumeImage:
    case FileType.Driver:
    case FileType.PxeCore:
    case FileType.PeiM:
    case FileType.Raw:
      tail = EFI.getBinary(containers);
      break;
    default:
      tail = this.data;
      break;
    }

    auto state = header.state;
    header.state    = 0;
    header.fileSize = cast(uint)(header.sizeof + tail.length);
    header.checksum = 0;

    ubyte headCheck = calculateChecksum!ubyte(&header, header.sizeof);
    ubyte tailCheck = calculateChecksum!ubyte(tail.ptr, tail.length);

    header.checksum = (tailCheck << 8) | headCheck;
    header.state    = state;

    ubyte[] data = fromStruct(&header, header.sizeof) ~ tail;
    if(data.length % fileAlignment != 0) {
      ubyte[] padding = new ubyte[fileAlignment - data.length % fileAlignment];
      foreach(ref pad; padding)
	pad = filePadFill;
      data ~= padding;
    }
    return data;
  }

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    auto file = new File();
    file.offset = offset;
    toStruct(data, &file.header, header.sizeof);

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
      file.containers = EFI.parse(file.data, 0, 1);
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
    if(header.fileSize % fileAlignment == 0)
      return header.fileSize;
    else
      return header.fileSize + (fileAlignment - header.fileSize % fileAlignment);
  }

  @property override
  EFIGUID guid() {
    return header.guid;
  }
}

class CompressedSection : Section {
  CompressedSectionHeader header2;
  ubyte[] uncompressed;

  override
  ubyte[] getBinary() {
    ubyte[] uncompressedData = EFI.getBinary(containers);
    enforce(uncompressed.length == uncompressedData.length);
    uncompressed = uncompressedData;

    ubyte[] tail;
    switch(header2.type) {
    case CompressionType.Standard:
      uint len = cast(uint)uncompressed.length;
      header2.uncompressedLength = len;
      ubyte[] compressedData = new ubyte[len];
      enforce(TianoCompress(uncompressed.ptr, len, compressedData.ptr, &len) == 0);
      tail = compressedData[0..len];
      break;
    case CompressionType.None:
      header2.uncompressedLength = cast(uint)uncompressed.length;
      tail = uncompressed;
      break;
    default:
      throw new Exception("Unknown compression!");
    }

    header.fileSize = cast(uint)(header.sizeof + header2.sizeof + tail.length);

    ubyte[] data = fromStruct(&header, header.sizeof);
    data        ~= fromStruct(&header2, header2.sizeof);
    data        ~= tail;
    return data;
  }

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    uint dataStart = header.sizeof + header2.sizeof;
    CompressedSection section = new CompressedSection();
    section.offset = offset;

    toStruct(data, &section.header, header.sizeof);
    toStruct(data[header.sizeof..dataStart], &section.header2, header2.sizeof);
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

    section.containers = EFI.parse(section.uncompressed, 0, 1);
    return section;
  }
}

class ExtendedSection : Section {
  ExtendedSectionHeader header2;

  override
  ubyte[] getBinary() {
    ubyte[] tail = EFI.getBinary(containers);
    header2.crc32 = crc32(0, tail);
    header.fileSize = cast(uint)(header.sizeof + header2.sizeof + tail.length);

    ubyte[] data = fromStruct(&header, header.sizeof);
    data        ~= fromStruct(&header2, header2.sizeof);
    data        ~= tail;
    data        ~= getPadding();
    return data;
  }

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    uint dataStart = header.sizeof + header2.sizeof;
    ExtendedSection section = new ExtendedSection();
    section.offset = offset;

    toStruct(data, &section.header, header.sizeof);
    toStruct(data[header.sizeof..dataStart], &section.header2, header2.sizeof);
    enforce(section.header.fileSize <= data.length);

    section.containers = EFI.parse(data[section.header2.offset..section.header.fileSize], 0, 1);
    return section;
  }

  @property override
  EFIGUID guid() {
    return header2.guid;
  }
}

class RawSection : Section {
  ubyte[] data;

  override
  ubyte[] getBinary() {
    header.fileSize = cast(uint)(header.sizeof + data.length);
    return fromStruct(&header, header.sizeof) ~ data ~ getPadding();
  }

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    RawSection section = new RawSection();
    section.offset = offset;

    toStruct(data, &section.header, header.sizeof);
    section.data   = data[header.sizeof..section.header.fileSize];
    return section;
  }
}

class UserInterfaceSection : Section {
  string fileName;
  ubyte[] data;

  override
  ubyte[] getBinary() {
    header.fileSize = cast(uint)(header.sizeof + data.length);
    return fromStruct(&header, header.sizeof) ~ data ~ getPadding();
  }

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    UserInterfaceSection section = new UserInterfaceSection();
    section.offset   = offset;
    toStruct(data, &section.header, header.sizeof);
    section.data     = data[header.sizeof..section.header.fileSize];
    char[] fileName = cast(char[])(section.data);
    foreach(i, ch; fileName) {
      enforce(i % 2 == 0 || ch == '\0');
      if(i % 2 == 0) {
        if(ch == '\0')
          break;
        section.fileName ~= ch;
      }
    }
    return section;
  }
}

class FVISection : Section {
  override
  ubyte[] getBinary() {
    ubyte[] tail = EFI.getBinary(containers);
    header.fileSize = cast(uint)(header.sizeof + tail.length);
    ubyte[] data = fromStruct(&header, header.sizeof);
    return data ~ tail ~ getPadding();
  }

  static EFIContainer parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    FVISection section = new FVISection();
    section.offset = offset;
    toStruct(data, &section.header, header.sizeof);
    section.containers = EFI.parse(data[header.sizeof..section.header.fileSize], 0);
    return section;
  }
}

abstract class Section : EFIContainer {
  SectionHeader header;
  size_t datalen;

  static auto parse(ubyte[] data, size_t offset = 0) {
    enforce(data.length >= header.sizeof);

    SectionHeader header;
    toStruct(data, &header, header.sizeof);
    enforce(header.fileSize <= data.length);

    EFIContainer section;
    switch(header.type) {
    case SectionType.Compressed:
      section = CompressedSection.parse(data, offset);
      break;
    case SectionType.FirmwareVolumeImage:
      section = FVISection.parse(data, offset);
      break;
    case SectionType.GUIDDefined:
      section = ExtendedSection.parse(data, offset);
      break;
    case SectionType.UserInterface:
      section = UserInterfaceSection.parse(data, offset);
      break;
    default:
    case SectionType.DxeDepex:
    case SectionType.PeiDepex:
    case SectionType.PE32:
    case SectionType.Raw:
      section = RawSection.parse(data, offset);
      break;
    }

    size_t padded = header.fileSize + (sectionAlignment - header.fileSize % sectionAlignment);
    if(header.fileSize % sectionAlignment == 0 || padded > data.length)
      (cast(Section)section).datalen = header.fileSize;
    else
      (cast(Section)section).datalen = padded;

    return section;
  }

  @property override
  string name() {
    return format("Section (%s)", to!string(header.type));
  }

  @property override
  size_t length() {
    return datalen;
  }

  @property override
  EFIGUID guid() {
    return ZeroGUID;
  }

  private ubyte[] getPadding() {
    if(header.fileSize == length())
      return [];
    ubyte[] padding = new ubyte[length() - header.fileSize];
    foreach(ref pad; padding)
      pad = sectionPadFill;
    return padding;
  }
}