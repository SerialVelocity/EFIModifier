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
dmd -debug -gc -property -w patchgen.d Patch.d PatchLexer.d PatchParser.d EFIHeaders.d Utils.d -ofpatchgen.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release patch generator"
dmd -release -property -w -O patchgen.d Patch.d PatchLexer.d PatchParser.d EFIHeaders.d Utils.d -ofpatchgen.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
strip patchgen.release > /dev/null 2>/dev/null

echo "Building debug patcher"
dmd -debug -gc -property -w patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.o Patch.d TianoCompress.debug.o -ofpatcher.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release patcher"
dmd -release -property -w -O patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o -ofpatcher.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
strip patcher.release > /dev/null 2>/dev/null

echo "Building debug extractor"
dmd -debug -gc -property -w extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.o Patch.d TianoCompress.debug.o -ofextractor.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release extractor"
dmd -release -property -w -O extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o -ofextractor.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
strip extractor.release > /dev/null 2>/dev/null

echo "Building debug injector"
dmd -debug -gc -property -w injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.o Patch.d TianoCompress.debug.o -ofinjector.debug
[[ "$?" -eq 0 ]] || echo "Unable to make debug version"

echo "Building release injector"
dmd -release -property -w -O injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o -ofinjector.release
[[ "$?" -eq 0 ]] || echo "Unable to make release version"
strip injector.release > /dev/null 2>/dev/null
