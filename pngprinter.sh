#!/bin/bash

# Bash script for displaying PNG images on terminal

## Requirements:
# - bash
# - awk | nawk
# - python2 with zlib
# - True-color terminal

## License:

# MIT License
#
# Copyright (c) 2018 Eridan Domoratskiy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Aliases

if ! type nawk &> /dev/null ; then
    # alias nawk=awk

    function nawk() {
        awk "$@"
    }
fi

if ! type python2 &> /dev/null ; then
    # alias python2=python

    function python2() {
        python "$@"
    }
fi

# Functions

## Utilities

### Bytes

# Prints char with specified ASCII code
#
# https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet
#
# 1 - int - char code
function chr() {
    [ "$1" -lt 256 ] || return 1
    printf "\\$(printf '%03o' "$1")"
}

# Applies chr on array and prints
#
# @ - int[] - char codes
function chr_array() {
    local i

    for ((i = 1; i <= $#; ++i)) ; do
        chr ${!i}
    done
}

# Converts bytes to unsigned integer and prints it
#
# @ - int[] - array of bytes
function bytes2uint() {
    local i

    local ret=0
    for ((i = 1; i <= $#; ++i)) ; do
        ret=$(($ret + (${!i} << (8 * ($# - $i)))))
    done

    echo $ret
}

# Reads data from stream and prints bytes array
function read_bytes() {
    xxd -p -c 1 | nawk '
BEGIN {
    for (i = 0; i < 256; ++i) {
        hex2dec[sprintf("%02x", i)] = i
    }
}

{
    printf("%s ", hex2dec[$0])
}
'
}

### Math

# Prints absolute value of number
#
# 1 - int - number
function abs() {
    echo ${1#-}
}

# Division with floor to greater value
#
# 1 - int - numerator
# 2 - int - denominator
function div_greater() {
    echo $(($1 / $2 + ($1 % $2 > 0 ? 1 : 0)))
}

### Arrays

# Checks is array contains a value
#
# 1   - string   - value
# @:2 - string[] - array
function array_contains() {
    local input=("${@:2}")
    local value="$1"

    local elem
    for elem in "${input[@]}" ; do
        [[ $value == $elem ]] && return 0
    done

    return 1
}

# Prints index of nearest value from array
#
# 1   - int   - value
# @:2 - int[] - array
function find_nearest() {
    local input=("${@:2}")

    local i
    local nearest=0
    local diff=$(abs $((${input[0]} - $1)))
    for ((i = 1; i < ${#input[@]}; ++i)) ; do
        if [[ $diff -eq 0 ]] ; then
            break
        fi

        if [[ $(abs $((${input[$i]} - $1))) -lt $diff ]] ; then
            diff=$(abs $((${input[$i]} - $1)))
            nearest=$i
        fi
    done

    echo $nearest
}

### Color

# Mixes color with background color
#
# @link https://habr.com/post/98743/
#
# @:1:4 - int[4] - foreground color RGBA
# @:5:3 - int[3] - background color RGB
# 8     - int    - bit depth
function apply_background() {
    local max=$((2 ** $8 - 1))

    echo $(($5 + ($1 - $5) * $4 / $max))
    echo $(($6 + ($2 - $6) * $4 / $max))
    echo $(($7 + ($3 - $7) * $4 / $max))
}

# Converts color to ANSI ESC-sequence
#
# 1     - int    - bit depth
# @:2:3 - int[3] - RGB
function color2ansi() {
    local color=(
        $(($2 * 256 / (2 ** $1)))
        $(($3 * 256 / (2 ** $1)))
        $(($4 * 256 / (2 ** $1)))
    )

    printf '\x1B[48;2;%d;%d;%dm \x1B[0m' "${color[@]}"
}

# Serializes color array
#
# @ - color components
function color_serialize() {
    local color="$*"
    echo "${color// /:}"
}

# Unserializes color array
#
# 1 - serialized color components
function color_unserialize() {
    echo "${1//:/ }"
}

### Other

# Inflates deflated stream in zlib format
function zlib_uncompress() {
    python2 -c "import zlib,sys;sys.stdout.write(zlib.decompress(sys.stdin.read()))"
}

## PNG

# Converts bytes to color
#
# 1   - int   - bit depth
# @:2 - int[] - color components
function PNG_bytes2color() {
    local i

    local comp=$(($1 / 8))
    [[ $comp -eq 0 ]] && comp=1

    local bytes=("${@:2}")

    local buf=()
    local color=()
    for ((i = 0; i <= ${#bytes[@]}; ++i)) ; do
        if [[ $i -ne 0 ]] && (($i % $comp == 0)) ; then
            color=("${color[@]}" $(bytes2uint "${buf[@]}"))
            buf=()
        fi

        buf=("${buf[@]}" ${bytes[$i]})
    done

    echo "${color[@]}"
}

PNG_check_sign_sign="137 80 78 71 13 10 26 10"
# Checks is bytes is a PNG image
#
# @ - int[8] - array of bytes
function PNG_check_sign() {
    [[ "${*:1:8}" == "$PNG_check_sign_sign" ]]
}

# Reads chunk and prints it in following format:
#   [0]  - chunk data length
#   [1]  - chunk type
#   [2:] - chunk data bytes
#
# @ - int[12] - array of bytes
function PNG_read_chunk() {
    local input=("$@")

    local length=$(bytes2uint "${input[@]:0:4}")
    if [[ $length -ge 4294967296 ]] ; then
        echo 'Bad chunk size' >&2
        kill $$
    fi

    local b
    local type=("${input[@]:4:4}")
    for b in "${type[@]}" ; do
        if (( ($b < 65 || $b > 90) && ($b < 97 || $b > 122) )) ; then
            echo 'Bad chunk type' >&2
            kill $$
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

    chr_array "${@:2}" | zlib_uncompress | read_bytes
}

# Prints formatted tIME content
#
# @ - int[] - bytes array
function PNG_format_time() {
    local input=("$@")

    local time=($(bytes2uint "${input[@]:0:2}") "${input[@]:2}")
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
    for ((; i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        keyword="$keyword$(chr "${input[$i]}")"
    done

    if [[ "$i" -lt 1 ]] || [[ "$i" -gt 79 ]] ; then
        echo 'Bad tEXt chunk' >&2
    fi

    printf '%s: %s' "$keyword" "$(chr_array "${input[@]:$i + 1}" | cat -vt)"
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
    for ((; i < "${#input[@]}"; ++i)) ; do
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
    for ((; i < "${#input[@]}"; ++i)) ; do
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
    for ((; i < "${#input[@]}"; ++i)) ; do
        [[ "${input[$i]}" -eq 0 ]] && break

        lang="$lang$(chr "${input[$i]}")"
    done

    ((++i))
    local trans_keyword=
    for ((; i < "${#input[@]}"; ++i)) ; do
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

PNG_get_parts_sizes_Adam7=(
    0 5 3 5 1 5 3 5
    6 6 6 6 6 6 6 6
    4 5 4 5 4 5 4 5
    6 6 6 6 6 6 6 6
    2 5 3 5 2 5 3 5
    6 6 6 6 6 6 6 6
    4 5 4 5 4 5 4 5
    6 6 6 6 6 6 6 6
)

# Prints widths and heights of parts of image in following format:
#   [0]  - parts count
#   [1:] - parts sizes (2 numbers on part: width and height)
#
# @ - int[7] - image header
function PNG_get_parts_sizes() {
    local header=("$@")

    case "${header[6]}" in
    '0' )
        echo 1 "${header[0]}" "${header[1]}"
        ;;
    '1' )
        echo 7

        echo $(div_greater ${header[0]} 8) $(div_greater ${header[1]} 8)
        echo $(div_greater $((${header[0]} - 4)) 8) $(div_greater ${header[1]} 8)
        echo $(div_greater ${header[0]} 4) $(div_greater $((${header[1]} - 4)) 8)
        echo $(div_greater $((${header[0]} - 2)) 4) $(div_greater ${header[1]} 4)
        echo $(div_greater ${header[0]} 2) $(div_greater $((${header[1]} - 2)) 4)
        echo $(div_greater $((${header[0]} - 1)) 2) $(div_greater ${header[1]} 2)
        echo ${header[0]} $(div_greater $((${header[1]} - 1)) 2)
        ;;
    '*' )
        echo "Undefined interlace method ${header[6]}" >&2
        kill $$
    esac
}

# Prints pixel components count
#
# @ - int[7] - image header
function PNG_get_pixel_components() {
    case "$4" in
    0|3 )
        echo 1
        ;;
    4 )
        echo 2
        ;;
    2 )
        echo 3
        ;;
    6 )
        echo 4
        ;;
    esac
}

# Prints pixel size by PNG header in following format:
#   [0] - int - count of bytes in pixel (from 1 to 4)
#   [1] - int - count of pixels in byte (from 1 to 8)
#   [2] - int - bit depth
#
# @ - int[7] - image header
function PNG_get_pixel_size() {
    if [[ $3 -lt 8 ]] ; then
        echo 1 $((8 / $3)) $3
        return
    fi

    local comps=$(PNG_get_pixel_components "$@")
    echo $((($3 / 8) * $comps)) 1 $3
}

# PaethPredictor reconstruction function
#
# 1 - int - Recon(a)
# 2 - int - Recon(b)
# 3 - int - Recon(c)
function PNG_reconstruct_PaethPredictor() {
    local p=$(($1 + $2 - $3))
    local pa=$(abs $(($p - $1)))
    local pb=$(abs $(($p - $2)))
    local pc=$(abs $(($p - $3)))

    if [[ $pa -le $pb ]] && [[ $pa -le $pc ]] ; then
        echo $1
    elif [[ $pb -le $pc ]] ; then
        echo $2
    else
        echo $3
    fi
}

# Reconstructs scanline from filtered
#
# 1        - int     - filter method
# 2        - int     - pixel size in bytes
# 3        - int     - line length in bytes
# 4        - int     - line filter type
# @:5:$3   - int[$3] - filtered line
# @:$3 + 5 - int[]   - reconstructed previous line
function PNG_reconstruct_line() {
    local line=("${@:5:$3}")
    local prev_line=("${@:$3 + 5}")

    if [[ $1 -ne 0 ]] ; then
        echo "Undefined filter method $1" >&2
        kill $$
    fi

    local x
    local cur_line=()
    for ((x = 0; x < $3; ++x)) ; do
        case "$4" in
        0 )
            cur_line=("${cur_line[@]}" ${line[$x]})
            ;;
        1 )
            if [[ $x -lt $2 ]] ; then
                cur_line=("${cur_line[@]}" ${line[$x]})
            else
                cur_line=("${cur_line[@]}" $(((${line[$x]} + ${cur_line[$x - $2]}) % 256)))
            fi
            ;;
        2 )
            cur_line=("${cur_line[@]}" $(((${line[$x]} + ${prev_line[$x]:-0}) % 256)))
            ;;
        3 )
            if [[ $x -lt $2 ]] ; then
                cur_line=("${cur_line[@]}" $(((${line[$x]} + ${prev_line[$x]:-0} / 2) % 256)))
            else
                cur_line=("${cur_line[@]}" $(((${line[$x]} + (${cur_line[$x - $2]} + ${prev_line[$x]:-0}) / 2) % 256)))
            fi
            ;;
        4 )
            if [[ $x -lt $2 ]] ; then
                cur_line=("${cur_line[@]}" $(((${line[$x]} + $(PNG_reconstruct_PaethPredictor 0 ${prev_line[$x]:-0} 0)) % 256)))
            else
                cur_line=("${cur_line[@]}" $(((${line[$x]} + $(PNG_reconstruct_PaethPredictor ${cur_line[$x - $2]} ${prev_line[$x]:-0} ${prev_line[$x - $2]:-0})) % 256)))
            fi
            ;;
        * )
            echo "Undefined filter type $4" >&2
            kill $$
            ;;
        esac
    done

    echo "${cur_line[@]}"
}

# Splits bytes to pixels array
#
# @:1:3 - int[3] - pixel size
# @:4   - int[]  - line bytes
function PNG_unserialize_line() {
    local i
    local j

    local input=("${@:4}")

    local pixels=()
    if [[ $2 -eq 1 ]] ; then
        for ((i = 0; i < ${#input[@]}; i += $1)) ; do
            pixels=("${pixels[@]}" $(color_serialize $(PNG_bytes2color $3 "${input[@]:$i:$1}")))
        done
    else
        local mask=$((2 ** $3 - 1))

        local buf
        local byte
        for byte in "${input[@]}" ; do
            buf=()

            for ((i = 0; i < $2; ++i)) ; do
                buf=($(color_serialize $(PNG_bytes2color $3 $(($byte & $mask)))) "${buf[@]}")
                (( byte >>= $3 ))
            done

            pixels=("${pixels[@]}" "${buf[@]}")
        done
    fi

    echo "${pixels[@]}"
}

# Entry point

## Options handling

options=()
for ((i = 1; i <= $#; ++i)) ; do
    case "${!i}" in
    '-v'|'--verbose' )
        options=("${options[@]}" 'verbose')
        ;;
    '-q'|'--quiet' )
        options=("${options[@]}" 'quiet' 'ignore tIME' 'ignore tEXt' 'ignore zTXt' 'ignore iTXt')
        ;;
    '-i'|'--ignore' )
        ((++i))

        if array_contains "${!i}" IHDR PLTE IDAT IEND ; then
            echo 'Cannot ignore critical chunks!' >&2
            kill $$
        fi

        options=("${options[@]}" "ignore ${!i}")
        ;;
    '-b'|'--background' )
        ((++i))
        background=("${!i}")

        ((++i))
        background=("${background[@]}" "${!i}")

        ((++i))
        background=("${background[@]}" "${!i}")

        options=("${options[@]}" 'background' 'ignore bKGD')
        ;;
    esac
done

input=($(read_bytes))

if ! PNG_check_sign "${input[@]}" ; then
    echo 'File is not PNG image!' >&2
    kill $$
fi

input=("${input[@]:8}")

# Image array format:
#   - 0 - Width
#   - 1 - Height
#   - 2 - Bit depth
#   - 3 - Color type
#   - 4 - Compression method
#   - 5 - Filter method
#   - 6 - Interlace method
header=()

# Palette. Array with colors or empty if not used
palette=()

# Color that will be treated as transparent
transparent=()

# Background color
array_contains 'background' "${options[@]}" || background=(0 0 0)

# Array of all IDAT chunks content
data=()

# Array with readed chunk types
chunks=()

while true ; do
    if [[ ${#input[@]} -eq 0 ]] ; then
        echo 'Missing IEND chunk' >&2
        kill $$
    fi

    chunk=($(PNG_read_chunk "${input[@]}"))

    if [[ ${#chunks[@]} -eq 0 ]] && [[ ${chunk[1]} != 'IHDR' ]] ; then
        echo 'Missing IHDR chunk' >&2
        kill $$
    fi

    input=($(PNG_skip_chunk ${chunk[0]} "${input[@]}"))
    if array_contains "ignore ${chunk[1]}" "${options[@]}" ; then
        array_contains 'verbose' "${options[@]}" && echo "Chunk ${chunk[1]} ignored" >&2
        continue
    fi

    array_contains 'verbose' "${options[@]}" && printf 'Chunk %s length %d: %s\n' "${chunk[1]}" "${chunk[0]}" "${chunk[*]:2}" >&2

    case "${chunk[1]}" in

    # Critical chunks
    'IHDR' )
        if [[ ${chunk[0]} -ne 13 ]] ; then
            echo 'Bad IHDR chunk' >&2
            kill $$
        fi

        header=($(bytes2uint ${chunk[@]:2:4}) $(bytes2uint ${chunk[@]:6:4}) "${chunk[@]:10}")

        if (( "${header[0]}" == 0 || "${header[1]}" == 0 )) ||
            ! array_contains "${header[2]}" 1 2 4 8 16 ||
            ! array_contains "${header[3]}" 0 2 3 4 6 ||
            [[ "${header[5]}" -ne 0 ]] ||
            ! array_contains "${header[6]}" 0 1 ||
            (array_contains "${header[3]}" 2 4 6 && array_contains "${header[2]}" 1 2 4) ||
            (( "${header[3]}" == 3 && "${header[2]}" == 16 )); then
            echo 'Bad IHDR chunk' >&2
            kill $$
        fi

        array_contains 'quiet' "${options[@]}" || printf 'Image size: %dx%dpx
Bit depth: %d
Color type: %d
Compression method: %d
Filter method: %d
Interlace method: %d\n' "${header[@]}"
        ;;
    'PLTE' )
        if array_contains 'PLTE' "${chunks[@]}" ; then
            echo 'PLTE chunks cannot be more than one' >&2
            kill $$
        fi

        if ! array_contains "${header[3]}" 2 3 6 ; then
            echo 'PLTE chunk is not allowed' >&2
            kill $$
        fi

        if (( ${chunk[0]} % 3 != 0 )) ; then
            echo 'Bad PLTE chunk' >&2
            kill $$
        fi

        if (( ${chunk[0]} / 3 > 2 ** ${header[2]} )) ; then
            echo 'Palette is too large for bit depth' >&2
            kill $$
        fi

        for ((i = 2; i < ${#chunk[@]}; i += 3)) ; do
            palette=("${palette[@]}" $(color_serialize "${chunk[@]:$i:3}"))
        done
        ;;
    'IDAT' )
        if array_contains 'IDAT' "${chunks[@]}" && [[ "${chunks[@]:${#chunks[@]} - 1:1}" != 'IDAT' ]] ; then
            echo 'IDAT chunks must follow one by one' >&2
            kill $$
        fi

        data=("${data[@]}" "${chunk[@]:2}")
        ;;
    'IEND' )
        if [[ ${chunk[0]} -ne 0 ]] ; then
            echo 'Bad IEND chunk' >&2
            kill $$
        fi

        break
        ;;

    # Ancillary chunks
    'tRNS' )
        if array_contains 'tRNS' "${chunks[@]}" ; then
            echo 'tRNS chunk cannot be more than one' >&2
            kill $$
        fi

        case ${header[3]} in
        2|4 )
            transparent=($(PNG_bytes2color 16 ${chunk[@]:2}))
            ;;
        3 )
            if ! array_contains 'PLTE' "${chunks[@]}" ; then
                echo 'tRNS chunk cannot be before PLTE' >&2
                kill $$
            fi

            if (( ${chunk[0]} > ${#palette[@]} )) ; then
                echo 'tRNS chunk cannot contain more values than palette' >&2
                kill $$
            fi

            transparent=("${chunk[@]:2}")
            ;;
        esac
        ;;
    'bKGD' )
        if array_contains 'bKGD' "${chunks[@]}" ; then
            echo 'bKGD chunk cannot be more than one' >&2
            kill $$
        fi

        case ${header[3]} in
        2|4 )
            background=($(PNG_bytes2color 16 ${chunk[@]:2}))
            ;;
        3 )
            if ! array_contains 'PLTE' "${chunks[@]}" ; then
                echo 'bKGD chunk cannot be before PLTE' >&2
                kill $$
            fi

            background=($(color_unserialize ${palette[${chunk[2]}]}))
            ;;
        esac
        ;;
    'tIME' )
        if array_contains 'tIME' "${chunks[@]}" ; then
            echo 'tIME chunks cannot be more than one' >&2
            kill $$
        fi

        echo 'Image last edit time:' "$(PNG_format_time ${chunk[@]:2})"
        ;;
    'iTXt' )
        PNG_format_international_text "${chunk[@]:2}"
        echo
        ;;
    'tEXt' )
        PNG_format_text "${chunk[@]:2}"
        echo
        ;;
    'zTXt' )
        PNG_format_compressed_text "${chunk[@]:2}"
        echo
        ;;

    # Ignored chunks
    '*' )
        echo "Chunk ${chunk[1]} ignored" >&2
        ;;
    esac

    chunks=("${chunks[@]}" "${chunk[1]}")
done

array_contains 'quiet' "${options[@]}" || printf 'Uncompressing...'
data=($(PNG_uncompress "${header[4]}" "${data[@]}"))
array_contains 'quiet' "${options[@]}" || echo $'   Done!'

pixel_size=($(PNG_get_pixel_size "${header[@]}"))

bit_depth=${header[2]}
[[ ${header[3]} == 3 ]] && bit_depth=8

parts=($(PNG_get_parts_sizes "${header[@]}"))
parts_count="${parts[0]}"
parts=("${parts[@]:1}")

cur_image=()
for ((i = 0; i < $parts_count; ++i)) ; do
    prev_line=()

    for ((y = 0; y < ${parts[1]}; ++y)) ; do
        # Reconstruct line
        length=$(div_greater $((${parts[0]} * ${pixel_size[0]})) ${pixel_size[1]})
        cur_line=($(PNG_reconstruct_line ${header[5]} ${pixel_size[0]} $length "${data[@]:0:$length + 1}" "${prev_line[@]}"))
        prev_line=("${cur_line[@]}")

        # Unserialize line
        line=($(PNG_unserialize_line "${pixel_size[@]}" "${cur_line[@]}"))

        # Print line
        for ((x = 0; x < ${parts[0]}; ++x)) ; do
            pixel=($(color_unserialize ${line[$x]}))

            # Resolve palette colors
            if [[ ${header[3]} -eq 3 ]] ; then
                pixel=($(color_unserialize ${palette[${pixel[0]}]}) ${transparent[${pixel[0]}]:-255})
            fi

            # Scale grayscale to RGB
            if [[ ${header[3]} -eq 0 ]] || [[ ${header[3]} -eq 4 ]] ; then
                pixel=(${pixel[0]} ${pixel[0]} ${pixel[0]} ${pixel[1]:-$((2 ** $bit_depth - 1))})
            fi

            # Add alpha component
            if [[ ${header[3]} -ne 3 ]] && [[ "${transparent[*]}" == "${pixel[*]}" ]] ; then
                pixel=(0 0 0 0)
            elif [[ ${#pixel[@]} -eq 3 ]] ; then
                if [[ ${header[3]} -eq 3 ]] ; then
                    pixel=("${pixel[@]}" 255)
                else
                    pixel=("${pixel[@]}" $((2 ** $bit_depth - 1)))
                fi
            fi

            # Print
            chr="$(color2ansi $bit_depth $(apply_background "${pixel[@]}" "${background[@]}" $bit_depth))"
            printf '%s%s' "$chr" "$chr"
        done
        echo

        data=("${data[@]:$length + 1}")
    done

    parts=("${parts[@]:2}")
done
