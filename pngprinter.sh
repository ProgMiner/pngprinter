#!/bin/bash

# Functions

## Utilities

# Prints char with specified ASCII code
#
# https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet
#
# 1 - int - char code
chr() {
    [ "$1" -lt 256 ] || return 1
    printf "\\$(printf '%03o' "$1")"
}

# Applies chr on array and prints
#
# @ - int[] - char codes
function chr_array() {
    local input=("$@")

    for c in "${input[@]}" ; do
        chr $c
    done
}

# Converts 4 bytes to unsigned integer and prints it
#
# @ - int[4] - array of bytes
function bytes2uint() {
    local input=("$@")

    local ret=0
    for ((i=0; $i < 4; ++i)) ; do
        ret=$(( $ret + (${input[$i]} << (8 * (3 - $i))) ))
    done

    echo $ret
}

# Checks is array contains a value
#
# 1   - Value
# @:2 - Array
function array_contains() {
    local input=("${@:2}")
    local value="$1"

    for elem in "${input[@]}" ; do
        [[ $value == $elem ]] && return 0
    done

    return 1
}

## PNG

# Checks is bytes is a PNG image
#
# @ - int[8] - array of bytes
function PNG_check_sign() {
    local sign=(137 80 78 71 13 10 26 10)
    local input=("$@")

    for ((i=0; $i < ${#sign[@]}; ++i)) ; do
        [[ ${input[$i]} -ne ${sign[$i]} ]] && return 1
    done

    return 0
}

# Reads chunk and pronts it in following format:
#   [0]  - chunk data length
#   [1]  - chunk type
#   [2-] - chunk data bytes
#
# @ - int[12] - array of bytes
function PNG_read_chunk() {
    local input=("$@")

    local length=$(bytes2uint "${input[@]}")

    if [[ $length -ge 4294967296 ]] ; then
        echo 'Bad chunk size' >&2
        exit
    fi

    local type=("${input[@]:4:4}")
    for b in $type ; do
        if (( ($b < 65 || $b > 90) && ($b < 97 || $b > 122) )) ; then
            echo 'Bad chunk type' >&2
            exit
        fi
    done

    input=("${input[@]:8}")
    local data=("${input[@]:0:$length}")

    # TODO CRC check

    echo "$length $(chr_array "${type[@]}") ${data[@]}"
}

# Prints bytes array without chunk
#
# Prints bytes array starting at
# specified chunk length + 12 bytes
#
# 1   - int   - chunk length
# @:2 - int[] - bytes array
function PNG_skip_chunk() {
    local input=("${@:2}")
    local length=$(( $1 + 12 ))

    echo "${input[@]:$length}"
}

# Prints formatted tIME content
#
# @ - int[] - bytes array
function PNG_format_time() {
    local input=("$@")

    local time=($(bytes2uint 0 0 "${input[@]}") "${input[@]:2}")
    printf '%02d-%02d-%02d %02d:%02d:%02d' "${time[@]}"
}

# Prints formatted tEXt content
#
# @ - int[] - bytes array
function PNG_format_text() {
    local input=("$@")

    local keyword=
    for c in "${input[@]}" ; do
        [[ $c -eq 0 ]] && break

        keyword="${keyword[@]}$(chr $c)"
    done

    local kw_length=${#keyword}
    if [[ $kw_length -gt 79 ]] ; then
        echo 'Bad tEXt chunk' >&2
    fi

    printf '%s: %s' "$keyword" "$(chr_array "${input[@]:$(( $kw_length + 1 ))}" | cat -vt)"
}

# Entry point

if ! type nawk &> /dev/null ; then
    # alias nawk=awk

    function nawk() {
        awk "$@"
    }
fi

input=($( xxd -p -c 1 | nawk '
BEGIN {
    for (i = 0; i < 256; ++i) {
        hex2dec[sprintf("%02x", i)] = i
    }
}

{
    print hex2dec[$0]
}
'))

if ! PNG_check_sign "${input[@]}" ; then
    echo 'File is not PNG image!' >&2
    exit
fi

input=("${input[@]:8}")

# Image array format:
#   - 0 - Width
#   - 1 - Height
#   - 2 - Bit depth
#   - 3 - Colour type
#   - 4 - Compression method
#   - 5 - Filter method
#   - 6 - Interlace method
header=()

# Array with readed chunks
chunks=()

while true ; do
    if [[ ${#input[@]} -eq 0 ]] ; then
        echo 'Missing IEND chunk' >&2
        exit
    fi

    chunk=($(PNG_read_chunk "${input[@]}"))

    if [[ ${#chunks[@]} -eq 0 ]] && [[ ${chunk[1]} != 'IHDR' ]] ; then
        echo 'Missing IHDR chunk' >&2
        exit
    fi

    case "${chunk[1]}" in

    # Critical chunks
    'IHDR' )
        if [[ ${chunk[0]} -ne 13 ]] ; then
            echo 'Bad IHDR chunk' >&2
            exit
        fi

        header=($(bytes2uint ${chunk[@]:2}) $(bytes2uint ${chunk[@]:6}) "${chunk[@]:10}")

        printf 'Image size: %dx%dpx
Bit depth: %d
Colour type: %d
Compression method: %d
Filter method: %d
Interlace method: %d\n' "${header[@]}"
        ;;
    'PLTE' )
        ;;
    'IDAT' )
        ;;
    'IEND' )
        if [[ ${chunk[0]} -ne 0 ]] ; then
            echo 'Bad IEND chunk' >&2
            exit
        fi

        break
        ;;

    # Ancillary chunks
    'cHRM' )
        ;;
    'gAMA' )
        ;;
    'iCCP' )
        ;;
    'sBIT' )
        ;;
    'sRGB' )
        ;;
    'bKGD' )
        ;;
    'hIST' )
        ;;
    'tRNS' )
        ;;
    'pHYs' )
        ;;
    'sPLT' )
        ;;
    'tIME' )
        if array_contains 'tIME' "${chunks[@]}" ; then
            echo 'tIME chunks cannot be more than one' >&2
            exit
        fi

        echo 'Image last edit time:' "$(PNG_format_time ${chunk[@]:2})"
        ;;
    'iTXt' )
        # TODO
        ;;
    'tEXt' )
        echo "$(PNG_format_text ${chunk[@]:2})"
        ;;
    'zTXt' )
        # TODO
        ;;
    esac

    printf 'Chunk %s length %d: ' ${chunk[1]} ${chunk[0]}
    echo "${chunk[@]:2}"

    input=($(PNG_skip_chunk ${chunk[0]} "${input[@]}"))
    chunks=("${chunks[@]}" "${chunk[1]}")
done
