@echo off
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
gcc -O2 -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.o
gdc -o main.release.exe -O2 main.d EFI.d EFIHeaders.d Console.d Utils.d TianoDecompress.o TianoCompress.o
strip main.release.exe

gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
gcc -g -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.o
gdc -g -fdebug -o main.debug.exe main.d EFI.d EFIHeaders.d Console.d Utils.d TianoDecompress.o TianoCompress.o