#!/bin/zsh

#Simple function to allow the script to die
die () {
    echo >&2 "$@"
    exit 1
}

echo "Initialising and updating submodules"
git submodule update --init --quiet || die "Couldn't initialise/update submodules"

echo "Building debug tiano objects"
gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.debug.o || die "Couldn't build debug decompression object"
gcc -g -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.debug.o || die "Couldn't build debug compression object"

echo "Building release tiano objects"
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.release.o || die "Couldn't build release decompression object"
gcc -O2 -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.release.o || die "Couldn't build release compression object"

echo "Building debug patch generator"
dmd -debug -gc -w patchgen.d Patch.d PatchLexer.d PatchParser.d Utils.d -ofpatchgen.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release patch generator"
dmd -release -w -nofloat -noboundscheck patchgen.d Patch.d PatchLexer.d PatchParser.d Utils.d -ofpatchgen.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"

echo "Building debug patcher"
dmd -debug -gc -property -w main.d EFI.d EFIHeaders.d Console.d Utils.d TianoDecompress.debug.o Patch.d TianoCompress.debug.o -ofmain.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release patcher"
dmd -release -property -w -nofloat -noboundscheck main.d EFI.d EFIHeaders.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o -ofmain.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
