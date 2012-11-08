module PatchParser;

private {
  import std.conv   : to;
  import std.string : format;
  import Patch      : Patch, PatchToken, PatchTokenType;

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

  static Patch[] parse(PatchToken[] tokens) {
    return (new PatchParser(tokens)).parsePatches();
  }

private:
  this(PatchToken[] tokens) {
    this.tokens = tokens;
  }

  Patch[] parsePatches() {
    Patch[] patches;

    while(tokens.length > 0)
      patches ~= parsePatch();

    return patches;
  }

  Patch parsePatch() {
    Patch patch;

    crunch(PatchTokenType.OpenCurly, tokens);

    while(tokens[0].type != PatchTokenType.CloseCurly) {
      auto keyword = crunch(PatchTokenType.Keyword, tokens);
      crunch(PatchTokenType.Equals, tokens);

      switch(keyword.str) {
      case "Name":
	patch.name = crunch(PatchTokenType.String, tokens).str;
	break;
      case "File":
	patch.file = crunch(PatchTokenType.String, tokens).str;
	break;
      case "Search":
	patch.search = parseList();
	break;
      case "Replace":
	patch.replace = parseList();
	break;
      default:
	throw new Exception("Unknown header: " ~ keyword.str);
      }
    }

    crunch(PatchTokenType.CloseCurly, tokens);
    return patch;
  }

  ubyte[] parseList() {
    ubyte[] list;
    crunch(PatchTokenType.OpenSquare, tokens);
    while(tokens[0].type != PatchTokenType.CloseSquare) {
      auto str = crunch(PatchTokenType.Keyword, tokens).str;
      if(str.length <= 2 || str[0..2] != "0x")
	throw new Exception("Expected hex number beginning 0x, got " ~ str);
      list ~= to!ubyte(str[2..$], 16);

      if(tokens[0].type != PatchTokenType.Comma)
	break;
      crunch(PatchTokenType.Comma, tokens);
    }
    crunch(PatchTokenType.CloseSquare, tokens);
    return list;
  }
}