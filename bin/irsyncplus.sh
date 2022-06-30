#!/usr/bin/env bash 
# Created: 21 Jun 2022 3:33:43pm 
# Author: Manos Lefakis 
# set -x 
# depends on: https://github.com/pomfort/mhl-tool 

# trap "exit 1" TERM
export TOP_PID=$$

use_sudo=""
if [ $SUDO_USER ]; then
	USER=$SUDO_USER 
else 
	USER=`whoami` 
	use_sudo=sudo
fi 

# ad a pointless comment
if [[ $# -eq 1 ]]; then
	case $1 in
		update)
			ping -c1 github.com
			if [[ $? -ne 0 ]]; then 
				echo Maybe you are not connected to the internet
				echo Check your connection and try again
				exit 1
			fi
			pushd $(dirname $(dirname $(realpath $0)))
			git remote update && git status | grep "git pull"
			is_up_to_date=$?
			echo $is_up_to_date
			if [[ $is_up_to_date -eq 0 ]]; then
				echo updating irsyncplus...
				git pull
				$use_sudo make install
				if [[ $? -ne 0 ]]; then 
					echo Something went wrong during installation
					exit 1
				fi
			else 
				echo irsyncplus is up to date
			fi
			popd
			exit 0
			;;
		help | --help | -h)
			echo "Just run:"
			echo "	$ doit"
			echo ""
			echo "Options:"
			echo "	update		installs updates"
			echo "	help		prints this message"
			exit 0
			;;
		*)
			echo $@ 
			echo what do you mean with that?
			echo I don\'t know what to do, goodbuy
			echo run with option help
			echo "	 doit help\n"
			exit 1
			;;
	esac
fi

[[ -d /run/media/$USER ]] && DIR=/run/media/$USER/ 
[[ -d /media/$USER ]] && DIR=/media/$USER/ 
#DIR=$(pwd)
#DIR=$DIR/test

fzf_header="Go copy that shit, and do it right!" 

fzf_options="--layout=reverse --header-first --padding=1 --margin=1 --height=100% --scroll-off=3 --border"
fzf_options=`echo $fzf_options`

ask_drive() {
	diskList=`find $DIR -maxdepth $1 -mindepth 1 -type d | sort -u`
	ask "$2" "$diskList"
}

confirm() {
	opts="Yes No"
	if [[ "$(ask "$1" "$opts")" = "Yes" ]]; then
		return 0
	else
		return 1
	fi
}

ask() {
	while [ ! "$selection" ]; do
		selection=`echo $2 Exit|tr " " "\n"| fzf $fzf_options --prompt="$1: " --header="$fzf_header"`
		if [ "$selection" == "Exit" ]; then
			kill -s TERM $TOP_PID
		fi
	done
	echo $selection
}

mk_card_dir() {
	c_dirs=$(ls $1 | grep C)
	c_idx=$(echo $c_dirs | tr -d "C" |tr " " "\n"| sort -n)
	for idx in $c_idx; do
		[[ $idx =~ ^[0-9]+$ ]] && last=$idx
	done;
	new_idx=$((last+1))
	new_cdir="C$new_idx"
	confirm "$new_cdir will be created. Continue or create your own?" ||
		new_cdir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="Go copy that shit, and do it right!" | tr " " "_" )
	#mkdir $1/$new_cdir
	realpath $1/$new_cdir
}

mk_custom_dir() {
	existing_dirs=`find $1 -maxdepth 3 -mindepth 1 -type d | sort -u | xargs -n1 basename`
	existing_dirs="$existing_dirs CREATE_NEW_DIRECTORY"
	custom_dir=$(ask "Select an existing directory or create a new one" "$existing_dirs")
	[[ "$custom_dir" = "CREATE_NEW_DIRECTORY" ]] &&
		custom_dir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="Go copy that shit, and do it right!" | tr " " "_")
	realpath $1/$custom_dir
}

mk_audio_dir() {
	new_adir="Audio"
	#mkdir $1/$new_adir
	confirm "$new_adir will be created. Continue or create your own?" ||
		new_adir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="Go copy that shit, and do it right!" | tr " " "_" )
	realpath $1/$new_adir
}

diff_everything() {
	sources=$(ls $1)
	echo 
	echo diffing the files...
	for s in $sources; do
		if [ -f $1/$s ]; then
			diff -qrs $1/$s $2/$s
		fi
	done;
}

# select source disk/sd card. It could be a subdirectory
source_dir=$(ask_drive 3 "Select source directory")

# select destination disk
destination_dir=$(ask_drive 1 "Select destination disk")

fzf_header="Select/generate base directery" 
#select or create a base dir on target disk
is_initialized=$(find $destination_dir -maxdepth 1 -mindepth 1 -type d | sort -u | wc -l)
if [[ $is_initialized = "0"  ]]; then
	# empty disk. create new dir
	base_dir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="$fzf_header" | tr " " "_")
	destination_dir=$destination_dir/$base_dir
elif [[ $is_initialized = "1"  ]]; then
	# initialized disk with 1 subdirectory (as expected)
	base_dir=$(find $destination_dir -maxdepth 1 -mindepth 1 -type d | sort -u)
	confirm "Directory $(basename $base_dir) found on Disk. Continue in it?" || 
		base_dir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="$fzf_header" | tr " " "_")
	destination_dir=$destination_dir/$(basename $base_dir)
else
	# initialized with more than 1 directory (maybe containing other data also)
	base_dirs=$(find $destination_dir -maxdepth 1 -mindepth 1 -type d | xargs -n1 basename | sort -u)
	base_dirs="$base_dirs CREATE_NEW_DIRECTORY"
	base_dir=$(ask "more than one dir found. select one or create a new" "$base_dirs")
	[[ "$base_dir" = "CREATE_NEW_DIRECTORY" ]] &&
		base_dir=$(echo | fzf $fzf_options --print-query --prompt="Name of new directory: " --header="$fzf_header" | tr " " "_")
	 
	destination_dir=$destination_dir/$(basename $base_dir)
fi;

dst=$(basename $destination_dir)
src=$(basename $source_dir)
fzf_header="Select/generate target directery" 
op_mode_opts="video audio manual"
op_mode=$(ask "What mode d'you want? " "$op_mode_opts")

msg="Copy $op_mode from $src to $dst, go for it?"
confirm "$msg" || exit 1

[[ -d $destination_dir ]] || mkdir $destination_dir
if [[ $op_mode = "video" ]]; then
	actual_destination=$(mk_card_dir $destination_dir/)
elif [[ $op_mode = "audio" ]]; then
	actual_destination=$(mk_audio_dir $destination_dir/)
else
	actual_destination=$(mk_custom_dir $destination_dir/)
fi

fzf_header="" 
confirm "Copying from $source_dir to $actual_destination" || exit 1
[[ -d $actual_destination ]] || mkdir $actual_destination
confirm "Do you want to copy safely?" && checksum="-c"
diff=no
confirm "Do you want to check copied files integrity after transfer? (I do not recoment to choose No in case you've disabled safe copy on last step)" && diff=yes
sign=no
confirm "Do you want to generate mhl file?" && sign=yes

rsync -r -t -v --progress $checksum -H -i -s $source_dir/ $actual_destination

[[ $diff = "yes" ]] && diff_everything $source_dir $actual_destination
[[ $sign = "yes" ]] && mhl seal -o $actual_destination $actual_destination
