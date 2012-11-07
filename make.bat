@echo off
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
gdc -o main.release.exe -O2 main.d EFI.d Console.d TianoDecompress.o

gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.o
gdc -g -o main.debug.exe main.d EFI.d Console.d TianoDecompress.o