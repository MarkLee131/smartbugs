#!/bin/sh

FILENAME="$1"
TIMEOUT="$2"
BIN="$3"

export PATH="$BIN:$PATH"
chmod +x "$BIN/solc"

python contractlint.py -c "$FILENAME" -p DAO,TOD -o /"$FILENAME" -sc "$BIN/solc" -icc
