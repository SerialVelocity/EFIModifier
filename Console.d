module Console;

private {
  import std.conv   : to;
  import std.stdio  : write, writeln, writefln, readln;
  import std.string : strip;

  Console console;
}

class Console {
  string[] args;
  this(string[] args, string help) {
    if(args == null || args.length <= 1 || args[1] == "-h" || args[1] == "--help" || args[1] == "/?") {
      this.args.length = 0;
      writeln(help);
    } else {
      this.args = args[1..$];
    }
  }

  static void Init(string[] args, string help) {
    console = new Console(args, help);
  }

  static T GetInput(T)(string question) {
    return console._GetInput!T(question);
  }

  static void opCall(string[int] options, void delegate()[int] cmds) {
    return console._opCall(options, cmds);
  }

  T _GetInput(T)(string question) {
    if(args.length > 0) {
      auto arg = args[0];
      args = args[1..$];
      return to!T(arg);
    }

    writefln("%s:", question);
    write("=> ");

    return to!T(readln().strip());
  }

  void _opCall(string[int] options, void delegate()[int] cmds) {
    assert(options.length == cmds.length);

    if(args.length > 0) {
      auto arg = to!int(args[0]);
      if(arg in cmds) {
	args = args[1..$];
	cmds[arg]();
	return;
      } else {
	writefln("Unknown option %d, reverting to user input", args[0]);
	args.length = 0;
      }
    }

    writeln("Please select an option:");

    foreach(i, option; options)
      writefln("%d. %s", i, option);

    write("\n=> ");

    int num = to!int(readln().strip());
    if(num in cmds) {
      cmds[num]();
    }
  }
}