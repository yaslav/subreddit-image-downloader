#!/bin/sh

# Global variables
## parameters
VERBOSE=false
SUBREDDIT=""
DL_DIR=""
FREQUENCY=""
## number of characters for progress bar in the terminal
PROGRESS_BAR_WIDTH=90
## user agent for curl of reddit json api
## needs to be passed otherwise reddit blocks requests
FAKE_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"


create_progress_bar() { 
    progress=$1 
    total=$2 
    scaled_progress=$3 
    max_width=$4 
    progress_bar="" 

    for _ in $(seq 1 "$scaled_progress"); do 
        progress_bar="$progress_bar#" 
    done 

    for _ in $(seq $((scaled_progress+1)) "$max_width"); do 
        progress_bar="$progress_bar." 
    done 

    progress_bar="$progress_bar [$progress/$total]" 
    printf "\r%s" "$progress_bar" 
} 
 
progress_print(){ 
    progress=$1 
    total_amount=$2 
    max_width=$3 
    scaled_progress=$(echo "$max_width/$total_amount*$progress" | bc -l)

    # rounding up floating points
    # is there a cleaner way to do this?
    case $scaled_progress in 
        *"."*)
            scaled_progress=$(echo "scale=0; ($scaled_progress + 1)/1" | bc)
            ;;
    esac

    create_progress_bar "$progress" "$total_amount" "$scaled_progress" "$max_width" 
}

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
    elif [ "$FREQUENCY" != "day" ] && [ "$FREQUENCY" != "week" ]  && 
         [ "$FREQUENCY" != "month" ] && [ "$FREQUENCY" != "year" ] && 
         [ "$FREQUENCY" != "all" ]; then
       echo "Error: Invalid frequency $FREQUENCY provided. Either leave parameter -f|--frequency empty or set to day|week|month|year|all"
       exit 1 
    fi
}

get_frequency_string(){
    frequency=$1
    frequency_string=""
    case "$FREQUENCY" in
        day)    frequency_string="today";;
        week)   frequency_string="the week";;
        month)  frequency_string="the month";;
        year)   frequency_string="the year";;
        all)    frequency_string="all time";;
        *)   echo "Error: Invalid frequency $FREQUENCY provided. Either leave parameter -f|--frequency empty or set to day|week|month|year|all"; exit 1 ;;
    esac
    echo "$frequency_string"
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


download_images(){
    dl_dir=$1
    frequency=$2
    subreddit=$3
    frequency_string=$(get_frequency_string "$frequency")

    debug_print "DIRECTORY: $dl_dir, frequency: $frequency, subreddit: $subreddit, VERBOSE: $VERBOSE"

    top_url="https://www.reddit.com/r/$subreddit/top.json?limit=100&t=$frequency"

    debug_print "Attempting to download JSON metadata from /r/$subreddit"

    http_code=$(curl -A "$FAKE_USER_AGENT" -s -w "%{http_code}" "$top_url" -o posts.json)
    check_http_code "$http_code"

    number_images=$(jq -r '[.data.children | .[].data | select(.post_hint=="image")] | length' posts.json)
    urls=$(jq -r '.data.children | .[].data | select(.post_hint=="image") | .url' posts.json)

    if [ ! -d "$dl_dir" ]; then
        debug_print "$dl_dir does not exist, creating"
        mkdir "$dl_dir"
    fi

    dl_folder_abs=$(realpath "$dl_dir")

    echo "Downloading top $number_images images of $frequency_string from /r/$subreddit"

    downloaded=0
    skipped=0
    errors=0
    image_index=0
    error_urls=""

    for url in $urls; do
        image_index=$((image_index+1))
        $VERBOSE || progress_print "$image_index" "$number_images" "$PROGRESS_BAR_WIDTH"
        filename=$(basename "$url")
        filename_abs="$dl_folder_abs/$filename"
        if [ ! -f "$filename_abs" ]; then
            debug_print "Downloading $filename from $url"
            curl "$url" -s -o "$filename_abs"
            if file "$filename_abs" | grep empty > /dev/null; then
                debug_print "Error downloading file $url"
                rm "$filename_abs"
                errors=$((errors+1))
                error_urls="$error_urls    $url\n"
            else
                downloaded=$((downloaded+1))
            fi
        else
            debug_print "File $filename exists under $filename_abs, skipping"
            skipped=$((skipped+1))
        fi
    done

    echo ""
    echo ""
    echo "Finished. Total: $total,  downloaded: $downloaded, skipped: $skipped, errors: $errors"
    if [ -n "$error_urls" ]; then
        echo "Following images could not be downloaded"
        echo "$error_urls"
    fi

    rm -f posts.json
}

parse_args "$@"
process_args

download_images "$DL_DIR" "$FREQUENCY" "$SUBREDDIT"