#!/usr/bin/env bash 
# Created: 21 Jun 2022 3:33:43pm 
# Author: Manos Lefakis 
# set -x 
# depends on: https://github.com/pomfort/mhl-tool 

if [ $SUDO_USER ]; then
	USER=$SUDO_USER 
else 
	USER=`whoami` 
fi 
DIR=/media/$USER/ 
#DIR=$(pwd)
#DIR=$DIR/test


fzf_options="--header-first --padding=4 --margin=10 --height=100%"
fzf_options=`echo $fzf_options`

ask_drive() {
	diskList=`find $DIR -maxdepth $1 -type d | sort -u`
	ask "$2" "$diskList"
}

ask() {
	while [ ! "$selection" ]; do
		selection=`echo $2 Exit|tr " " "\n"| fzf $fzf_options --prompt="$1" --header="Go copy that shit, and do it right!" `
		if [ "$selection" == "Exit" ]; then
			exit 69 
		fi
	done
	echo $selection
}

mk_card_dir() {
	c_dirs=$(ls $1 | grep C)
	c_idx=$(echo $c_dirs | tr -d "C" |tr " " "\n"| sort -n)
	for idx in $c_idx; do
		last=$idx
	done;
	new_idx=$((last+1))
	new_cdir="C$new_idx"
	mkdir $1/$new_cdir
	realpath $1/$new_cdir
}

mk_audio_dir() {
	new_adir="Audio"
	mkdir $1/$new_adir
	realpath $1/$new_adir
}

diff_everything() {
	sources=$(ls $1)
	for s in $sources; do
		if [ -f $1/$s ]; then
			diff -qrs $1/$s $2/$s
		fi
	done;
}

source_dir=$(ask_drive 3 "Select source card")
[[ $? -eq 69 ]] && exit 0

destination_dir=$(ask_drive 2 "Select destination disk")
[[ $? -eq 69 ]] && exit 0

is_initialized=$(ls $destination_dir)
if [[ -z $is_initialized  ]]; then
	base_dir=$(echo | fzf $fzf_options --print-query --prompt="Name of folder: " --header="Go copy that shit, and do it right!" )
	destination_dir=$destination_dir/$base_dir
	mkdir $destination_dir
else
	destination_dir=$destination_dir/$is_initialized
fi;

op_mode_opts="video audio"
op_mode=$(ask "What are you copying? " "$op_mode_opts")
[[ $? -eq 69 ]] && exit 0

dst=$(basename $destination_dir)
src=$(basename $source_dir)
opts="Yes No"
confirmation=$(ask "Copy $op_mode from $src to $dst, go for it?" "$opts")
[[ $? -eq 69 ]] && exit 0
[[ $confirmation = "No" ]] && exit 1

if [[ $op_mode = "video" ]]; then
	actual_destination=$(mk_card_dir $destination_dir/)
else
	actual_destination=$(mk_audio_dir $destination_dir/)
fi

echo "Copying from $source_dir to $actual_destination"
rsync -r -t -v --progress -c -H -i -s $source_dir/ $actual_destination
diff_everything $source_dir $actual_destination
mhl seal -o $actual_destination $actual_destination
