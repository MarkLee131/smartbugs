#!/bin/sh

FILENAME="$1"
TIMEOUT="$2"
BIN="$3"

export PATH="$BIN:$PATH"
chmod +x "$BIN/solc"

slither "$FILENAME" --detect erc20-indexed,arbitrary-send-erc20,encode-packed-collision,suicidal,arbitrary-send-erc20-permit,unchecked-transfer,erc20-interface,locked-ether,unused-return,incorrect-modifier,missing-zero-check --json /output.json 
