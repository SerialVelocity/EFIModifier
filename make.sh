#!/bin/zsh

#Simple function to allow the script to die
die () {
    echo >&2 "$@"
    exit 1
}

#Debug patcher
rdmd -debug -gc -w -ofpatchgen.debug --build-only -ISemiTwistDTools/src -IGoldie/src patchgen.d
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

#Release patcher
rdmd -release -w -nofloat -noboundscheck -ofpatchgen.release --build-only -ISemiTwistDTools/src -IGoldie/src patchgen.d
[[ "$?" -eq 0 ]] || echo "Unable to make release version"

#Debug main
dmd -debug -gc -property -w main.d EFI.d EFIHeaders.d Console.d Utils.d TianoDecompress.debug.o TianoCompress.debug.o -ofmain.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

#Release
dmd -release -property -w -nofloat -noboundscheck main.d EFI.d EFIHeaders.d Console.d Utils.d TianoDecompress.debug.o TianoCompress.debug.o -ofmain.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
