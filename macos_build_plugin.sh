#!/bin/bash
set -e
mkdir -p build
# sudo rm -r build
# mkdir -p build
cd build
echo Deleting CMake output files...
find . -iwholename '*cmake*' -maxdepth 1 -delete
echo Generating Unix makefiles...
/Applications/CMake.app/Contents/bin/cmake -G "Unix Makefiles" ..
#-DCMAKE_BUILD_TYPE=Release -DCMAKE_RULE_MESSAGES:BOOL=OFF -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON ..
#echo Building plugin...
#make
echo Installing plugin...
make install
echo All done!
