#!/bin/zsh

#Simple function to allow the script to die
die () {
    echo >&2 "$@"
    exit 1
}

git submodule init
git submodule update

cd BaseTools
make all
[[ "$?" -eq 0 ]] || die "Unable to make the library"
cd ..

#Release
dmd -release -property -w -nofloat -noboundscheck main.d EFI.d Console.d Utils.d ../../../buildtools-BaseTools/Source/C/libs/libCommon.a -ofmain.release
[[ "$?" -eq 0 ]] || die "Unable to make release version"

#Debug
dmd -debug -gc -property -w main.d EFI.d Console.d Utils.d ../../../buildtools-BaseTools/Source/C/libs/libCommon.a -ofmain.debug
[[ "$?" -eq 0 ]] || die "Unable to make debug version"
