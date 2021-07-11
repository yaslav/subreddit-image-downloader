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

parse_args "$@"
process_args

$VERBOSE && echo "DIRECTORY: $DL_DIR, FREQUENCY: $FREQUENCY, SUBREDDIT: $SUBREDDIT, VERBOSE: $VERBOSE"

FAKE_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

TOP_URL="https://www.reddit.com/r/$SUBREDDIT/top.json?limit=100&t=$FREQUENCY"

$VERBOSE && echo "Attempting to download JSON metadata from /r/$SUBREDDIT"
rm -f posts.json
http_code=$(curl -A "$FAKE_USER_AGENT" -s -w "%{http_code}" "$TOP_URL" -o posts.json)
$VERBOSE && echo "http_code: $http_code"
if [ "$http_code" -eq "429" ]; then
    echo "Error 429: too many requests. Maybe try changing the user agent or wait a couple of minutes"
    exit 1
elif [ "$http_code" -eq "302" ]; then
    echo "Invalid subreddit /r/$SUBREDDIT, please check the subreddit parameter"
    exit 1
elif [ "$http_code" -eq "200" ]; then
    echo "Successfully parsed metadata from /r/$SUBREDDIT"
fi

length=$(jq -r '.data.children | length' posts.json)
urls=$(jq -r '.data.children | .[].data | select(.post_hint=="image") | .url' posts.json)

if [ ! -d "$DL_DIR" ]; then
    $VERBOSE && echo "$DL_DIR does not exist, creating"
    mkdir "$DL_DIR"
fi
dl_folder_abs=$(realpath "$DL_DIR")

echo "Downloading top $length images of $FREQUENCY_STRING from /r/$SUBREDDIT"

for url in $urls; do
    filename=$(basename "$url")
    filename_abs="$dl_folder_abs/$filename"
    if [ ! -f "$filename_abs" ]; then
        $VERBOSE && echo "Downloading $filename from $url"
        curl "$url" -s -o "$filename_abs"
        if file "$filename_abs" | grep empty > /dev/null; then
            $VERBOSE && echo "Error downloading file $url"
            rm "$filename_abs"
        fi
    else
        $VERBOSE && cho "File $filename exists under $filename_abs, skipping"
    fi
done

echo "Done"
