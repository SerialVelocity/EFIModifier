import std.stream  : BufferedFile, FileMode;
import std.file    : read;
import PatchLexer  : PatchLexer;
import PatchParser : PatchParser;
import Patch       : Patch;

int main(string[] args) {
  Patch[] patches = PatchParser.parse(PatchLexer.lex(cast(ubyte[])read(args[1])), args[1]);
  BufferedFile file = new BufferedFile(args[1] ~ ".bin", FileMode.OutNew);

  foreach(patch; patches) {
    ubyte[] bin = patch.toBinary();
    file.writeExact(bin.ptr, bin.length);
  }

  file.close();
  return 0;
}