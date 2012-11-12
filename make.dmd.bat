@echo off

echo Initialising and updating submodules
git submodule update --init --quiet

echo Building debug tiano objects
dmc -g -c PMPatch/Tiano/TianoDecompress.c -oTianoDecompress.debug.obj
dmc -g -c PMPatch/Tiano/TianoCompress.c -oTianoCompress.debug.obj

echo Building release tiano objects
dmc -o -c PMPatch/Tiano/TianoDecompress.c -oTianoDecompress.release.obj
dmc -o -c PMPatch/Tiano/TianoCompress.c -oTianoCompress.release.obj

echo Building patch generator manifest
windres --input=patchgen.rc --input-format=rc --output=patchgen.res -F pe-i386 --output-format=res
echo Building debug patch generator
dmd -debug -gc -property -w patchgen.d Patch.d PatchLexer.d PatchParser.d EFIHeaders.d Utils.d patchgen.res -ofpatchgen.debug.exe
echo Building release patch generator
dmd -release -property -w -O patchgen.d Patch.d PatchLexer.d PatchParser.d EFIHeaders.d Utils.d patchgen.res -ofpatchgen.release.exe
strip patchgen.release.exe > NUL 2>NUL

echo Building patcher manifest
windres --input=patcher.rc --input-format=rc --output=patcher.res -F pe-i386 --output-format=res
echo Building debug patcher
dmd -debug -gc -property -w patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.obj Patch.d TianoCompress.debug.obj patcher.res -ofpatcher.debug.exe
echo Building release patcher
dmd -release -property -w -O patcher.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.obj TianoCompress.release.obj patcher.res -ofpatcher.release.exe
strip patcher.release.exe > NUL 2>NUL

echo Building extractor manifest
windres --input=extractor.rc --input-format=rc --output=extractor.res -F pe-i386 --output-format=res
echo Building debug extractor
dmd -debug -gc -property -w extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.obj Patch.d TianoCompress.debug.obj extractor.res -ofextractor.debug.exe
echo Building release extractor
dmd -release -property -w -O extractor.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.obj TianoCompress.release.obj extractor.res -ofextractor.release.exe
strip extractor.release.exe > NUL 2>NUL

echo Building injector manifest
windres --input=injector.rc --input-format=rc --output=injector.res -F pe-i386 --output-format=res
echo Building debug injector
dmd -debug -gc -property -w injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.obj Patch.d TianoCompress.debug.obj injector.res -ofinjector.debug.exe
echo Building release injector
dmd -release -property -w -O injector.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.obj TianoCompress.release.obj injector.res -ofinjector.release.exe
strip injector.release.exe > NUL 2>NUL

echo Building info executable manifest
windres --input=info.rc --input-format=rc --output=info.res -F pe-i386 --output-format=res
echo Building debug info executable
dmd -debug -gc -property -w info.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d TianoDecompress.debug.obj Patch.d TianoCompress.debug.obj info.res -ofinfo.debug
echo Building release info executable
dmd -release -property -w -O info.d EFI.d EFIHeaders.d EFIUtils.d Console.d Utils.d Patch.d TianoDecompress.release.obj TianoCompress.release.obj info.res -ofinfo.release.exe
strip info.release.exe > NUL 2>NUL