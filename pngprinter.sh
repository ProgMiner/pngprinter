#!/bin/bash

# Functions

# https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet
chr() {
    [ "$1" -lt 256 ] || return 1
    printf "\\$(printf '%03o' "$1")"
}

# Checks is bytes is a PNG image
#
# 1 - int[] - array of bytes
function PNG_check_sign() {
    sign='137 80 78 71 13 10 26 10'

    [[ "$(echo ${1:0:${#sign}})" == "$sign" ]] && return 1

    return 0
}

# Entry point

input="$( xxd -p -c 1 | nawk '
BEGIN {
    for (i = 0; i < 256; ++i) {
        hex2dec[sprintf("%02x", i)] = i
    }
}
{
    print hex2dec[$0]
}
')"

if PNG_check_sign "$input" ; then
    echo 'File is not PNG image!' >&2
    exit
fi


# input="${input:8}"