#!/bin/sh
SELECTED_INSTALL=0
SERVER="sourceforge.net"
if [ "$1" != "" ]; then
	AUTODETECTIP=0
	URLUPDATELOCAL="$1"
else
	AUTODETECTIP=1
	URLUPDATELOCAL="http://192.168.0.1/updatev1.sh"
fi
URLUPDATE="http://kernelloader.sourceforge.net/installer/updatev1.sh"

dmesg -n 3

# Disable screen saver
echo -e "\033[9;0]"

################################################################################
#
# Basic menu functionaility 
#
################################################################################

clear_screen()
{
	echo -e '\0033\0143'
	echo
	echo
	echo
	echo
	echo
}

print_indent()
{
	if [ "$1" != "" ]; then
		echo -e "         $1"
	else
		echo -n "         "
	fi
}

################################################################################
#
# Gamepad input
#
################################################################################

get_input()
{
	if [ -e /proc/ps2pad ]; then
		# Check gamepad in first slot:
		INPUT=""
		BUTTONS=""
		while [ "${BUTTONS:0:4}" != "FFFF" ]; do
			BUTTONS="$(head -n 2 /proc/ps2pad | tail -n 1 | cut -b 32-36)"
		done
		while [ "$INPUT" = "" ]; do
			BUTTONS="$(head -n 2 /proc/ps2pad | tail -n 1 | cut -b 32-36)"
			case ${BUTTONS:0:4} in
				FFBF)
					INPUT="X"
					;;
				FFDF)
					INPUT="O"
					;;
				FFEF)
					INPUT="T"
					;;
				EFFF)
					INPUT="UP"
					;;
				BFFF)
					INPUT="DOWN"
					;;
			esac
		done
	else
		read INPUT
	fi
}

wait_for_XOT()
{
	INPUT=""
	while [ "$INPUT" != "X" -a "$INPUT" != "O" -a "$INPUT" != "T" ]; do
		get_input
	done
}

wait_for_XO()
{
	INPUT=""
	while [ "$INPUT" != "X" -a "$INPUT" != "O" ]; do
		get_input
	done
}

wait_for_X()
{
	INPUT=""
	while [ "$INPUT" != "X" ]; do
		get_input
	done
}

################################################################################
#
# Basic menu functions
#
################################################################################

print_menu()
{
	local MENUTITLE="$1"
	local MENU_MIN=$2
	local MENU_MAX=$3
	local MENU_SELECTED=$4
	clear_screen
	print_indent "$MENUTITLE"
	echo
	local i=$MENU_MIN
	while [ $i -lt $MENU_MAX ]; do
		eval "MENUENTRY=\"\$MENUENTRY$i\""
		print_indent
		if [ $i -eq $MENU_SELECTED ]; then
			echo -ne "-> \e[0;33m"
		else
			echo -n "   "
		fi
		echo -ne "$i) $MENUENTRY"
		echo -e "\e[0m"
		i=$(expr $i + 1)
	done
	echo
	print_indent "\e[0;32mHold X to continue.\e[0m"
	print_indent "\e[0;32mHold O to cancel\e[0m"
}

select_menu()
{
	local MENUTITLE="$1"
	local MENU_MIN=$2
	local MENU_MAX=$3
	local MENU_SELECTED=$4

	if [ $MENU_SELECTED -ge $MENU_MAX ]; then
		MENU_SELECTED=$(expr $MENU_MAX - 1)
	fi
	if [ $MENU_SELECTED -lt $MENU_MIN ]; then
		MENU_SELECTED="$MENU_MIN"
	fi
	print_menu "$MENUTITLE" $MENU_MIN $MENU_MAX $MENU_SELECTED
	INPUT=""
	while [ "$INPUT" != "X" -a "$INPUT" != "O" ]; do
		get_input
		if [ "$INPUT" = "DOWN" ]; then
			MENU_SELECTED=$(expr $MENU_SELECTED + 1)
			if [ $MENU_SELECTED -ge $MENU_MAX ]; then
				MENU_SELECTED=$(expr $MENU_MAX - 1)
			fi
		fi
		if [ "$INPUT" = "UP" ]; then
			MENU_SELECTED=$(expr $MENU_SELECTED - 1)
			if [ $MENU_SELECTED -lt $MENU_MIN ]; then
				MENU_SELECTED=$MENU_MIN
			fi
		fi
		print_menu "$MENUTITLE" $MENU_MIN $MENU_MAX $MENU_SELECTED
	done

	if [ "$INPUT" = "X" ]; then
		return $MENU_SELECTED
	else
		return 255
	fi
}

################################################################################
#
# Error handling
#
###############################################################################

install_cleanup()
{
	umount /mnt/dos 2>/dev/null 1>&2
	umount /mnt/disk 2>/dev/null 1>&2
	umount /mnt/mc 2>/dev/null 1>&2

	if [ "$SWAPDEVICE" != "" ]; then
		swapoff "$SWAPDEVICE" 2>/dev/null 1>&2
	fi
}


error_exit()
{
	set +x
	sleep 3
	install_cleanup

	print_indent "\e[0;32mHold X to continue.\e[0m"
	echo
	echo
	echo
	echo
	echo
	INPUT=""
	while [ "$INPUT" != "X" ]; do
		get_input
	done
	clear_screen
	print_indent "An error happened."
	print_indent "\e[0;32mHold X to power off.\e[0m"
	INPUT=""
	while [ "$INPUT" != "X" ]; do
		get_input
	done
	halt
	exit 1
}

################################################################################
#
# Basic state machine functions
#
###############################################################################

state_reset()
{
	STATE="welcome"
	STEP=0
}

state_set()
{
	# Always clear screen when changing state.
	clear_screen

	eval "PREVSTATE$STEP=\"$STATE\""
	STEP=$(expr $STEP + 1)
	STATE="$1"
}

state_back()
{
	if [ $STEP -gt 0 ]; then
		STEP=$(expr $STEP - 1)
		eval "STATE=\"\$PREVSTATE$STEP\""
	else
		state_reset
	fi
}

################################################################################
#
# Helper functions
#
###############################################################################

show_info()
{
	clear_screen
	print_indent "This will install Linux on the Sony Playstation 2."
	print_indent "An internet connection is required."
	echo
	print_indent "\e[0;32mHold X to continue\e[0m"
	print_indent "\e[0;32mHold O to power off\e[0m"
	echo
	print_indent "Don't just press the buttons on the first game pad,"
	print_indent "you need to hold them after pressing as the buttons"
	print_indent "are only polled."
	print_indent "You can press UP and DOWN to select a differnt option."
	echo
	print_indent "\e[0;32mIt is recommended to just press X for all questions,\e[0m"
	print_indent "\e[0;32mthe defaults will work, but may delete all data on the\e[0m"
	print_indent "\e[0;32mselected device. So please make a backup before\e[0m"
	print_indent "\e[0;32mrunning this.\e[0m"
	print_indent "\e[0;32mThis will not harm your PS2. You will still be able\e[0m"
	print_indent "\e[0;32mto play games.\e[0m"

	wait_for_XO
	if [ "$INPUT" = "O" ]; then
		halt
		exit 1
	fi
}

show_install_info()
{
	clear_screen
	print_indent "This will install the following $INSTALLNAME:"
	echo
	print_indent "\e[0;33mFile system archive:\e[0m"
	print_indent "$URLBASE"
	print_indent "Archive: $TGZFILE"
	local VAL=$(expr $MINPARTSIZE / 1048576)
	print_indent "Required size on hard disc ${VAL}MiB"
	local VAL=$(expr $SPLITSIZE / 1048576)
	print_indent "Recommended size ${VAL}MiB on hard disc"
	echo
	print_indent "\e[0;33mKernel:\e[0m"
	print_indent "$URLKERNBASE"
	print_indent "File: $KERNFILE"
	print_indent "Size $KERNSIZE"
	echo
	print_indent "\e[0;32mHold X to continue\e[0m"
	print_indent "\e[0;32mHold O to cancel\e[0m"
	wait_for_XO
	if [ "$INPUT" = "X" ]; then
		state_set "select_install_disk"
	else
		state_back
	fi
}

# Returns number of disks found + 1.
search_disks()
{
	local IGNOREMC=$1

	local FOUND=0
	local FOUNDMC=0
	parted -s -m -l >/tmp/disklist.txt 2>/dev/null

	exec 6<&0
	# Redirect STDIN to output of parted:
	exec < /tmp/disklist.txt
	local i=1
	while read line; do
		if [ $FOUND -eq 1 ]; then
			local DISK="$(echo "$line" | cut -d ':' -f 1)"
			local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")
			local DISKSIZE="$(echo "$line" | cut -d ':' -f 2)"
			local FORMAT="$(echo "$line" | cut -d ':' -f 6)"
			local LABEL="$(echo "$line" | cut -d ':' -f 7)"
			if [ "${DEV:0:5}" = "ps2mc" ]; then
				LABEL="Memory card in slot ${DEV:5:1}"
			fi
			# Don't show memory cards.
			if [ $IGNOREMC -eq 1 -a "${DEV:0:5}" != "ps2mc" ]; then
				eval "DISK$i=\"$DISK\""
				eval "DISKSIZE$i=\"$DISKSIZE\""
				eval "DISKFORMAT$i=\"$FORMAT\""
				eval "DISKLABEL$i=\"$LABEL\""
				eval "MENUENTRY$i=\"$i $DISK $DISKSIZE $FORMAT $LABEL\""
				FOUNDMC=1
				i=$(expr $i + 1)
			fi
			if [ $IGNOREMC -eq 0 -a "${DEV:0:2}" != "hd" ]; then
				eval "DISK$i=\"$DISK\""
				eval "DISKSIZE$i=\"$DISKSIZE\""
				eval "DISKFORMAT$i=\"$FORMAT\""
				eval "DISKLABEL$i=\"$LABEL\""
				if [ "${DEV:0:5}" = "ps2mc" ]; then
					eval "MENUENTRY$i=\"$i $DISK $LABEL\""
				else
					eval "MENUENTRY$i=\"$i $DISK $DISKSIZE $FORMAT $LABEL\""
				fi
				i=$(expr $i + 1)
			fi
			FOUND=0
		fi
		if [ "$line" = "BYT;" ]; then
			FOUND=1
		fi
	done
	# Restore STDIN
	exec 0<&6 6<&-

	if [ $IGNOREMC -eq 0 ]; then
		if [ $FOUNDMC -ne 1 ]; then
			# Memory card was not found by parted, add entry for these:
			DISK="/dev/ps2mc00"
			eval "DISK$i=\"$DISK\""
			eval "DISKSIZE$i=\"8MiB\""
			eval "DISKFORMAT$i=\"ps2mcfs\""
			LABEL="Memory card in slot 0"
			eval "DISKLABEL$i=\"$LABEL\""
			eval "MENUENTRY$i=\"$i $DISK $LABEL\""
			i=$(expr $i + 1)

			DISK="/dev/ps2mc10"
			eval "DISK$i=\"$DISK\""
			eval "DISKSIZE$i=\"8MiB\""
			eval "DISKFORMAT$i=\"ps2mcfs\""
			LABEL="Memory card in slot 1"
			eval "DISKLABEL$i=\"$LABEL\""
			eval "MENUENTRY$i=\"$i $DISK $LABEL\""
			i=$(expr $i + 1)
		fi
	fi
	
	return $i
}

# Try to get all disks connected.
# Returns number of disks found + 1.
check_disk()
{
	local IGNOREMC=$1

	local MAX=0
	INPUT="X"
	while [ $MAX -le 1 -a "$INPUT" = "X" ]; do
		search_disks $IGNOREMC
		MAX=$?
		if [ $MAX -le 1 ]; then
			clear_screen
			print_indent "No disk found."
			print_indent "Please connect USB storage device."
			echo

			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
		fi
	done
	return $MAX
}

search_partitions()
{
	local DISK="$1"
	local FOUND=0

	print_indent "Detecting partitions..."
	parted -s -m $DISK unit B print>/tmp/partlist.txt 2>/dev/null
	exec 6<&0
	exec < /tmp/partlist.txt
	local i=0
	print_indent "Reading partitions..."
	while read line; do
		if [ $i -gt 0 ]; then
			local PART="$(echo "$line" | cut -d ':' -f 1)"
			local PARTSTART="$(echo "$line" | cut -d ':' -f 2)"
			local PARTEND="$(echo "$line" | cut -d ':' -f 3)"
			local PARTSIZE="$(echo "$line" | cut -d ':' -f 4)"
			local PARTSIZE=$(echo $PARTSIZE | sed -e "s-B\$--g")
			local PARTFORMAT="$(echo "$line" | cut -d ':' -f 5)"
			eval "PART$i=\"\$PART\""
			eval "PARTSIZE$i=\"\$PARTSIZE\""
			eval "PARTFORMAT$i=\"\$PARTFORMAT\""
			eval "PARTSTART$i=\"\$PARTSTART\""
			eval "PARTEND$i=\"\$PARTEND\""
			PARTSIZE=$(expr $PARTSIZE / 1048576)
			eval "MENUENTRY$i=\"${DISK}$PART ${PARTSIZE}MiB $PARTFORMAT\""

			i=$(expr $i + 1)
		fi
		if [ $FOUND -eq 1 ]; then
			PARTDISKSIZE="$(echo "$line" | cut -d ':' -f 2)"
			i=$(expr $i + 1)
			FOUND=0
		fi
		if [ "$line" = "BYT;" ]; then
			FOUND=1
		fi
	done
	exec 0<&6 6<&-
	
	return $i
}

split_partition()
{
	local DISK="$1"
	local PART="$2"
	local PARTSTART="$3"
	local PARTEND="$4"

	local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")
	local BLOCKSIZE=$(cat /sys/block/$DEV/queue/physical_block_size)

	# Round:
	local CHANGE=$(expr $SPLITSIZE / $BLOCKSIZE)
	CHANGE=$(expr $CHANGE \* $BLOCKSIZE)

	local END=$(echo $PARTEND | sed -e "s-B\$--g")
	END=$(expr $END - $CHANGE)

	set -x
	parted -s -m "$DISK" resize $PART "$PARTSTART" "${END}B"
	RESULT=$?
	set +x

	local START=$(expr $END + 1)

	if [ $RESULT -eq 0 ]; then
		set -x
		parted -s -m $DISK mkpart primary ext2 ${START}B $PARTEND
		RESULT=$?
		set +x
	fi

	if [ $RESULT -ne 0 ]; then
		print_indent "Failed to split the partition"
	fi
	echo
	print_indent "\e[0;32mHold X to continue.\e[0m"
	wait_for_X
}

create_partition()
{
	local DISK="$1"
	local PARTSTART="$2"
	local PARTEND="$3"

	set -x
	parted -s -m $DISK mkpart primary ext2 ${PARTSTART}B ${PARTEND}B
	RESULT=$?
	set +x

	if [ $RESULT -ne 0 ]; then
		print_indent "Failed to split the partition"
	fi
	echo
	print_indent "\e[0;32mHold X to continue.\e[0m"
	wait_for_X
}

################################################################################
#
# States
#
###############################################################################

state_welcome()
{
	show_info
	state_set "server_check"
}

state_server_check()
{
	PINGFAIL=1
	INPUT="X"
	while [ $PINGFAIL -ne 0 -a "$INPUT" = "X" ]; do
		ping -c 3 $SERVER
		PINGFAIL=$?
		if [ $PINGFAIL -ne 0 ]; then
			clear_screen
			print_indent "Ping failed, please setup DHCP server and"
			print_indent "connect network cable."
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			print_indent "\e[0;32mHold TRIANGLE to ignore\e[0m"
			wait_for_XOT
		fi
	done

	case $INPUT in
		X|T)
			state_set "select_install"
			;;
		O)
			state_back
			;;
	esac
}

get_install()
{
	local MAX=1

	local JUHUTUBEBASE="http://$SERVER/projects/kernelloader/files/Juhutube/v2"
	local JUHUTUBEBASE3="http://$SERVER/projects/kernelloader/files/Juhutube/v3"

	eval "INSTALLNAME$MAX=\"Linux YouTube Player v3\""
	eval "SPLITSIZE$MAX=167772160"
	eval "MINPARTSIZE$MAX=104857600"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"ps2juhutube-image-v3.tgz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLBASE$MAX=\"$JUHUTUBEBASE3\""
	eval "URLKERNBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "MENUENTRY$MAX=\"Install Juhutube an YouTube Player v3 (default)\""
	eval "MAX=$(expr $MAX + 1)"

	eval "INSTALLNAME$MAX=\"Linux YouTube Player v2\""
	eval "SPLITSIZE$MAX=167772160"
	eval "MINPARTSIZE$MAX=104857600"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"ps2juhutube-image-v2.tgz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERNBASE$MAX=\"\$URLBASE$MAX\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "MENUENTRY$MAX=\"Install Juhutube an YouTube Player v2\""
	eval "MAX=$(expr $MAX + 1)"

	eval "INSTALLNAME$MAX=\"Debian 5.0 v1\""
	eval "SPLITSIZE$MAX=629145600"
	eval "MINPARTSIZE$MAX=419430400"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"debian-lenny-mipsel-v1.tgz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLKERNBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLBASE$MAX=\"http://$SERVER/projects/kernelloader/files/Debian%205.0/\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "MENUENTRY$MAX=\"Install Debian 5.0 mipsel v1\""
	eval "MAX=$(expr $MAX + 1)"

	eval "INSTALLNAME$MAX=\"Debian 5.0 v2\""
	eval "SPLITSIZE$MAX=629145600"
	eval "MINPARTSIZE$MAX=419430400"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"debian-lenny-mipsel-v2.tgz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLKERNBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLBASE$MAX=\"http://$SERVER/projects/kernelloader/files/Debian%205.0/\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "MENUENTRY$MAX=\"Install Debian 5.0 mipsel v2 (preconfigured network)\""
	eval "MAX=$(expr $MAX + 1)"

	eval "INSTALLNAME$MAX=\"Fedora Core 12\""
	eval "SPLITSIZE$MAX=1887436800"
	eval "MINPARTSIZE$MAX=1258291200"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"fedora-12-n32-rootfs-20100414.tar.gz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLKERNBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLBASE$MAX=\"http://files.gbraad.nl/fedora/mips/Fedora-12-rootfs-MIPS\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "MENUENTRY$MAX=\"Fedora Core 12 (experts only)\""
	eval "MAX=$(expr $MAX + 1)"

	eval "INSTALLNAME$MAX=\"Fedora Core 13\""
	eval "SPLITSIZE$MAX=1887436800"
	eval "MINPARTSIZE$MAX=1258291200"
	eval "SWAPSIZE$MAX=134217728"
	eval "TGZFILE$MAX=\"fedora-13-n32-rootfs-20100710.tar.gz\""
	eval "KERNFILE$MAX=\"vmlinux_juhutube_v2.gz\""
	eval "KERNSIZE$MAX=\"2.4MiB\""
	eval "URLKERNBASE$MAX=\"$JUHUTUBEBASE\""
	eval "URLKERN$MAX=\"\$URLKERNBASE$MAX/\$KERNFILE$MAX\""
	eval "URLBASE$MAX=\"http://files.gbraad.nl/fedora/mips/Fedora-13-rootfs-MIPS\""
	eval "URLTGZ$MAX=\"\$URLBASE$MAX/\$TGZFILE$MAX\""
	eval "MENUENTRY$MAX=\"Fedora Core 13 (experts only, may not install)\""
	eval "MAX=$(expr $MAX + 1)"

	return $MAX
}

state_show_install()
{
	show_install_info
}

state_select_install_disk()
{
	local SELECTED_DISK=1
	check_disk 1
	local MAX=$?

	if [ $MAX -gt 1 ]; then
		local SURE=n
		while [ "$SURE" != "y" ]; do
			select_menu "Please select a disk for installation:" 1 $MAX $SELECTED_DISK
			SELECTED_DISK=$?
			if [ $SELECTED_DISK -gt $MAX ]; then
				state_back
				break
			fi
			eval "DISK=\"\$DISK$SELECTED_DISK\""
			eval "DISKSIZE=\"\$DISKSIZE$SELECTED_DISK\""
			eval "DISKFORMAT=\"\$DISKFORMAT$SELECTED_DISK\""
			eval "DISKLABEL=\"\$DISKLABEL$SELECTED_DISK\""
			clear_screen
			print_indent "Are you sure to use the following disk?"
			echo
			print_indent "Device $DISK"
			print_indent "Size $DISKSIZE"
			print_indent "Partition table format $DISKFORMAT"
			print_indent "Label $DISKLABEL"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			print_indent "\e[0;32mHold O to cancel.\e[0m"
			print_indent "\e[0;32mHold TRIANGLE to retry\e[0m"
			get_input
			if [ "$INPUT" = "X" ]; then
				state_set "select_kernel_disk"
				SURE="y"
			fi
			if [ "$INPUT" = "T" ]; then
				break
			fi
		done
	else
		state_back
	fi
}

state_select_kernel_disk()
{
	check_disk 0
	local MAX=$?

	local i=1

	# Prefer to install kernel to same disk:
	while [ $i -lt $MAX ]; do
		eval "KERNDISK=\"\$DISK$i\""
		if [ "$KERNDISK" = "$DISK" ]; then
			SELECTED_DISK="$i"
			break
		fi
		i=$(expr $i + 1)
	done
	KERNDISK=""

	local NOINSTALL="$MAX"
	eval "MENUENTRY$MAX=\"Don't install kernel\""
	MAX=$(expr $MAX + 1)

	local SELECTED_DISK=1
	local SURE=n
	while [ "$SURE" != "y" ]; do
		select_menu "Please select where to install the kernel:" 1 $MAX $SELECTED_DISK
		SELECTED_DISK=$?
		if [ $SELECTED_DISK -gt $MAX ]; then
			state_back
			break
		fi
		if [ $SELECTED_DISK -eq $NOINSTALL ]; then
			# Don't install kernel.
			SURE="y"
			KERNDISK=""
			KERNDEVICE=""
			KERNDISKSIZE=""
			KERNDISKFORMAT=""
			KERNDISKLABEL=""
			DESTKERN="mc0:kloader"
			state_set select_install_partition
		else
			eval "KERNDISK=\"\$DISK$SELECTED_DISK\""
			eval "KERNDISKSIZE=\"\$DISKSIZE$SELECTED_DISK\""
			eval "KERNDISKFORMAT=\"\$DISKFORMAT$SELECTED_DISK\""
			eval "KERNDISKLABEL=\"\$DISKLABEL$SELECTED_DISK\""
			local DEV=$(echo "$KERNDISK" | sed -e "s#/dev/##g")
			clear_screen
			print_indent "Are you sure to use the following disk?"
			echo
			print_indent "Device $KERNDISK"
			if [ "${DEV:0:5}" != "ps2mc" ]; then
				print_indent "Size $KERNDISKSIZE"
				print_indent "Partition table format $KERNDISKFORMAT"
			fi
			print_indent "Label $KERNDISKLABEL"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			print_indent "\e[0;32mHold O to cancel.\e[0m"
			print_indent "\e[0;32mHold TRIANGLE to retry\e[0m"
			get_input
			if [ "$INPUT" = "X" ]; then
				if [ "${DEV:0:7}" = "ps2mc00" ]; then
					DESTKERN="mc0:kloader"
					KERNDEVICE="$KERNDISK"
				else
					if [ "${DEV:0:7}" = "ps2mc10" ]; then
						DESTKERN="mc1:kloader"
						KERNDEVICE="$KERNDISK"
					else
						DESTKERN=""
					fi
				fi
				state_set select_install_partition
				SURE="y"
			fi
			if [ "$INPUT" = "T" ]; then
				break
			fi
		fi
	done
}

state_select_install_partition()
{
	local DISK="$1"
	local SIZE="$2"
	local LABEL="$3"

	DEVICE=""
	SWAPDEVICE=""

	local SELECTED_PART=0
	search_partitions "$DISK"
	local MAX=$?

	if [ $MAX -lt 1 ]; then
		MAX=1
	fi
	# Prefer to install kernel to first unformatted partition:
	local i=1
	while [ $i -lt $MAX ]; do
		eval "PARTFORMAT=\"\$PARTFORMAT$i\""
		if [ "${PARTFORMAT}" = "" ]; then
			eval "DEVICESIZE=\"\$PARTSIZE$i\""
			if [ $DEVICESIZE -ge $MINPARTSIZE ]; then
				SELECTED_PART="$i"
				break
			fi
		fi
		if [ "${PARTFORMAT:0:10}" = "linux-swap" ]; then
			eval "PART=\"\$PART$i\""
			SWAPDEVICE="${DISK}$PART"
		fi
		i=$(expr $i + 1)
	done
	if [ $SELECTED_PART -eq 0 ]; then
		# No partition found, try to find an ext2 partition:
		local i=1
		while [ $i -lt $MAX ]; do
			eval "PARTFORMAT=\"\$PARTFORMAT$i\""
			if [ "${PARTFORMAT:0:4}" = "ext2" ]; then
				eval "DEVICESIZE=\"\$PARTSIZE$i\""
				if [ $DEVICESIZE -ge $MINPARTSIZE ]; then
					SELECTED_PART="$i"
					break
				fi
			fi
			i=$(expr $i + 1)
		done
	fi
	if [ $SELECTED_PART -eq 0 ]; then
		# No partition found, try to find an ext2/3/4 partition:
		local i=1
		while [ $i -lt $MAX ]; do
			eval "PARTFORMAT=\"\$PARTFORMAT$i\""
			if [ "${PARTFORMAT:0:3}" = "ext" ]; then
				eval "DEVICESIZE=\"\$PARTSIZE$i\""
				if [ $DEVICESIZE -ge $MINPARTSIZE ]; then
					SELECTED_PART="$i"
					break
				fi
			fi
			i=$(expr $i + 1)
		done
	fi

	# Try to find free space for new partitions:
	local REALMAX=$MAX
	local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")
	local OPTIMALIOSIZE=$(cat /sys/block/$DEV/queue/optimal_io_size)
	local MINIMALIOSIZE=$(cat /sys/block/$DEV/queue/minimum_io_size)
	local BLOCKSIZE=$(cat /sys/block/$DEV/queue/physical_block_size)
	local ALIGNOFF=$(cat /sys/block/$DEV/alignment_offset)
	local START=$OPTIMALIOSIZE
	if [ $START -lt $MINIMALIOSIZE ]; then
		START=$MINIMALIOSIZE
	fi
	START=$(expr $START + $ALIGNOFF)
	local FIRSTSECTOR=$(expr $START / $BLOCKSIZE)
	if [ $FIRSTSECTOR -lt 2048 ]; then
		FIRSTSECTOR=2048
	fi
	START=$(expr $FIRSTSECTOR \* $BLOCKSIZE)

	local MINEND=0
	local DISCEND=$(echo $PARTDISKSIZE | sed -e "s-B\$--g")
	local MAXSTART=$DISCEND
	local i=1
	while [ $i -lt $MAX ]; do
		eval "PARTSTART=\"\$PARTSTART$i\""
		PARTSTART=$(echo $PARTSTART | sed -e "s-B\$--g")
		eval "PARTEND=\"\$PARTEND$i\""
		PARTEND=$(echo $PARTEND | sed -e "s-B\$--g")

		if [ $PARTSTART -lt $MAXSTART ]; then
			MAXSTART=$PARTSTART
		fi
		if [ $PARTEND -gt $MINEND ]; then
			MINEND=$PARTEND
		fi
		i=$(expr $i + 1)
	done
	MINEND=$(expr $MINEND + $BLOCKSIZE - 1)
	MINEND=$(expr $MINEND / $BLOCKSIZE)
	MINEND=$(expr $MINEND \* $BLOCKSIZE)
	ALIGNSIZE=$(expr $MINPARTSIZE / $BLOCKSIZE)
	ALIGNSIZE=$(expr $ALIGNSIZE \* $BLOCKSIZE)
	local VAL=$(expr $MINEND + $ALIGNSIZE)
	if [ $DISCEND -ge $VAL ]; then
		# There is enough room for another partition:

		eval "MENUENTRY$REALMAX=\"Create new partition at the end with min size\""
		eval "PARTSTART$REALMAX=\"$MINEND\""
		VAL=$(expr $VAL - 1)
		eval "PARTEND$REALMAX=\"$VAL\""
		REALMAX=$(expr $REALMAX + 1)

		eval "MENUENTRY$REALMAX=\"Create new partition at the end with max size\""
		eval "PARTSTART$REALMAX=\"$MINEND\""
		VAL=$(expr $VAL - 1)
		eval "PARTEND$REALMAX=\"100%\""
		if [ $SELECTED_PART -eq 0 ]; then
			SELECTED_PART=$REALMAX
		fi
		REALMAX=$(expr $REALMAX + 1)
	fi

	local VAL=$(expr $START + $ALIGNSIZE)
	if [ $VAL -le $MAXSTART ]; then
		# There is enough room for another partition:
		eval "MENUENTRY$REALMAX=\"Create new partition at the start with min size\""
		eval "PARTSTART$REALMAX=\"$START\""
		VAL=$(expr $VAL - 1)
		eval "PARTEND$REALMAX=\"$VAL\""
		REALMAX=$(expr $REALMAX + 1)

		eval "MENUENTRY$REALMAX=\"Create new partition at the start with max size\""
		eval "PARTSTART$REALMAX=\"$START\""
		VAL=$(expr $VAL - 1)
		eval "PARTEND$REALMAX=\"100%\""
		if [ $SELECTED_PART -eq 0 ]; then
			SELECTED_PART=$REALMAX
		fi
		REALMAX=$(expr $REALMAX + 1)
	fi
	if [ $SELECTED_PART -eq 0 ]; then
		# No partition found, try to find something which is not fat:
		local i=1
		while [ $i -lt $MAX ]; do
			eval "PARTFORMAT=\"\$PARTFORMAT$i\""
			if [ "${PARTFORMAT:0:3}" != "fat" ]; then
				eval "DEVICESIZE=\"\$PARTSIZE$i\""
				if [ $DEVICESIZE -ge $MINPARTSIZE ]; then
					SELECTED_PART="$i"
					break
				fi
			fi
			i=$(expr $i + 1)
		done
	fi
	if [ $SELECTED_PART -eq 0 -a $MAX -eq 2 ]; then
		# No partition found, try to find something which is fat,
		# because this can be splitted:
		local i=1
		while [ $i -lt $MAX ]; do
			eval "PARTFORMAT=\"\$PARTFORMAT$i\""
			if [ "${PARTFORMAT:0:3}" = "fat" ]; then
				eval "DEVICESIZE=\"\$PARTSIZE$i\""
				local VAL=$(expr $SPLITSIZE + $MINPARTSIZE)
				if [ $DEVICESIZE -gt $VAL ]; then
					SELECTED_PART="$i"
					break
				fi
			fi
			i=$(expr $i + 1)
		done
	fi
	local SURE=n
	while [ "$SURE" != "y" ]; do
		MENUENTRY0="Delete all data on $DISK $SIZE $LABEL\n         and create new partition"
		select_menu "Please select a partition for installation:" 0 $REALMAX $SELECTED_PART
		SELECTED_PART=$?
		if [ $SELECTED_PART -gt $REALMAX ]; then
			state_back
			break
		fi
		if [ $SELECTED_PART -eq 0 ]; then
			clear_screen
			print_indent "Are you sure to delete all data on the following disk?"
			echo
			print_indent "$DISK $SIZE $LABEL"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			print_indent "\e[0;32mHold O to cancel.\e[0m"

			wait_for_XO
			if [ "$INPUT" = "X" ]; then
				SURE="y"
				DEVICE="deleteall"
				if [ "$KERNDISK" = "" -o "$KERNDEVICE" != "" ]; then
					# all information already known
					state_set install
				else
					if [ "$DISK" = "$KERNDISK" ]; then
						# As we know that $DISK should be delete, we don't need to
						# ask again for $KERNDISK as this is the same.
						KERNDEVICE="deleteall"
						state_set install
					else
						# Need to find partition where kernel should be installed.
						state_set select_kern_partition
					fi
				fi
			else
				DEVICE=""
			fi
		else
			eval "PART=\"\$PART$SELECTED_PART\""
			eval "DEVICE=\"${DISK}\$PART$SELECTED_PART\""
			eval "DEVICESIZE=\"\$PARTSIZE$SELECTED_PART\""
			eval "PARTFORMAT=\"\$PARTFORMAT$SELECTED_PART\""
			eval "PARTSTART=\"\$PARTSTART$SELECTED_PART\""
			eval "PARTEND=\"\$PARTEND$SELECTED_PART\""
			local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")

			if [ $SELECTED_PART -gt $MAX ]; then
				create_partition "$DISK" "$PARTSTART" "$PARTEND"
				break
			fi

			if [ "$DISK" = "$KERNDISK" -a "${PARTFORMAT:0:3}" = "fat" -a "${DEV:0:2}" != "hd" ]; then
				clear_screen
				print_indent "Should the partition be splitted?"
				if [ $MAX -eq 2 ]; then
					print_indent "You will may need a FAT and an ext2 partition."
					print_indent "It is recommended to resize split the parition."
				fi
				echo
				local VAL=$(expr $DEVICESIZE / 1048576)
				print_indent "$DEVICE ${VAL}MiB $PARTFORMAT"
				echo
				if [ $MAX -eq 2 ]; then
					print_indent "\e[0;32mHold X to split\e[0m"
					print_indent "\e[0;32mHold O to continue\e[0m"
					wait_for_XO
					if [ "$INPUT" = "X" ]; then
						split_partition "$DISK" "$PART" "$PARTSTART" "$PARTEND"
						break
					fi
				else
					print_indent "\e[0;32mHold X to continue\e[0m"
					print_indent "\e[0;32mHold O to split\e[0m"
					wait_for_XO
					if [ "$INPUT" = "O" ]; then
						split_partition "$DISK" "$PART" "$PARTSTART" "$PARTEND"
						break
					fi
				fi
			fi

			clear_screen
			print_indent "Are you sure to use the following partition?"
			print_indent "WARNING: The data will be deleted."
			echo
			local VAL=$(expr $DEVICESIZE / 1048576)
			print_indent "$DEVICE ${VAL}MiB $PARTFORMAT"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			print_indent "\e[0;32mHold O to cancel.\e[0m"
			wait_for_XO
			if [ "$INPUT" = "X" ]; then
				SURE="y"
				if [ "$KERNDISK" = "" -o "$KERNDEVICE" != "" ]; then
					# all information already known
					state_set install
				else
					# Need to find partition where kernel should be installed.
					state_set select_kern_partition
				fi
			else
				DEVICE=""
			fi
		fi
	done
}

state_select_kern_partition()
{
	local DISK="$1"
	local SIZE="$2"
	local LABEL="$3"

	local SELECTED_PART=0
	search_partitions "$DISK"
	local MAX=$?

	# Prefer to install kernel to fat partition with minimum size:
	local i=1
	while [ $i -lt $MAX ]; do
		eval "KERNPARTFORMAT=\"\$PARTFORMAT$i\""
		if [ "${KERNPARTFORMAT:0:3}" = "fat" ]; then
			eval "DEVICESIZE=\"\$PARTSIZE$i\""
			if [ $DEVICESIZE -gt $MINPARTSIZE]; then
				SELECTED_PART="$i"
				break
			fi
		fi
		i=$(expr $i + 1)
	done

	# Prefer to install kernel to first fat partition:
	if [ $SELECTED_PART -eq 0 ]; then
		local i=1
		while [ $i -lt $MAX ]; do
			eval "KERNPARTFORMAT=\"\$PARTFORMAT$i\""
			if [ "${KERNPARTFORMAT:0:3}" = "fat" ]; then
				eval "DEVICESIZE=\"\$PARTSIZE$i\""
				SELECTED_PART="$i"
				break
			fi
			i=$(expr $i + 1)
		done
	fi

	KERNDEVICE=""
	KERNPARTFORMAT=""

	if [ $MAX -lt 1 ]; then
		MAX=1
	fi

	local SURE=n
	while [ "$SURE" != "y" ]; do
		MENUENTRY0="Delete all data on $DISK $SIZE $LABEL\n         and create new partition"
		select_menu "Please select a partition for kernel:" 0 $MAX $SELECTED_PART
		SELECTED_PART=$?
		if [ $SELECTED_PART -gt $MAX ]; then
			state_back
			break
		fi
		if [ $SELECTED_PART -eq 0 ]; then
			clear_screen
			print_indent "Are you sure to delete all data on the following disk?"
			echo
			print_indent "$DISK $SIZE $LABEL"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			print_indent "\e[0;32mHold O to cancel.\e[0m"

			wait_for_XO
			if [ "$INPUT" = "X" ]; then
				SURE="y"
				KERNDEVICE="deleteall"
				state_set install
			else
				KERNDEVICE=""
			fi
		else
			eval "KERNDEVICE=\"${DISK}\$PART$SELECTED_PART\""
			eval "KERNDEVICESIZE=\"\$PARTSIZE$SELECTED_PART\""
			eval "KERNPARTFORMAT=\"\$PARTFORMAT$SELECTED_PART\""

			if [ "$KERNDEVICE" = "$DEVICE" -o "${KERNPARTFORMAT:0:3}" != "fat" ]; then
				clear_screen
				print_indent "\e[0;35mYou need to choose a different partition for the kernel.\e[0m"
				print_indent "The kernel is not readable by kernelloader when it is"
				print_indent "not installed in a fat partition."
				echo
				local VAL=$(expr $KERNDEVICESIZE / 1048576)
				print_indent "$KERNDEVICE ${VAL}MiB $KERNPARTFORMAT"
				echo
				print_indent "\e[0;32mHold X to ignore.\e[0m"
				print_indent "\e[0;32mHold O to cancel.\e[0m"
				wait_for_XO
				if [ "$INPUT" = "X" ]; then
					SURE="y"
					state_set install
				fi
			else
				clear_screen
				print_indent "Are you sure to use the following partition?"
				echo
				local VAL=$(expr $KERNDEVICESIZE / 1048576)
				print_indent "$KERNDEVICE ${VAL}MiB $KERNPARTFORMAT"
				echo
				print_indent "\e[0;32mHold X to continue.\e[0m"
				print_indent "\e[0;32mHold O to cancel.\e[0m"
				wait_for_XO
				if [ "$INPUT" = "X" ]; then
					SURE="y"
					state_set install
				else
					KERNDEVICE=""
				fi
			fi
		fi
	done
}

state_install()
{
	clear_screen
	print_indent "Installing..."
	echo

	local KERNDEV=$(echo "$KERNDISK" | sed -e "s#/dev/##g")
	if [ "$KERNDISK" = "" ]; then
		INSTALLKERN=0
	else
		INSTALLKERN=1
	fi

	if [ "$DISK" = "$KERNDISK" ]; then
		if [ "$DEVICE" = "deleteall" ]; then
			# Create new partition table and format fat.
			format_everything "$DISK" "$DISKSIZE"
			if [ "$STATE" != "install" ]; then
				# User stopped installation:
				return
			fi
			install_linux "$DEVICE" "$DOSDEVICE" "/dev/ps2mc00" $INSTALLKERN
		else
			install_linux "$DEVICE" "$KERNDEVICE" "/dev/ps2mc00" $INSTALLKERN
		fi
	else
		if [ "$DEVICE" = "deleteall" ]; then
			format_everything_as_linux_only "$DISK" "$DISKSIZE" "$SWAPSIZE"
			if [ "$STATE" != "install" ]; then
				# User stopped installation:
				return
			fi
		fi
		if [ "${KERNDEV:0:5}" = "ps2mc" ]; then
			if [ "$KERNDISK" != "" ]; then
				clear_screen
				print_indent "Please select the bootloader:"
				echo
				print_indent "\e[0;32mHold X to install to kloader on MC.\e[0m"
				print_indent "\e[0;32m (You need kloader to boot).\e[0m"
				print_indent "\e[0;32mHold O to install to BWLINUX on MC.\e[0m"
				print_indent "\e[0;32m (You need disc 1 from Sony's Linux Toolkit to boot).\e[0m"
				echo
				wait_for_XO
				if [ "$INPUT" = "X" ]; then
					install_linux_hdd "$DEVICE" "vmlinux.gz" "$KERNDEVICE" "$DESTKERN" "kloader"
				else
					install_linux_hdd "$DEVICE" "vmlinux" "$KERNDEVICE" "$DESTKERN" "BWLINUX"
				fi
			else
				install_linux_hdd "$DEVICE" "" "$KERNDEVICE" "mc0:kloader" "kloader"
			fi
		else
			install_linux "$DEVICE" "$KERNDEVICE" "/dev/ps2mc00" $INSTALLKERN
		fi
	fi
}

state_finished()
{
	clear_screen
	print_indent "Installation finished."
	print_indent "Please start kernel loader."
	echo
	print_indent "\e[0;32mHold X to power off.\e[0m"
	print_indent "\e[0;32mHold O to restart installer.\e[0m"
	wait_for_XO
	if [ "$INPUT" = "X" ]; then
		halt
		exit 1
	else
		state_reset
	fi
}

################################################################################
#
# Installers
#
###############################################################################

format_everything()
{
	local DISK="$1"
	local DISKSIZE="$1"

	print_indent "\e[0;32mHold X to delete all data on ${DISK} ${DISKLABEL}.\e[0m"
	print_indent "\e[0;32mHold O to cancel.\e[0m"
	wait_for_XO
	if [ "$INPUT" != "X" ]; then
		state_back
		return
	fi

	local END=$DISKSIZE
	local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")
	local OPTIMALIOSIZE=$(cat /sys/block/$DEV/queue/optimal_io_size)
	local MINIMALIOSIZE=$(cat /sys/block/$DEV/queue/minimum_io_size)
	local BLOCKSIZE=$(cat /sys/block/$DEV/queue/physical_block_size)
	local ALIGNOFF=$(cat /sys/block/$DEV/alignment_offset)
	local START=$OPTIMALIOSIZE
	if [ $START -lt $MINIMALIOSIZE ]; then
		START=$MINIMALIOSIZE
	fi
	START=$(expr $START + $ALIGNOFF)
	local FIRSTSECTOR=$(expr $START / $BLOCKSIZE)
	if [ $FIRSTSECTOR -lt 2048 ]; then
		FIRSTSECTOR=2048
	fi
	START=$(expr $FIRSTSECTOR \* $BLOCKSIZE)
	local BORDER=$(expr $SPLITSIZE + $START)
	BORDER=$(expr $BORDER + $BLOCKSIZE - 1)
	BORDER=$(expr $BORDER / $BLOCKSIZE)
	BORDER=$(expr $BORDER \* $BLOCKSIZE)
	BORDER=$(expr $BORDER - 1)

	set -x
	parted -s -m $DISK mklabel msdos || error_exit
	parted -s -m $DISK mkpart primary ext2 ${FIRSTSECTOR}s ${BORDER}B || error_exit
	set +x
	BORDER=$(expr $BORDER + 1)
	local END=$(expr $BORDER + $SWAPSIZE - 1)
	set -x
	parted -s -m $DISK mkpartfs primary linux-swap ${BORDER}B ${END}B || error_exit
	END=$(expr $END + 1)
	parted -s -m $DISK mkpart primary fat32 ${END}B 100% || error_exit
	swapon ${DISK}2
	DOSDEVICE="${DISK}3"
	DEVICE="${DISK}1"
	mkfs.fat -F 32 $DOSDEVICE || error_exit
	set +x
}

format_everything_as_linux_only()
{
	local DISK="$1"
	local DISKSIZE="$2"
	local SWAPSIZE="$3"

	print_indent "\e[0;32mHold X to delete all data on ${DISK} ${DISKLABEL}.\e[0m"
	print_indent "\e[0;32mHold O to cancel.\e[0m"
	wait_for_XO
	if [ "$INPUT" != "X" ]; then
		state_back
		return
	fi

	local END=$DISKSIZE
	local DEV=$(echo "$DISK" | sed -e "s#/dev/##g")
	local OPTIMALIOSIZE=$(cat /sys/block/$DEV/queue/optimal_io_size)
	local MINIMALIOSIZE=$(cat /sys/block/$DEV/queue/minimum_io_size)
	local BLOCKSIZE=$(cat /sys/block/$DEV/queue/physical_block_size)
	local ALIGNOFF=$(cat /sys/block/$DEV/alignment_offset)
	local START=$OPTIMALIOSIZE
	if [ $START -lt $MINIMALIOSIZE ]; then
		START=$MINIMALIOSIZE
	fi
	START=$(expr $START + $ALIGNOFF)
	local FIRSTSECTOR=$(expr $START / $BLOCKSIZE)
	if [ $FIRSTSECTOR -lt 2048 ]; then
		FIRSTSECTOR=2048
	fi
	set -x
	parted -s -m $DISK mklabel msdos || error_exit
	# Make first partition a swap partition when user wants to install a larger system.
	parted -s -m $DISK mkpartfs primary linux-swap ${FIRSTSECTOR}s $SWAPSIZE || error_exit
	parted -s -m $DISK mkpart primary ext2 ${SWAPSIZE} 100% || error_exit
	swapon ${DISK}1
	DEVICE="${DISK}2"
	set +x
}

install_linux()
{
	local DEVICE="$1"
	local DOSDEVICE="$2"
	local MCDEVICE="$3"
	local INSTALLKERN="$4"

	clear_screen
	print_indent "Please select how to format the partition ${DEVICE}:"
	echo
	print_indent "\e[0;32mHold X to delete all data on ${DEVICE}.\e[0m"
	print_indent "\e[0;32mHold TRIANGLE to try updating without formating.\e[0m"
	print_indent "\e[0;32mHold O to cancel.\e[0m"
	wait_for_XOT
	if [ "$INPUT" = "O" ]; then
		state_back
		return
	fi

	if [ "$SWAPDEVICE" != "" ]; then
		swapon "$SWAPDEVICE"
	fi

	if [ "$INPUT" = "X" ]; then
		yes | mkfs.ext2 ${DEVICE}
		if [ $? -ne 0 ]; then
			print_indent "Failed to create file system"
			echo
			print_indent "\e[0;32mHold X to continue\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
	fi
	fsck.ext2 -y ${DEVICE}
	mkdir -p /mnt/disk || error_exit
	mount ${DEVICE} /mnt/disk
	if [ $? -ne 0 ]; then
		print_indent "Failed to mount file system of ${DEVICE}"
		echo
		print_indent "\e[0;32mHold X to cancel\e[0m"
		wait_for_X
		install_cleanup
		state_back
		return
	fi
	local DOWNLOADDIR="/mnt/disk/installer"

	if [ "$DOSDEVICE" != "" ]; then
		if [ "$DEVICE" != "$DOSDEVICE" ]; then
			local DOSDIR="/mnt/dos"
			mkdir -p "$DOSDIR" || error_exit
			mount ${DOSDEVICE} "$DOSDIR"
			if [ $? -ne 0 ]; then
				print_indent "Failed to mount file system of ${DOSDEVICE}."
				echo
				print_indent "\e[0;32mHold X to cancel\e[0m"
				wait_for_X
				install_cleanup
				state_back
				return
			fi
			local DOWNLOADDIR="$DOSDIR/ps2"
			mkdir -p "$DOWNLOADDIR" || error_exit
		else
			local DOSDIR="/mnt/disk"
			local DOWNLOADDIR="$DOSDIR/boot"
		fi
	fi

	mkdir -p /mnt/disk/boot || error_exit
	print_indent "Downloading"

	if [ ! -e "$DOWNLOADDIR" ]; then
		mkdir -p "$DOWNLOADDIR" || error_exit
	fi

	FAILED=1
	while [ $FAILED -ne 0 ]; do
		echo "$URLTGZ"
		if [ -e "$DOWNLOADDIR/$TGZFILE" ]; then
			print_indent "File $TGZFILE found."
			echo
			print_indent "\e[0;32mHold X to redownload\e[0m"
			print_indent "\e[0;32mHold O to use file\e[0m"
			wait_for_XO

			if [ "$INPUT" = "O" ]; then
				break
			fi

			rm "$DOWNLOADDIR/$TGZFILE"
		fi
		wget -O "$DOWNLOADDIR/$TGZFILE" "$URLTGZ"
		FAILED=$?
		if [ $FAILED -ne 0 ]; then
			print_indent "Failed download..."
			df -h "$DOWNLOADDIR"
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold TRIANGLE to remove old installer files\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XOT
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
			if [ "$INPUT" = "T" ]; then
				rm -rf "$DOWNLOADDIR/"*.tgz
				rm -rf "$DOWNLOADDIR/"*.tar.gz
				rm -rf "$DOWNLOADDIR/"*.tar.bz2
			fi
		fi
	done

	if [ $INSTALLKERN -eq 1 ]; then
		FAILED=1
		while [ $FAILED -ne 0 ]; do
			echo "$URLKERN"
			if [ -e "$DOWNLOADDIR/$KERNFILE" ]; then
				print_indent "File $KERNFILE found."
				echo
				print_indent "\e[0;32mHold X to redownload\e[0m"
				print_indent "\e[0;32mHold O to use file\e[0m"
				wait_for_XO

				if [ "$INPUT" = "O" ]; then
					break
				fi

				rm "$DOWNLOADDIR/$KERNFILE"
			fi
			wget -O "$DOWNLOADDIR/$KERNFILE" "$URLKERN"
			FAILED=$?
			if [ $FAILED -ne 0 ]; then
				print_indent "Failed download..."
				echo
				print_indent "\e[0;32mHold X to retry\e[0m"
				print_indent "\e[0;32mHold O to cancel\e[0m"
				wait_for_XO
				if [ "$INPUT" = "O" ]; then
					install_cleanup
					state_back
					return
				fi
			fi
		done
	fi
	tar -xvf "$DOWNLOADDIR/$TGZFILE" -C /mnt/disk/
	if [ $? -ne 0 ]; then
		gzip -cd "$DOWNLOADDIR/$TGZFILE" | tar -xv -C /mnt/disk/
		if [ $? -ne 0 ]; then
			install_cleanup
			print_indent "Failed to extract the archive..."
			echo
			print_indent "\e[0;32mHold X to cancel\e[0m"
			wait_for_X
			state_back
			return
		fi
	fi
	if [ "$DEVICE" != "$DOSDEVICE" ]; then
		if [ "$DOSDEVICE" != "" ]; then
			umount /mnt/disk
		fi
	fi
	mkdir -p /mnt/mc || error_exit
	MOUNTED=1
	while [ $MOUNTED -ne 0 ]; do
		mount "$MCDEVICE" /mnt/mc
		MOUNTED=$?
		if [ $MOUNTED -eq 0 ]; then
			# mount can return success when there is no memory card,
			# then creating a directory will fail:
			if [ ! -d /mnt/mc/kloader ]; then
				mkdir -p /mnt/mc/kloader
				MOUNTED=$?
				if [ $MOUNTED -ne 0 ]; then
					umount /mnt/mc
				fi
			fi
		fi
		if [ $MOUNTED -ne 0 ]; then
			clear_screen
			print_indent "Please insert a memory card in the first slot."
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
		if [ ! -d /mnt/mc/kloader ]; then
			umount /mnt/mc
			MOUNTED=1
			clear_screen
			print_indent "The memory card seems not to be supported."
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
	done
	cat <<EOF >/tmp/config.txt
KernelParameter=
KernelFileName=
InitrdFileName=
Auto Boot=
EOF
	if [ -d /mnt/mc/kloader ]; then
		if [ ! -e /mnt/mc/kloader/config.txt ]; then
			if [ ! -d /mnt/mc/kloader ]; then
				mkdir -p /mnt/mc/kloader
			fi
		else
			cp /mnt/mc/kloader/config.txt /tmp/config.txt
			cp /tmp/config.txt "$DOWNLOADDIR/oldconfig.txt"
		fi
		if [ ! -e /mnt/mc/kloader/icon.sys ]; then
			cp /usr/share/kloader/icon.sys /mnt/mc/kloader/
		fi
		if [ ! -e /mnt/mc/kloader/kloader.icn ]; then
			cp /usr/share/kloader/kloader.icn /mnt/mc/kloader/
		fi
	else
		umount /mnt/mc >/dev/null 2>&1
		clear_screen
		print_indent "The memory card seems not to be supported."
		echo
		print_indent "\e[0;32mHold X to cancel\e[0m"
		wait_for_X
		install_cleanup
		state_back
		return
	fi
	if [ "$DEVICE" != "$DOSDEVICE" -a $INSTALLKERN -eq 1 ]; then
		sed </tmp/config.txt >"$DOWNLOADDIR/config.txt" -e "s#^KernelParameter=.*#KernelParameter=root=${DEVICE} rootdelay=4#g" -e "s#^KernelFileName=.*#KernelFileName=mass:/ps2/$KERNFILE#g" -e "s#^Auto Boot=.*#Auto Boot=3#g" -e "s#^InitrdFileName=.*#InitrdFileName=#g" || error_exit
	else
		sed </tmp/config.txt >"$DOWNLOADDIR/config.txt" -e "s#^KernelParameter=.*#KernelParameter=root=${DEVICE} rootdelay=4#g" -e "s#^Auto Boot=.*#Auto Boot=3#g" -e "s#^InitrdFileName=.*#InitrdFileName=#g" || error_exit
	fi
	if [ "$DOSDEVICE" != "" -a "$DEVICE" != "$DOSDEVICE" ]; then
		cp "$DOWNLOADDIR/config.txt" "$DOSDIR/"
	fi
	rm /mnt/mc/kloader/config.txt
	cp "$DOWNLOADDIR/config.txt" /mnt/mc/kloader/config.txt
	if [ $? -ne 0 ]; then
		print_indent "Failed to copy config.txt to mc0:/kloader"
		echo
		echo
		echo
		echo
		echo
		sleep 3
	fi
	umount /mnt/mc
	umount "$DOSDIR"
	if [ "$SWAPDEVICE" != "" ]; then
		swapoff "$SWAPDEVICE"
	fi
	state_set "finished"
}

# Install linux on disk and kernel on memory card
install_linux_hdd()
{
	local DEVICE="$1"
	local VMLINUX="$2"
	local MCDEVICE="$3"
	local MC="$4"
	local MCDIR="$5"

	clear_screen
	print_indent "Please select how to format the partition ${DEVICE}:"
	echo
	print_indent "\e[0;32mHold X to delete all data on ${DEVICE}.\e[0m"
	print_indent "\e[0;32mHold TRIANGLE to try updating without formating.\e[0m"
	print_indent "\e[0;32mHold O to cancel.\e[0m"
	wait_for_XOT
	if [ "$INPUT" = "O" ]; then
		state_back
		return
	fi

	if [ "$SWAPDEVICE" != "" ]; then
		swapon "$SWAPDEVICE"
	fi

	if [ "$INPUT" = "X" ]; then
		yes | mkfs.ext2 "${DEVICE}"
		if [ $? -ne 0 ]; then
			print_indent "Failed to create file system"
			echo
			print_indent "\e[0;32mHold X to continue\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
	fi
	fsck.ext2 -y ${DEVICE}
	mkdir -p /mnt/disk || error_exit
	mount "${DEVICE}" /mnt/disk || error_exit
	mkdir -p /mnt/disk/installer || error_exit
	mkdir -p /mnt/disk/boot || error_exit
	print_indent "Downloading"

	local FAILED=1
	while [ $FAILED -ne 0 ]; do
		echo "$URLTGZ"
		if [ -e "/mnt/disk/installer/$TGZFILE" ]; then
			print_indent "File $TGZFILE found."
			echo
			print_indent "\e[0;32mHold X to redownload\e[0m"
			print_indent "\e[0;32mHold O to use file\e[0m"
			wait_for_XO

			if [ "$INPUT" = "O" ]; then
				break
			fi

			rm "/mnt/disk/installer/$TGZFILE"
		fi
		wget -O "/mnt/disk/installer/$TGZFILE" "$URLTGZ"
		FAILED=$?
		if [ $FAILED -ne 0 ]; then
			print_indent "Failed download..."
			df -h /mnt/disk
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold TRIANGLE to remove old installer files\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XOT
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
			if [ "$INPUT" = "T" ]; then
				rm -rf /mnt/disk/installer
				mkdir -p /mnt/disk/installer || error_exit
			fi
		fi
	done

	FAILED=1
	while [ $FAILED -ne 0 ]; do
		echo "$URLKERN"
			if [ -e "/mnt/disk/boot/$KERNFILE" ]; then
				print_indent "File $KERNFILE found."
				echo
				print_indent "\e[0;32mHold X to redownload\e[0m"
				print_indent "\e[0;32mHold O to use file\e[0m"
				wait_for_XO

				if [ "$INPUT" = "O" ]; then
					break
				fi

				rm "/mnt/disk/boot/$KERNFILE"
			fi
		wget -O "/mnt/disk/boot/$KERNFILE" "$URLKERN"
		FAILED=$?
		if [ $FAILED -ne 0 ]; then
			print_indent "Failed download..."
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
	done
	tar -xvf "/mnt/disk/installer/$TGZFILE" -C /mnt/disk/
	if [ $? -ne 0 ]; then
		gzip -cd "/mnt/disk/installer/$TGZFILE" | tar -xv -C /mnt/disk/
		if [ $? -ne 0 ]; then
			install_cleanup
			print_indent "Failed to extract the archive..."
			echo
			print_indent "\e[0;32mHold X to cancel\e[0m"
			wait_for_X
			state_back
			return
		fi
	fi
	mkdir -p /mnt/mc || error_exit
	local MOUNTED=1
	while [ $MOUNTED -ne 0 ]; do
		mount "$MCDEVICE" /mnt/mc
		MOUNTED=$?
		if [ $MOUNTED -eq 0 ]; then
			# mount can return success when there is no memory card,
			# then creating a directory will fail:
			if [ ! -d "/mnt/mc/$MCDIR" ]; then
				mkdir -p "/mnt/mc/$MCDIR"
				MOUNTED=$?
				if [ $MOUNTED -ne 0 ]; then
					umount /mnt/mc
				fi
			fi
		fi
		if [ $MOUNTED -ne 0 ]; then
			clear_screen
			print_indent "Please insert a memory card in the first slot."
			print_indent "There must be $KERNSIZE free."
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			INPUT=""
			while [ "$INPUT" != "X" ]; do
				get_input
			done
		fi
		if [ ! -d "/mnt/mc/$MCDIR" ]; then
			umount /mnt/mc
			MOUNTED=1
			clear_screen
			print_indent "The memory card seems not to be supported."
			echo
			print_indent "\e[0;32mHold X to retry\e[0m"
			print_indent "\e[0;32mHold O to cancel\e[0m"
			wait_for_XO
			if [ "$INPUT" = "O" ]; then
				install_cleanup
				state_back
				return
			fi
		fi
	done
	cat <<EOF >/tmp/config.txt
KernelParameter=
KernelFileName=
InitrdFileName=
Auto Boot=
EOF
	if [ -e /mnt/mc/kloader/config.txt ]; then
		cp /mnt/mc/kloader/config.txt /tmp/config.txt
		cp /tmp/config.txt /mnt/disk/installer/oldconfig.txt
	fi
	if [ "$MCDIR" = "kloader" ]; then
		if [ ! -e "/mnt/mc/$MCDIR/icon.sys" ]; then
			cp "/usr/share/$MCDIR/icon.sys" "/mnt/mc/$MCDIR/"
		fi
		if [ ! -e "/mnt/mc/$MCDIR/$MCDIR" ]; then
			cp "/usr/share/$MCDIR/kloader.icn" "/mnt/mc/$MCDIR/"
		fi
	fi
	if [ "$VMLINUX" != "" ]; then
		if [ -e "/mnt/mc/$MCDIR/$VMLINUX" ]; then
			rm "/mnt/mc/$MCDIR/$VMLINUX"
		fi
		echo
		if [ "$MCDIR" = "kloader" ]; then
			print_indent "Copying kernel."
			echo
			cp "/mnt/disk/boot/$KERNFILE" "/mnt/mc/$MCDIR/$VMLINUX"
		else
			if [ "${KERNFILE/.gz/}" != "${KERNFILE}" ]; then
				# Sony's Linux Toolkit can start uncompressed kernels only.
				print_indent "Uncompressing kernel."
				echo
				gunzip -c "/mnt/disk/boot/$KERNFILE" >"/tmp/$VMLINUX"
				print_indent "Copying kernel."
				cp "/tmp/$VMLINUX" "/mnt/mc/$MCDIR/$VMLINUX"
			else
				print_indent "Copying kernel."
				echo
				cp "/mnt/disk/boot/$KERNFILE" "/mnt/mc/$MCDIR/$VMLINUX"
			fi
		fi
		if [ $? -ne 0 ]; then
			# Remove broken file:
			rm "/mnt/mc/$MCDIR/$VMLINUX"
			clear_screen
			print_indent "\e[0;35mFailed to copy kernel on the memory card.\e[0m"
			print_indent "You need to install the kernel manually."
			print_indent "There must be $KERNSIZE free."
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			wait_for_X
			sed </tmp/config.txt >/mnt/disk/installer/config.txt -e "s#^KernelParameter=.*#KernelParameter=root=${DEVICE} rootdelay=4#g" -e "s#^Auto Boot=.*#Auto Boot=3#g" -e "s#^InitrdFileName=.*#InitrdFileName=#g" || error_exit
		else
			sed </tmp/config.txt >/mnt/disk/installer/config.txt -e "s#^KernelParameter=.*#KernelParameter=root=${DEVICE} rootdelay=4#g" -e "s#^KernelFileName=.*#KernelFileName=$MC/${VMLINUX}#g" -e "s#^Auto Boot=.*#Auto Boot=3#g" -e "s#^InitrdFileName=.*#InitrdFileName=#g" || error_exit
		fi
	else
		sed </tmp/config.txt >/mnt/disk/installer/config.txt -e "s#^KernelParameter=.*#KernelParameter=root=${DEVICE} rootdelay=4#g" -e "s#^Auto Boot=.*#Auto Boot=3#g" -e "s#^InitrdFileName=.*#InitrdFileName=#g" || error_exit
	fi
	if [ "$MCDIR" = "kloader" ]; then
		rm -f "/mnt/mc/$MCDIR/config.txt"
		cp /mnt/disk/installer/config.txt "/mnt/mc/$MCDIR/config.txt"
		if [ $? -ne 0 ]; then
			print_indent "Failed to copy config.txt to $MC"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			wait_for_X
		fi
	fi
	if [ "$MCDIR" = "BWLINUX" ]; then
		# Use current configuration:
		cat /proc/cmdline | tr " " "\n" | grep -e "^crtmode=" -e "^xmode=" -e "^video=" | tr "\n" " " >/tmp/videoparms.txt
			cat /proc/cmdline | tr " " "\n" | grep -e "^video=" | cut -d '=' -f 2 | cut -d ':' -f 2 | tr "," "\n" | grep -e vesa -e pal -e ntsc | tail -n 1 >/tmp/videoformat.txt
		local VIDEOPARMS="$(cat /tmp/videoparms.txt)"
		local VIDEOFORMAT="$(cat /tmp/videoformat.txt)"
		touch /tmp/p2lboot.cnf
		if [ -e "/mnt/mc/$MCDIR/p2lboot.cnf" ]; then
			cp "/mnt/mc/$MCDIR/p2lboot.cnf" /tmp/p2lboot.cnf
		fi
		echo -e "\"$INSTALLNAME $VIDEOFORMAT\"\t\"$VMLINUX\"\t\"\"\t203\t${DEVICE}\t\"rootdelay=4 $VIDEOPARMS\"\t\"$INSTALLNAME $VIDEOFORMAT $SELECTEDLINUXINSTALL\"" >>/tmp/p2lboot.cnf
		sort -u /tmp/p2lboot.cnf >/tmp/p2lboot.cnf.sorted
		rm -f "/mnt/mc/$MCDIR/p2lboot.cnf"
		cp /tmp/p2lboot.cnf.sorted "/mnt/mc/$MCDIR/p2lboot.cnf"
		if [ $? -ne 0 ]; then
			print_indent "Failed to copy p2lboot.cnf to $MC"
			echo
			print_indent "\e[0;32mHold X to continue.\e[0m"
			wait_for_X
		fi
	fi
	umount /mnt/mc
	umount /mnt/disk
	if [ "$SWAPDEVICE" != "" ]; then
		swapoff "$SWAPDEVICE"
	fi
	state_set "finished"
}

########## Stuff not updated ##########

check_for_update()
{
	if [ $AUTODETECTIP -eq 1 ]; then
		local BASEIP="$(ifconfig | grep -e 'inet addr:' | cut -d ':' -f 2 | cut -d ' ' -f 1 | head -n 1 | sed -e 's-\.[0-9]*$--g')"
		if [ $? -eq 0 -a "$BASEIP" != "" ]; then
			URLUPDATELOCAL="http://${BASEIP}.42/updatev1.sh"
		fi
	fi
	echo "$URLUPDATELOCAL"
	wget -O /tmp/update.sh "$URLUPDATELOCAL"
	if [ $? -ne 0 ]; then
		echo "$URLUPDATE"
		wget -O /tmp/update.sh "$URLUPDATE"
	fi
	if [ $? -eq 0 ]; then
		source /tmp/update.sh
	else
		print_indent "No update was found."
		echo
		print_indent "\e[0;32mHold X to continue\e[0m"

		wait_for_X
	fi
}

state_select_install()
{
	get_install
	MAX=$?

	MENUENTRY0="Update installer"
	select_menu "Please select an installation:" 0 $MAX $SELECTED_INSTALL
	SELECTED_INSTALL=$?

	if [ $SELECTED_INSTALL -gt $MAX ]; then
		state_back
		state_back
		return
	fi
	if [ $SELECTED_INSTALL -eq 0 ]; then
		SELECTED_INSTALL=1
		check_for_update
		return
	fi
	# Where to split the FAT partition:
	eval "SPLITSIZE=\"\$SPLITSIZE$SELECTED_INSTALL\""
	# Minimum size for the new created partition:
	eval "MINPARTSIZE=\"\$MINPARTSIZE$SELECTED_INSTALL\""
	# Reserve memory for swap:
	eval "SWAPSIZE=\"\$SWAPSIZE$SELECTED_INSTALL\""
	eval "TGZFILE=\"\$TGZFILE$SELECTED_INSTALL\""
	eval "KERNSIZE=\"\$KERNSIZE$SELECTED_INSTALL\""
	eval "KERNFILE=\"\$KERNFILE$SELECTED_INSTALL\""
	eval "URLBASE=\"\$URLBASE$SELECTED_INSTALL\""
	eval "URLKERNBASE=\"\$URLKERNBASE$SELECTED_INSTALL\""
	eval "URLTGZ=\"\$URLTGZ$SELECTED_INSTALL\""
	eval "URLKERN=\"\$URLKERN$SELECTED_INSTALL\""
	eval "INSTALLNAME=\"\$INSTALLNAME$SELECTED_INSTALL\""
	eval "SELECTEDLINUXINSTALL=\"\$MENUENTRY$SELECTED_INSTALL\""

	state_set "show_install"
}

state_machine()
{
	state_reset

	while true; do
		case $STATE in
			welcome)
				state_welcome
				;;
			server_check)
				state_server_check
				;;
			select_install)
				state_select_install
				;;
			show_install)
				state_show_install
				;;
			select_install_disk)
				state_select_install_disk
				;;
			select_kernel_disk)
				state_select_kernel_disk
				;;
			select_install_partition)
				state_select_install_partition "$DISK" "$DISKSIZE" "$DISKLABEL"
				;;

			select_kern_partition)
				state_select_kern_partition "$KERNDISK" "$KERNDISKSIZE" "$KERNDISKLABEL"
				;;

			install)
				state_install "$DISK" "$DISKSIZE" "$DISKLABEL" "$DEVICE" "$KERNDISK"
				;;

			finished)
				state_finished
				;;

			*)
				install_cleanup
				clear_screen
				print_indent "Unknown state restarting installer."
				echo
				print_indent "\e[0;32mHold X to continue\e[0m"
				wait_for_X
				state_reset
				;;
		esac
	done
}

update_info()
{
	echo
	print_indent "\e[0;32mv2\e[0m"
	print_indent "The update adds GPT support and audio support (audsrv.irx)."
	print_indent "Audio should work out of the box now in the YouTube player."
	print_indent "GPT support will only work when the newer kernel was already"
	print_indent "loaded when starting the installer."
	print_indent "The usabilty of the YoutTube player has been improved."
	print_indent "The installer can also install to BWLINUX on MC for use with"
	print_indent "Sony's Linux Toolkit."
	echo
	print_indent "\e[0;32mv3\e[0m"
	print_indent "Fixed playback of some YouTube videos which were just hanging"
	print_indent "and needed reboot."
	print_indent "Increased time waiting for network connection (DHCP client)."
	echo
	print_indent "\e[0;32mHold X to continue\e[0m"
	
	wait_for_X
}

state_machine
