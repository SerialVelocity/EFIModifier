@echo off

echo Initialising and updating submodules
git submodule update --init --quiet

echo Building debug tiano objects
gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.debug.o
gcc -g -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.debug.o

echo Building release tiano objects
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.release.o
gcc -O2 -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.release.o


echo Building patch generator manifest
windres --input=patchgen.rc --input-format=rc --output=patchgen.res --output-format=coff
echo Building debug patch generator
gdc -g -fdebug -o patchgen.debug.exe patchgen.d Utils.d Patch.d PatchLexer.d PatchParser.d patchgen.res
echo Building release patch generator
gdc -o patchgen.release.exe -O1 patchgen.d Utils.d Patch.d PatchLexer.d PatchParser.d patchgen.res
strip patchgen.release.exe

echo Building patcher manifest
windres --input=patcher.rc --input-format=rc --output=patcher.res --output-format=coff
echo Building debug patcher
gdc -g -fdebug -o patcher.debug.exe patcher.d EFI.d EFIHeaders.d Console.d Utils.d Patch.d TianoDecompress.debug.o TianoCompress.debug.o patcher.res
echo Building release patcher
gdc -o patcher.release.exe -O1 patcher.d EFI.d EFIHeaders.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o patcher.res
strip patcher.release.exe