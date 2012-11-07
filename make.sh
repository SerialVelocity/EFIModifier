#!/bin/zsh

#Simple function to allow the script to die
die () {
    echo >&2 "$@"
    exit 1
}

git submodule init
git submodule update

#Release
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
dmd -release -property -w -nofloat -noboundscheck main.d EFI.d Console.d Utils.d TianoDecompress.o -ofmain.release
[[ "$?" -eq 0 ]] || die "Unable to make release version"

#Debug
gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
dmd -debug -gc -property -w main.d EFI.d Console.d Utils.d TianoDecompress.o -ofmain.debug
[[ "$?" -eq 0 ]] || die "Unable to make debug version"
