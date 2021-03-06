#!/bin/bash

# Bash script for converting RGB ANSI-sequences to palette

## Requirements:
# - bash

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

# Functions

## Utilities

# Prints index of nearest color from palette
#
# http://algolist.manual.ru/graphics/find_col.php
#
# @:1:3 - int[3] - RGB
# @:4   - int[]  - palette
function find_nearest_color() {
    local input=("${@:4}")

    local diff=0
    local nearest=0
    for ((i = 0; $i < ${#input[@]}; ++i)) ; do
        local c=(${input[$i]//:/ })

        local d=$((30 * (${c[0]} - $1) ** 2 + 59 * (${c[1]} - $2) ** 2 + 11 * (${c[2]} - $3) ** 2))
        if [[ $i -eq 0 ]] || [[ $d -lt $diff ]] ; then
            nearest=$i
            diff=$d
        fi

        if [[ $diff -eq 0 ]] ; then
            break
        fi
    done

    echo $nearest
}

## SRG

# https://github.com/sindresorhus/xterm-colors/blob/master/xterm-colors.json
SGR_rgb2palette_Palette_values=(
    '0:0:0' '128:0:0' '0:128:0' '128:128:0' '0:0:128' '128:0:128' '0:128:128' '192:192:192'
    '128:128:128' '255:0:0' '0:255:0' '255:255:0' '0:0:255' '255:0:255' '0:255:255' '255:255:255'
    '0:0:0' '0:0:95' '0:0:135' '0:0:175' '0:0:215' '0:0:255' '0:95:0' '0:95:95'
    '0:95:135' '0:95:175' '0:95:215' '0:95:255' '0:135:0' '0:135:95' '0:135:135' '0:135:175'
    '0:135:215' '0:135:255' '0:175:0' '0:175:95' '0:175:135' '0:175:175' '0:175:215' '0:175:255'
    '0:215:0' '0:215:95' '0:215:135' '0:215:175' '0:215:215' '0:215:255' '0:255:0' '0:255:95'
    '0:255:135' '0:255:175' '0:255:215' '0:255:255' '95:0:0' '95:0:95' '95:0:135' '95:0:175'
    '95:0:215' '95:0:255' '95:95:0' '95:95:95' '95:95:135' '95:95:175' '95:95:215' '95:95:255'
    '95:135:0' '95:135:95' '95:135:135' '95:135:175' '95:135:215' '95:135:255' '95:175:0' '95:175:95'
    '95:175:135' '95:175:175' '95:175:215' '95:175:255' '95:215:0' '95:215:95' '95:215:135' '95:215:175'
    '95:215:215' '95:215:255' '95:255:0' '95:255:95' '95:255:135' '95:255:175' '95:255:215' '95:255:255'
    '135:0:0' '135:0:95' '135:0:135' '135:0:175' '135:0:215' '135:0:255' '135:95:0' '135:95:95'
    '135:95:135' '135:95:175' '135:95:215' '135:95:255' '135:135:0' '135:135:95' '135:135:135' '135:135:175'
    '135:135:215' '135:135:255' '135:175:0' '135:175:95' '135:175:135' '135:175:175' '135:175:215' '135:175:255'
    '135:215:0' '135:215:95' '135:215:135' '135:215:175' '135:215:215' '135:215:255' '135:255:0' '135:255:95'
    '135:255:135' '135:255:175' '135:255:215' '135:255:255' '175:0:0' '175:0:95' '175:0:135' '175:0:175'
    '175:0:215' '175:0:255' '175:95:0' '175:95:95' '175:95:135' '175:95:175' '175:95:215' '175:95:255'
    '175:135:0' '175:135:95' '175:135:135' '175:135:175' '175:135:215' '175:135:255' '175:175:0' '175:175:95'
    '175:175:135' '175:175:175' '175:175:215' '175:175:255' '175:215:0' '175:215:95' '175:215:135' '175:215:175'
    '175:215:215' '175:215:255' '175:255:0' '175:255:95' '175:255:135' '175:255:175' '175:255:215' '175:255:255'
    '215:0:0' '215:0:95' '215:0:135' '215:0:175' '215:0:215' '215:0:255' '215:95:0' '215:95:95'
    '215:95:135' '215:95:175' '215:95:215' '215:95:255' '215:135:0' '215:135:95' '215:135:135' '215:135:175'
    '215:135:215' '215:135:255' '215:175:0' '215:175:95' '215:175:135' '215:175:175' '215:175:215' '215:175:255'
    '215:215:0' '215:215:95' '215:215:135' '215:215:175' '215:215:215' '215:215:255' '215:255:0' '215:255:95'
    '215:255:135' '215:255:175' '215:255:215' '215:255:255' '255:0:0' '255:0:95' '255:0:135' '255:0:175'
    '255:0:215' '255:0:255' '255:95:0' '255:95:95' '255:95:135' '255:95:175' '255:95:215' '255:95:255'
    '255:135:0' '255:135:95' '255:135:135' '255:135:175' '255:135:215' '255:135:255' '255:175:0' '255:175:95'
    '255:175:135' '255:175:175' '255:175:215' '255:175:255' '255:215:0' '255:215:95' '255:215:135' '255:215:175'
    '255:215:215' '255:215:255' '255:255:0' '255:255:95' '255:255:135' '255:255:175' '255:255:215' '255:255:255'
    '8:8:8' '18:18:18' '28:28:28' '38:38:38' '48:48:48' '58:58:58' '68:68:68' '78:78:78'
    '88:88:88' '96:96:96' '102:102:102' '118:118:118' '128:128:128' '138:138:138' '148:148:148' '158:158:158'
    '168:168:168' '178:178:178' '188:188:188' '198:198:198' '208:208:208' '218:218:218' '228:228:228' '238:238:238'
)

SGR_rgb2palette_Palette_codes=(
    0 1 2 3 4 5 6 7
    '8;5;8' '8;5;9' '8;5;10' '8;5;11' '8;5;12' '8;5;13' '8;5;14' '8;5;15'
    '8;5;16' '8;5;17' '8;5;18' '8;5;19' '8;5;20' '8;5;21' '8;5;22' '8;5;23'
    '8;5;24' '8;5;25' '8;5;26' '8;5;27' '8;5;28' '8;5;29' '8;5;30' '8;5;31'
    '8;5;32' '8;5;33' '8;5;34' '8;5;35' '8;5;36' '8;5;37' '8;5;38' '8;5;39'
    '8;5;40' '8;5;41' '8;5;42' '8;5;43' '8;5;44' '8;5;45' '8;5;46' '8;5;47'
    '8;5;48' '8;5;49' '8;5;50' '8;5;51' '8;5;52' '8;5;53' '8;5;54' '8;5;55'
    '8;5;56' '8;5;57' '8;5;58' '8;5;59' '8;5;60' '8;5;61' '8;5;62' '8;5;63'
    '8;5;64' '8;5;65' '8;5;66' '8;5;67' '8;5;68' '8;5;69' '8;5;70' '8;5;71'
    '8;5;72' '8;5;73' '8;5;74' '8;5;75' '8;5;76' '8;5;77' '8;5;78' '8;5;79'
    '8;5;80' '8;5;81' '8;5;82' '8;5;83' '8;5;84' '8;5;85' '8;5;86' '8;5;87'
    '8;5;88' '8;5;89' '8;5;90' '8;5;91' '8;5;92' '8;5;93' '8;5;94' '8;5;95'
    '8;5;96' '8;5;97' '8;5;98' '8;5;99' '8;5;100' '8;5;101' '8;5;102' '8;5;103'
    '8;5;104' '8;5;105' '8;5;106' '8;5;107' '8;5;108' '8;5;109' '8;5;110' '8;5;111'
    '8;5;112' '8;5;113' '8;5;114' '8;5;115' '8;5;116' '8;5;117' '8;5;118' '8;5;119'
    '8;5;120' '8;5;121' '8;5;122' '8;5;123' '8;5;124' '8;5;125' '8;5;126' '8;5;127'
    '8;5;128' '8;5;129' '8;5;130' '8;5;131' '8;5;132' '8;5;133' '8;5;134' '8;5;135'
    '8;5;136' '8;5;137' '8;5;138' '8;5;139' '8;5;140' '8;5;141' '8;5;142' '8;5;143'
    '8;5;144' '8;5;145' '8;5;146' '8;5;147' '8;5;148' '8;5;149' '8;5;150' '8;5;151'
    '8;5;152' '8;5;153' '8;5;154' '8;5;155' '8;5;156' '8;5;157' '8;5;158' '8;5;159'
    '8;5;160' '8;5;161' '8;5;162' '8;5;163' '8;5;164' '8;5;165' '8;5;166' '8;5;167'
    '8;5;168' '8;5;169' '8;5;170' '8;5;171' '8;5;172' '8;5;173' '8;5;174' '8;5;175'
    '8;5;176' '8;5;177' '8;5;178' '8;5;179' '8;5;180' '8;5;181' '8;5;182' '8;5;183'
    '8;5;184' '8;5;185' '8;5;186' '8;5;187' '8;5;188' '8;5;189' '8;5;190' '8;5;191'
    '8;5;192' '8;5;193' '8;5;194' '8;5;195' '8;5;196' '8;5;197' '8;5;198' '8;5;199'
    '8;5;200' '8;5;201' '8;5;202' '8;5;203' '8;5;204' '8;5;205' '8;5;206' '8;5;207'
    '8;5;208' '8;5;209' '8;5;210' '8;5;211' '8;5;212' '8;5;213' '8;5;214' '8;5;215'
    '8;5;216' '8;5;217' '8;5;218' '8;5;219' '8;5;220' '8;5;221' '8;5;222' '8;5;223'
    '8;5;224' '8;5;225' '8;5;226' '8;5;227' '8;5;228' '8;5;229' '8;5;230' '8;5;231'
    '8;5;232' '8;5;233' '8;5;234' '8;5;235' '8;5;236' '8;5;237' '8;5;238' '8;5;239'
    '8;5;240' '8;5;241' '8;5;242' '8;5;243' '8;5;244' '8;5;245' '8;5;246' '8;5;247'
    '8;5;248' '8;5;249' '8;5;250' '8;5;251' '8;5;252' '8;5;253' '8;5;254' '8;5;255'
)

# Converts RGB to SRG palette
#
# @:1:3 - int[3] - RGB
# 4     - int    - 3/4 - fg/bg marker
function SRG_rgb2palette() {
    echo "${4:0:1}${SGR_rgb2palette_Palette_codes[$(find_nearest_color "${@:1:3}" "${SGR_rgb2palette_Palette_values[@]}")]//;/ }"
}

# Fixes RGB SRG to ANSI palette
#
# If ESC-sequence is not SRG or is not ESC-sequence returns w/o printing anything.
#
# @ - char[] - ESC-sequence
function SRG_fix() {
    local i

    local input=("$@")

    ([[ ${input[0]} != $'\x1B' ]] || [[ ${input[@]:${#input[@]} - 1:1} != m ]]) && return
    if [[ ${input[1]} != '[' ]] || [[ ${#input[@]} -eq 2 ]] ; then
        input="${input[*]}"

        printf '%s' "${input// /}"
        return
    fi

    input="${input[*]:2:${#input[@]} - 3}"
    input="${input// /}"

    input=(${input//;/ })

    local result=()
    for ((i = 0; i < ${#input[@]}; ++i)) ; do
        if [[ ${input[$i]} -ne 38 ]] && [[ ${input[$i]} -ne 48 ]] || [[ ${input[$i + 1]} -ne 2 ]] ; then
            result=("${result[@]}" "${input[$i]}")
            continue
        fi

        result=("${result[@]}" $(SRG_rgb2palette "${input[@]:$i + 2:3}" ${input[$i]}))
        ((i += 4))
    done

    result="${result[*]}"
    printf '\x1B[%sm' "${result// /;}"
}

# Entry point

while read line ; do
    for ((i = 0; i < ${#line}; ++i)) ; do
        if [[ ${line:$i:1} != $'\x1B' ]] ; then
            printf '%c' "${line:$i:1}"
            continue
        fi

        seq=()
        for ((; i < ${#line}; ++i)) ; do
            seq=("${seq[@]}" "${line:$i:1}")
            printf '%c' "${line:$i:1}"

            case "${line:$i:1}" in
            'm' )
                SRG_fix "${seq[@]}"
                break
                ;;
            '[@-~]' )
                break
                ;;
            esac
        done
    done

    echo
done
