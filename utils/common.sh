#!/bin/bash

pre_treat_old_file () {
    local f=$2

    if [ $1 = "rm" ]; then
	rm ${f}*
	echo $f
    else
        local fl=$(ls -l ${f}* | awk '{print $NF}' | sort | tail -n 1)
        echo ${fl}1
    fi
}

capitalize () {
    local w=$1
    local c=$(echo ${w:0:1})
    echo $(echo $c | tr [a-z] [A-Z])$(echo ${w:1})
}

get_file_absolute_path() {
	local cur_dir=$(pwd)
	cd $(dirname $1)
	echo "$(pwd)/$(basename $1)"
	cd $cur_dir
}
