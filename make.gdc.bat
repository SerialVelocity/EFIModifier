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
gdc -g -fdebug -o patchgen.debug.exe patchgen.d EFIHeaders.d Utils.d Patch.d PatchLexer.d PatchParser.d patchgen.res
echo Building release patch generator
gdc -o patchgen.release.exe -O1 patchgen.d EFIHeaders.d Utils.d Patch.d PatchLexer.d PatchParser.d patchgen.res
strip patchgen.release.exe

echo Building patcher manifest
windres --input=patcher.rc --input-format=rc --output=patcher.res --output-format=coff
echo Building debug patcher
gdc -g -fdebug -o patcher.debug.exe patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.debug.o TianoCompress.debug.o patcher.res
echo Building release patcher
gdc -o patcher.release.exe -O1 patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o patcher.res
strip patcher.release.exe

echo Building extractor manifest
windres --input=extractor.rc --input-format=rc --output=extractor.res --output-format=coff
echo Building debug extractor
gdc -g -fdebug -o extractor.debug.exe extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.debug.o TianoCompress.debug.o extractor.res
echo Building release extractor
gdc -o extractor.release.exe -O1 extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o extractor.res
strip extractor.release.exe

echo Building injector manifest
windres --input=injector.rc --input-format=rc --output=injector.res --output-format=coff
echo Building debug injector
gdc -g -fdebug -o injector.debug.exe injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.debug.o TianoCompress.debug.o injector.res
echo Building release injector
gdc -o injector.release.exe -O1 injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.o TianoCompress.release.o injector.res
strip injector.release.exe