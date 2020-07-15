#!/usr/bin/env bash
set -euo pipefail # fail loud and early

PREFIX=$1
RELEASE=$2
(
    cd $PREFIX/$RELEASE
    ./configure --prefix=$PREFIX --enable-disassembler
    make -j4
    make install
)


