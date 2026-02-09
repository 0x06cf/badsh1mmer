#!/bin/bash
# Copyright (c) 2026 kxtzownsu
# A copy of the MIT license should have been provided alongside this file.

dlog(){
  if [ "$DEBUG" = "1" ]; then
    printf '%s\n' "$*"
  fi
}

main(){
  INPUT_FILE="$1"
  OUTPUT_FILE="$2"

  SECTOR_SIZE=512
  SECTOR_START=2048

  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_image> <output_image>"
    exit 1
  fi

  if [ "$EUID" != "0" ]; then
    echo "Please run this script as root!"
    exit 1
  fi

  if [ "$INPUT_FILE" == "$OUTPUT_FILE" ]; then
    echo "bro?? don't override your source file???"
    exit 1
  fi

  echo "Shrinking $INPUT_FILE to $OUTPUT_FILE"

  DUMP=$(sfdisk -d "$INPUT_FILE")

  TOTAL_PART_SIZE=$(echo "$DUMP" | grep -o "size=[ ]*[0-9]*" | awk -F= '{sum += $2} END {print sum}')
  TOTAL_DISK_SECTORS=$((TOTAL_PART_SIZE + 4096))
  truncate -s $((TOTAL_DISK_SECTORS * SECTOR_SIZE)) "$OUTPUT_FILE"

  CURRENT_START=$SECTOR_START
  NEW_LAYOUT="label: gpt\nunit: sectors\n\n"

  PART_DATA=$(echo "$DUMP" | grep "^$INPUT_FILE" | sed "s|^$INPUT_FILE[p]*||")

  while read -r LINE; do
    PART_NUM=$(echo "$LINE" | awk -F'[: ]' '{print $1}')
    PART_OLD_START=$(echo "$LINE" | grep -o "start=[ ]*[0-9]*" | cut -d= -f2 | tr -d ' ')
    PART_SIZE=$(echo "$LINE" | grep -o "size=[ ]*[0-9]*" | cut -d= -f2 | tr -d ' ')
    PART_TYPE=$(echo "$LINE" | grep -o "type=[^ ,]*")
    PART_UUID=$(echo "$LINE" | grep -o "uuid=[^ ,]*")
    PART_NAME=$(echo "$LINE" | grep -o "name=\"[^\"]*\"")
    PART_ATTR=$(echo "$LINE" | grep -o "attrs=\"[^\"]*\"")

    dlog "part=$PART_NUM old_start=$PART_OLD_START new_start=$CURRENT_START size=$PART_SIZE type=$PART_TYPE uuid=$PART_UUID name=$PART_NAME attrs=$PART_ATTR"

    dd if="$INPUT_FILE" of="$OUTPUT_FILE" bs="$SECTOR_SIZE" \
       skip="$PART_OLD_START" seek="$CURRENT_START" count="$PART_SIZE" \
       conv=notrunc status=none

    NEW_LINE="$OUTPUT_FILE$PART_NUM : start=$CURRENT_START, size=$PART_SIZE, $PART_TYPE, $PART_UUID, $PART_NAME"
    [ -n "$PART_ATTR" ] && NEW_LINE+=", $PART_ATTR"
    NEW_LAYOUT+="$NEW_LINE\n"

    CURRENT_START=$((CURRENT_START + PART_SIZE))
  done <<< "$(echo "$PART_DATA" | sort -n)"

  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!!! if you see any signature errors below this, ignore them, they are intended !!!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo -e "$NEW_LAYOUT" | sfdisk "$OUTPUT_FILE" --force --quiet

  echo "Done!"
  exit 0
}

main "$@"