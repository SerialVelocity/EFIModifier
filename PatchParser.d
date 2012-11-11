module PatchParser;

private {
  import std.conv      : to;
  import std.exception : enforce;
  import std.string    : format;
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
    bool occurs;

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
	patch.file = crunch(PatchTokenType.String, tokens).str;
	break;
      case "Search":
	enforce(patch.search is null, "Already specified search list");
	patch.search = parseList();
	break;
      case "Replace":
	enforce(patch.replace is null, "Already specified replace list");
	patch.replace = parseList();
	break;
      case "Occurs":
	enforce(!occurs, "Already specified amount of occurrences");
	occurs = true;
	patch.occurs = to!int(crunch(PatchTokenType.Keyword, tokens).str);
	break;
      default:
	throw new Exception("Unknown header: " ~ keyword.str);
      }
    }

    enforce(patch.name !is null, "Patch is missing a patch name");
    enforce(patch.file !is null, "Patch is missing a file name");
    enforce(patch.search !is null, "Patch is missing a search list");
    enforce(patch.replace !is null, "Patch is missing a replace list");
    enforce(occurs, "Patch is missing an amount of occurrences");
    enforce(patch.search.length == patch.replace.length, "Search and replace lists must be the same size");
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