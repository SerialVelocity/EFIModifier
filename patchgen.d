import goldie.all;
import patch.all;

import std.conv : to, parse;
import std.file : write;
import std.stdio : writeln, writefln;
import Utils : fromStruct;

struct Patch {
  string name;
  string file;
  ubyte[] search;
  ubyte[] replace;
}

int main(string[] args) {
  try {
    auto parseTree = language_patch.parseFile(args[1]).parseTree;
    auto patches   = toPatches(parseTree);
    write(args[1] ~ ".bin", fromStruct(patches.ptr, patches.length * Patch.sizeof));
  } catch(ParseException e) {
    writeln(e.msg);
    return 1;
  }

  return 0;
}

alias Token_patch Tok;
Patch[] toPatches(Tok!"<ListOfPatches>" root) {
  Patch[] patches;
  foreach(tok; traverse(root)) {
    if(cast(Tok!"<Patch>")tok) {
      Patch patch;
      foreach(tok2; traverse(tok)) {
	if(cast(Tok!"<Header>")tok2) {
	  auto name = to!string(tok2.get!(Tok!"NString")(0));
	  auto str  = to!string(tok2.get!(Tok!"String")(0));
	  auto _arr  = tok2.get!(Tok!"<ListHex>")(0);
	  ubyte[] arr;
	  if(_arr !is null) {
	    foreach(tok3; traverse(_arr)) {
	      if(auto _elem = cast(Tok!"HexByte")tok3) {
		auto elem = to!string(_elem);
		arr ~= parse!ubyte(elem[2..$], 16);
	      }
	    }
	  }

	  switch(name) {
	  case "Name":
	    patch.name = str[1..$-1];
	    break;
	  case "File":
	    patch.file = str[1..$-1];
	    break;
	  case "Search":
	    patch.search = arr;
	    break;
	  case "Replace":
	    patch.replace = arr;
	    break;
	  default:
	    writefln("Unknown tag in patch");
	    return null;
	  }
	}
      }
      patches ~= patch;
    }
  }
  return patches;
}