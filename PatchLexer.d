module PatchLexer;

private {
  import std.ascii : isAlphaNum, isWhite;
  import Patch : PatchToken, PatchTokenType;
}

class PatchLexer {
  static PatchToken[] lex(ubyte[] input) {
    if(input.length == 0)
      return [];
    if(input[0] == '{')
      return PatchToken(PatchTokenType.OpenCurly) ~ lex(input[1..$]);
    if(input[0] == '}')
      return PatchToken(PatchTokenType.CloseCurly) ~ lex(input[1..$]);
    if(input[0] == '[')
      return PatchToken(PatchTokenType.OpenSquare) ~ lex(input[1..$]);
    if(input[0] == ']')
      return PatchToken(PatchTokenType.CloseSquare) ~ lex(input[1..$]);
    if(input[0] == '(')
      return PatchToken(PatchTokenType.OpenRound) ~ lex(input[1..$]);
    if(input[0] == ')')
      return PatchToken(PatchTokenType.CloseRound) ~ lex(input[1..$]);
    if(isWhite(input[0]))
      return lex(input[1..$]);
    if(input[0] == '=')
      return PatchToken(PatchTokenType.Equals) ~ lex(input[1..$]);
    if(input[0] == ',')
      return PatchToken(PatchTokenType.Comma) ~ lex(input[1..$]);
    if(input[0] == '@') {
      while(input.length > 0 && input[0] != '\r' && input[0] != '\n')
	input = input[1..$];
      return lex(input);
    }
    if(isAlphaNum(input[0])) {
      string str = "";
      while(input.length > 0 && isAlphaNum(input[0])) {
	str ~= input[0];
	input = input[1..$];
      }
      return PatchToken(PatchTokenType.Keyword, str) ~ lex(input);
    }
    if(input[0] == '"') {
      string str = "";
      input = input[1..$];
      if(input.length == 0)
	throw new Exception("Unexpected EOF, expected \"");
      while(input[0] != '"') {
	if(input[0] == '\\') {
	  if(input.length == 1)
	    throw new Exception("Unexpected EOF, expected character following \\");	  
	  switch(input[1]) {
	  case 'r':  str ~= '\r'; break;
	  case 'n':  str ~= '\n'; break;
	  case 't':  str ~= '\t'; break;
	  case '\"': str ~= '\"'; break;
	  default: throw new Exception("Unknown escape character: " ~ input[1]);
	  }
	  input = input[2..$];
	} else {
	  str ~= input[0];
	  input = input[1..$];
	}
	if(input.length == 0)
	  throw new Exception("Unexpected EOF, expected \"");
      }
      return PatchToken(PatchTokenType.String, str) ~ lex(input[1..$]);
    }
    throw new Exception("Unknown character: " ~ input[0]);
  }
}