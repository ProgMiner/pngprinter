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

# Converts RGB color to ASCII
#
# 1 - int - red component
# 2 - int - green component
# 3 - int - blue component
function rgb2ascii() {
    # TODO
    echo 7
}

# Reads data from stream and prints bytes array
function read_bytes() {
    echo "$( xxd -p -c 1 | nawk '
BEGIN {
    for (i = 0; i < 256; ++i) {
        hex2dec[sprintf("%02x", i)] = i
    }
}

{
    print hex2dec[$0]
}
')"
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

# Reads chunk and prints it in following format:
#   [0]  - chunk data length
#   [1]  - chunk type
#   [2:] - chunk data bytes
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

# Uncompresses data
#
# 1 -   int   - compression method
# @:2 - int[] - compressed bytes array
function PNG_uncompress() {
    if [[ "$1" -ne 0 ]] ; then
        echo "Undefined compression method $1" >&2
    fi

    chr_array "${@:2}" | gzip -cd - | read_bytes
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
# Printing format:
#   <Keyword>: <Text>
#
# @ - int[] - bytes array
function PNG_format_text() {
    local input=("$@")

    local i=0
    local keyword=
    for ((; $i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        keyword="$keyword$(chr "${input[$i]}")"
    done

    if [[ "$i" -lt 1 ]] || [[ "$i" -gt 79 ]] ; then
        echo 'Bad tEXt chunk' >&2
    fi

    printf '%s: %s' "$keyword" "$(chr_array "${input[@]:$(( $i + 1 ))}" | cat -vt)"
}

# Prints formatted zTXt content
#
# Printing format:
#   <Keyword>: <Text>
#
# @ - int[] - bytes array
function PNG_format_compressed_text() {
    local input=("$@")

    local i=0
    local keyword=
    for ((; $i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        keyword="$keyword$(chr "${input[$i]}")"
    done

    if [[ "$i" -lt 1 ]] || [[ "$i" -gt 79 ]] ; then
        echo 'Bad zTXt chunk' >&2
    fi

    ((++i))
    printf '%s: %s' "$keyword" "$(chr_array "$(PNG_uncompress "${input[@]:$i}")" | cat -vt)"
}

# Prints formatted iTXt content
#
# Printing format:
#   <Keyword> (<Language> - <Translated keyword>): <Text>
# or if Language or Translated keyword is not presented:
#   <Keyword> (<Language/Translated keyword>: <Text>
# or if Language and Translated keyword is not presented:
#   <Keyword>: <Text>
#
# @ - int[] - bytes array
function PNG_format_international_text() {
    local input=("$@")

    local i=0
    local keyword=
    for ((; $i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        keyword="$keyword$(chr "${input[$i]}")"
    done

    if [[ "$i" -lt 1 ]] || [[ "$i" -gt 79 ]] ; then
        echo 'Bad iTXt chunk' >&2
    fi

    ((++i))
    local compression="${input[$i]}"

    ((++i))
    local method="${input[$i]}"

    ((++i))
    local lang=
    for ((; $i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        lang="$lang$(chr "${input[$i]}")"
    done

    ((++i))
    local trans_keyword=
    for ((; $i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        trans_keyword=("${trans_keyword[@]}" "${input[$i]}")
    done

    ((++i))
    local text=("${input[@]:$i}")

    if [[ "$compression" -ne 0 ]] ; then
        text="$(PNG_uncompress "$method" "${text[@]}")"
    fi

    text=$(chr_array "${text[@]}" | cat -vt)

    case "${#lang}${#trans_keyword}" in
    '00' )
        printf '%s: %s' "$keyword" "$text"
        ;;
    '0*' )
        printf '%s (%s): %s' "$keyword" "$trans_keyword" "$text"
        ;;
    '*0' )
        printf '%s (%s): %s' "$keyword" "$lang" "$text"
        ;;
    '*' )
        printf '%s (%s - %s): %s' "$keyword" "$lang" "$trans_keyword" "$text"
        ;;
    esac
}

# Entry point

if ! type nawk &> /dev/null ; then
    # alias nawk=awk

    function nawk() {
        awk "$@"
    }
fi

input=($(read_bytes))

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
#   - 7 - Gamma
header=()

# Palette. Array with colors or empty if not used
palette=()

# Array of all IDAT chunks content
data=()

# Array with readed chunk types
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

    printf 'Chunk %s length %d: ' ${chunk[1]} ${chunk[0]}
    echo "${chunk[@]:2}"

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
        if array_contains 'PLTE' "${chunks[@]}" ; then
            echo 'PLTE chunks cannot be more than one' >&2
            exit
        fi

        if ! array_contains "${header[3]}" 2 3 6 ; then
            echo 'PLTE chunk is not allowed' >&2
            exit
        fi

        if (( ${chunk[0]} % 3 != 0 )) ; then
            echo 'Bad PLTE chunk' >&2
            exit
        fi

        if (( ${chunk[0]} / 3 > 2 ** ${header[2]} )) ; then
            echo 'Palette is too large for bit depth' >&2
            exit
        fi

        for ((i=2; $i < ${#chunk[@]}; i+=3)) ; do
            palette=("${palette[@]}" $(rgb2ascii ${chunk[@]:$i}))
        done
        ;;
    'IDAT' )
        if array_contains 'IDAT' "${chunks[@]}" && [[ "${chunks[@]:-1:1}" != 'IDAT' ]] ; then
            echo 'IDAT chunks must follow one by one' >&2
            exit
        fi

        data=("${data[@]}" "${chunk[@]:2}")
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
        if array_contains 'PLTE' "${chunks[@]}" || array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'gAMA must be before PLTE and IDAT chunks' >&2
            exit
        fi

        # TODO
        echo 'Warning: cHRM chunk is not supported' >&2
        ;;
    'gAMA' )
        if array_contains 'PLTE' "${chunks[@]}" || array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'gAMA must be before PLTE and IDAT chunks' >&2
            exit
        fi

        # TODO
        echo 'Warning: gAMA chunk is not supported' >&2
        ;;
    'iCCP' )
        if array_contains 'PLTE' "${chunks[@]}" || array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'iCCP must be before PLTE and IDAT chunks' >&2
            exit
        fi

        if array_contains 'sRGB' "${chunks[@]}" ; then
            echo 'iCCP and sRGB cannot be together' >&2
            exit
        fi

        # TODO
        echo 'Warning: iCCP chunk is not supported' >&2
        ;;
    'sBIT' )
        if array_contains 'PLTE' "${chunks[@]}" || array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'sBIT must be before PLTE and IDAT chunks' >&2
            exit
        fi

        # TODO
        echo 'Warning: sBIT chunk is not supported' >&2
        ;;
    'sRGB' )
        if array_contains 'PLTE' "${chunks[@]}" || array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'sRGB must be before PLTE and IDAT chunks' >&2
            exit
        fi

        if array_contains 'iCCP' "${chunks[@]}" ; then
            echo 'iCCP and sRGB cannot be together' >&2
            exit
        fi

        # TODO
        echo 'Warning: sRGB chunk is not supported' >&2
        ;;
    'bKGD' )
        if array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'bKGD must be before IDAT chunk' >&2
            exit
        fi

        # TODO
        echo 'bKGD chunk is ignored' >&2
        ;;
    'hIST' )
        if array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'hIST must be before IDAT chunk' >&2
            exit
        fi

        # TODO
        echo 'Warning: hIST chunk is not supported' >&2
        ;;
    'tRNS' )
        if array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'tRNS must be before IDAT chunk' >&2
            exit
        fi

        # TODO
        echo 'Warning: tRNS chunk is not supported' >&2
        ;;
    'pHYs' )
        if array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'pHYs must be before IDAT chunk' >&2
            exit
        fi

        x=$(bytes2uint "${chunk[@]:2}")
        y=$(bytes2uint "${chunk[@]:6}")
        if [[ $x -ne $y ]] ; then
            echo "Pixels aspect ratio is $x / $y but not supported" >&2
        fi
        ;;
    'sPLT' )
        if array_contains 'IDAT' "${chunks[@]}" ; then
            echo 'sPLT must be before IDAT chunk' >&2
            exit
        fi

        # TODO
        echo 'Warning: sPLT chunk is not supported' >&2
        ;;
    'tIME' )
        if array_contains 'tIME' "${chunks[@]}" ; then
            echo 'tIME chunks cannot be more than one' >&2
            exit
        fi

        echo 'Image last edit time:' "$(PNG_format_time ${chunk[@]:2})"
        ;;
    'iTXt' )
        echo "$(PNG_format_international_text "${chunk[@]:2}")"
        ;;
    'tEXt' )
        echo "$(PNG_format_text "${chunk[@]:2}")"
        ;;
    'zTXt' )
        echo "$(PNG_compressed_text "${chunk[@]:2}")"
        ;;
    esac

    input=($(PNG_skip_chunk ${chunk[0]} "${input[@]}"))
    chunks=("${chunks[@]}" "${chunk[1]}")
done
