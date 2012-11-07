module EFIHeaders;

private {
  import std.bitmanip  : bitfields;
  import std.exception : enforce;
  import std.string    : format;
  import Utils         : toStruct;
}

struct CapsuleHeader {
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

struct FileHeader {
  EFIGUID guid;
  ushort  checksum;
  FileType type;
  ubyte attribs;
  mixin(bitfields!(uint,  "fileSize" , 24,
		   ubyte, "state", 8));
}


struct SectionHeader {
  mixin(bitfields!(uint,        "fileSize" , 24,
		   SectionType, "type",      8));
}

align(1)
struct CompressedSectionHeader {
  uint uncompressedLength;
  CompressionType type;
}

struct ExtendedSectionHeader {
  EFIGUID guid;
  ushort offset;
  ushort attribs;
  uint crc32;
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
    toStruct(data, &this, this.sizeof);
  }

  string toString() {
    return format("%08X-%04X-%04X-%02X%02X%02X%02X%02X%02X%02X%02X", data1, data2, data3, data4[0], data4[1], data4[2], data4[3], data4[4], data4[5], data4[6], data4[7]);
  }
}

struct Block {
  int numBlocks;
  int blockLength;

  bool isTerminator() {
    return numBlocks == 0 && blockLength == 0;
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

enum CompressionType : ubyte{
  None     = 0x00,
  Standard = 0x01
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