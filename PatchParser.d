module PatchParser;

private {
  import std.conv      : to;
  import std.exception : enforce;
  import std.file      : exists, read;
  import std.path      : dirName, buildPath;
  import std.string    : format;
  import EFIHeaders    : EFIGUID;
  import Patch         : Patch, PatchToken, PatchTokenType;

  auto crunch(PatchTokenType type, ref PatchToken[] tokens) {
    if(tokens[0].type != type)
      throw new Exception(format("Expected %s, got %s", to!string(type), to!string(tokens[0].type)));
    auto token = tokens[0];
    tokens = tokens[1..$];
    return token;
  }
}

class PatchParser {
  PatchToken[] tokens;
  string dir;

  static Patch[] parse(PatchToken[] tokens, string file) {
    return (new PatchParser(tokens, file)).parsePatches();
  }

private:
  this(PatchToken[] tokens, string file) {
    this.tokens = tokens;
    this.dir    = dirName(file);
  }

  Patch[] parsePatches() {
    Patch[] patches;

    while(tokens.length > 0)
      patches ~= parsePatch();

    return patches;
  }

  Patch parsePatch() {
    Patch patch;
    bool occurs, guid;

    crunch(PatchTokenType.OpenCurly, tokens);

    while(tokens[0].type != PatchTokenType.CloseCurly) {
      auto keyword = crunch(PatchTokenType.Keyword, tokens);
      crunch(PatchTokenType.Equals, tokens);

      switch(keyword.str) {
      case "Name":
	enforce(patch.name == null, "Already specified patch name");
	patch.name = crunch(PatchTokenType.String, tokens).str;
	break;
      case "File":
	enforce(patch.file is null, "Already specified file name");
	enforce(!guid, "Already specified file guid");
	if(tokens[0].type == PatchTokenType.String) {
	  patch.file = crunch(PatchTokenType.String, tokens).str;
	} else {
	  auto guidstart = crunch(PatchTokenType.Keyword, tokens).str;
	  enforce(guidstart == "EFIGUID", "Unknown file name type");
	  crunch(PatchTokenType.OpenRound, tokens);

	  auto v1 = parseHex!uint();
	  crunch(PatchTokenType.Comma, tokens);
	  auto v2 = parseHex!ushort();
	  crunch(PatchTokenType.Comma, tokens);
	  auto v3 = parseHex!ushort();
	  crunch(PatchTokenType.Comma, tokens);
	  auto _v4 = parseList!ubyte();
	  enforce(_v4.length == 8, "List of EFIGUID has to be length 8");
	  ubyte[8] v4;
	  v4[] = _v4;

	  patch.guid = EFIGUID(v1, v2, v3, v4);
	  guid = true;

	  crunch(PatchTokenType.CloseRound, tokens);
	}
	break;
      case "Search":
	enforce(patch.search is null, "Already specified search list");
	enforce(patch.fileReplace is null, "Already specified replacement file");
	patch.search = parseList!ubyte();
	break;
      case "Replace":
	enforce(patch.replace is null, "Already specified replace list");
	enforce(patch.fileReplace is null, "Already specified replacement file");
	patch.replace = parseList!ubyte();
	break;
      case "FileReplace":
	enforce(patch.search is null, "Already specified search list");
	enforce(patch.replace is null, "Already specified replace list");
	enforce(patch.fileReplace is null, "Already specified replacement file");
	enforce(!occurs, "Already specified amount of occurrences");

	auto filename = buildPath(dir, crunch(PatchTokenType.String, tokens).str);
	enforce(filename.exists(), format("File \"%s\" doesn't exist", filename));

	patch.fileReplace = cast(ubyte[])read(filename);
	break;
      case "Occurs":
	enforce(!occurs, "Already specified amount of occurrences");
	enforce(patch.fileReplace is null, "Already specified replacement file");
	occurs = true;
	patch.occurs = to!int(crunch(PatchTokenType.Keyword, tokens).str);
	break;
      default:
	throw new Exception("Unknown header: " ~ keyword.str);
      }
    }

    enforce(patch.name !is null, "Patch is missing a patch name");
    enforce(patch.file !is null || guid, "Patch is missing a file name/guid");
    if(patch.fileReplace is null) {
      enforce(patch.search !is null, "Patch is missing a search list");
      enforce(patch.replace !is null, "Patch is missing a replace list");
      enforce(occurs, "Patch is missing an amount of occurrences");
    }
    crunch(PatchTokenType.CloseCurly, tokens);
    return patch;
  }

  T parseHex(T)() {
    auto str = crunch(PatchTokenType.Keyword, tokens).str;
    if(str.length <= 2 || str[0..2] != "0x")
      throw new Exception("Expected hex number beginning 0x, got " ~ str);
    return to!T(str[2..$], 16);
  }

  T[] parseList(T)() {
    T[] list;
    crunch(PatchTokenType.OpenSquare, tokens);
    while(tokens[0].type != PatchTokenType.CloseSquare) {
      list ~= parseHex!T();

      if(tokens[0].type != PatchTokenType.Comma)
	break;
      crunch(PatchTokenType.Comma, tokens);
    }
    crunch(PatchTokenType.CloseSquare, tokens);
    return list;
  }
}