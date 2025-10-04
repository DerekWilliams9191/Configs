#!/bin/bash

# Check if two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <directory1> <directory2>"
    exit 1
fi

dir1="$1"
dir2="$2"

# Check if directories exist
if [ ! -d "$dir1" ]; then
    echo "Error: Directory '$dir1' does not exist."
    exit 1
fi

if [ ! -d "$dir2" ]; then
    echo "Error: Directory '$dir2' does not exist."
    exit 1
fi

# Compare the directories recursively and briefly
diff -r -q "$dir1" "$dir2" > /dev/null 2>&1

# Check the exit status of the diff command
if [ $? -eq 0 ]; then
    echo "Directories '$dir1' and '$dir2' have the same files."
else
    echo "Directories '$dir1' and '$dir2' have different files."
    echo "Differences found:"
    diff -r "$dir1" "$dir2"
fi
