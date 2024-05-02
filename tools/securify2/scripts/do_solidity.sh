#!/bin/sh


FILENAME="$1"
# full path of file (within docker container) to analyse, e.g. /sb/my_contract.sol

BIN="$2"
# directory with scripts and programs supplied from the outside, typically /sb/bin

export PATH="$BIN:$PATH"
chmod +x "$BIN/solc"

securify "$FILENAME"
