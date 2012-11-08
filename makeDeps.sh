#!/bin/zsh

#Simple function to allow the script to die
die () {
    echo >&2 "$@"
    exit 1
}

echo "Initialising and updating submodules"
git submodule update --init --quiet || die "Couldn't initialise/update submodules"

echo "Building SemiTwist"
cd SemiTwistDTools

sed -i "" "s/size_t filenameLength;/uint filenameLength;/g" "src/semitwist/util/io.d"
sed -i "" "s/filenameLength = file.length-1;/filenameLength = cast(uint)file.length-1;/g" "src/semitwist/util/io.d"

./buildAll > /dev/null || die "Couldn't build SemiTwist"
CWD=`pwd`/bin
cd ..

echo "Building Goldie"
cd Goldie

for file in **/*.d
  sed -i "" "s/UtfException/UTFException/g" "$file"

PATH="$CWD":$PATH semitwist-stbuild all -x-I../SemiTwistDTools/src > /dev/null
[[ "$?" -eq 0 ]] || die "Couldn't build Goldie"

CWD2=`pwd`/bin
cd ..

echo "Building debug tiano objects"
gcc -g -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.debug.o || die "Couldn't build debug decompression object"
gcc -g -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.debug.o || die "Couldn't build debug compression object"

echo "Building release tiano objects"
gcc -O2 -c PMPatch/Tiano/TianoDecompress.c -o TianoDecompress.release.o || die "Couldn't build release decompression object"
gcc -O2 -c PMPatch/Tiano/TianoCompress.c -o TianoCompress.release.o || die "Couldn't build release compression object"

echo "Building Patch library"
PATH="$CWD2":"$CWD":$PATH goldie-grmc patch.grm > /dev/null || die "Couldn't parse patch grammar"
PATH="$CWD2":"$CWD":$PATH goldie-staticlang patch.cgt --pack=patch || die "Couldn't convert compiled patch grammar to D"
