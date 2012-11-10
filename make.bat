@echo off

echo Initialising and updating submodules
git submodule update --init --quiet

echo Building debug tiano objects
gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.debug.o
gcc -g -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.debug.o

echo Building release tiano objects
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.release.o
gcc -O2 -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.release.o

echo Building debug patch generator
gdc -g -fdebug -o p_atchgen.debug.exe patchgen.d Utils.d Patch.d PatchLexer.d PatchParser.d
echo Building release patch generator
gdc -o p_atchgen.release.exe -O1 patchgen.d Utils.d Patch.d PatchLexer.d PatchParser.d
strip p_atchgen.release.exe

echo Building debug patcher
gdc -g -fdebug -o p_atcher.debug.exe patcher.d EFI.d EFIHeaders.d Console.d Utils.d Patch.d TianoDecompress.debug.o TianoCompress.debug.o

echo Building release patcher
gdc -o p_atcher.release.exe -O1 patcher.d EFI.d EFIHeaders.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o
strip p_atcher.release.exe