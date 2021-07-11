#!/bin/sh

# Global variables
VERBOSE=false
SUBREDDIT=""
DL_DIR=""
FREQUENCY=""
FREQUENCY_STRING=""

help() {
    echo "Subreddit Image Downloader"
    echo "Usage: ./srid.sh [options]"
    echo " "
    echo "  -h|--help               Print this output"
    echo "  -v|--verbose            Print debug messages"
    echo "  -d|--directory          Directory to store downloaded images"
    echo "  -f|--frequency          Post frequency (day|week|month|year|all)"
    echo "  -s|--subreddit          Subreddit name from which to download images"
}


parse_args() {
    options=$(getopt -l "help,directory:,freq:,subreddit:,verbose" -o "hd:f:s:v" -- "$@")
    eval set -- "$options"

    while true
    do
    case $1 in
    -h|--help)
        help
        exit 0
        ;;
    -d|--directory)
        shift
        DL_DIR=$1
        ;;
    -f|--frequency)
        shift
        FREQUENCY=$1
        ;;
    -s|--subreddit)
        shift
        SUBREDDIT=$1
        ;;
    -v|--verbose)
        VERBOSE=true
        ;;
    --)
        shift
        break;;
    esac
    shift
    done
}
process_args() {
    if [ -z "$SUBREDDIT" ]; then
        echo "Error: subreddit name not provided"
        echo "Pass subreddit name via -s|--subreddit argument"
        exit 1
    fi

    if [ -z "$FREQUENCY" ]; then
        echo "Frequency not provided, setting to month"
        FREQUENCY=month
    fi

    case "$FREQUENCY" in
    day)   FREQUENCY=day; FREQUENCY_STRING="today";;
    week)   FREQUENCY=week; FREQUENCY_STRING="the week";;
    month)   FREQUENCY=month; FREQUENCY_STRING="the month";;
    year)   FREQUENCY=year; FREQUENCY_STRING="the year";;
    all)   FREQUENCY=all; FREQUENCY_STRING="all time";;
    *)   echo "Error: Invalid frequency $FREQUENCY provided. Either leave parameter -f|--frequency empty or set to day|week|month|year|all"; exit 1 ;;
    esac
}

debug_print() {
    $VERBOSE && echo $1
}

check_http_code() {
    debug_print "http_code: $http_code"
    http_code=$1
    if [ "$http_code" -eq "429" ]; then
        echo "Error 429: too many requests. Maybe try changing the user agent or wait a couple of minutes"
        exit 1
    elif [ "$http_code" -eq "302" ]; then
        echo "Invalid subreddit /r/$SUBREDDIT, please check the subreddit parameter"
        exit 1
    elif [ "$http_code" -eq "200" ]; then
        echo "Successfully parsed metadata from /r/$SUBREDDIT"
    fi
}

parse_args "$@"
process_args

rm -f posts.json

debug_print "DIRECTORY: $DL_DIR, FREQUENCY: $FREQUENCY, SUBREDDIT: $SUBREDDIT, VERBOSE: $VERBOSE"

# needs to be passed otherwise reddit blocks requests
fake_user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

top_url="https://www.reddit.com/r/$SUBREDDIT/top.json?limit=100&t=$FREQUENCY"

debug_print "Attempting to download JSON metadata from /r/$SUBREDDIT"

http_code=$(curl -A "$fake_user_agent" -s -w "%{http_code}" "$top_url" -o posts.json)
check_http_code "$http_code"

number_images=$(jq -r '[.data.children | .[].data | select(.post_hint=="image")] | length' posts.json)
urls=$(jq -r '.data.children | .[].data | select(.post_hint=="image") | .url' posts.json)

if [ ! -d "$DL_DIR" ]; then
    debug_print "$DL_DIR does not exist, creating"
    mkdir "$DL_DIR"
fi

dl_folder_abs=$(realpath "$DL_DIR")

echo "Downloading top $number_images images of $FREQUENCY_STRING from /r/$SUBREDDIT"

downloaded=0
skipped=0
errors=0
total=0

for url in $urls; do
    total=$((total+1))
    filename=$(basename "$url")
    filename_abs="$dl_folder_abs/$filename"
    if [ ! -f "$filename_abs" ]; then
        debug_print "Downloading $filename from $url"
        curl "$url" -s -o "$filename_abs"
        if file "$filename_abs" | grep empty > /dev/null; then
            debug_print "Error downloading file $url"
            rm "$filename_abs"
	    errors=$((errors+1))
	else
	    downloaded=$((downloaded+1))
        fi
    else
        debug_print "File $filename exists under $filename_abs, skipping"
        skipped=$((skipped+1))
    fi
done

echo "Finished. Total: $total,  downloaded: $downloaded, skipped: $skipped, errors: $errors"
