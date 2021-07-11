#!/bin/sh

SUBREDDIT=$1
DL_FOLDER=$2

if [ "$#" -ne 2 ]; then
    echo "Execute as ./srid.sh <subreddit> <dl-folder>"
    exit 1
fi

TIME=month
FAKE_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

TOP_URL="https://www.reddit.com/r/$SUBREDDIT/top.json?limit=100&t=$TIME"

echo "Attempting to download JSON metadata from /r/$SUBREDDIT"
rm -f posts.json
http_code=$(curl -A "$FAKE_USER_AGENT" -s -w "%{http_code}" "$TOP_URL" -o posts.json)
if [ "$http_code" -eq "429" ]; then
    echo "Error 429: too many requests. Maybe try changing the user agent or wait a couple of minutes"
    exit 1
elif [ "$http_code" -eq "200" ]; then
    echo "Successfully parsed metadata from $SUBREDDIT"
fi
urls=$(jq -r '.data.children | .[].data | select(.post_hint=="image") | .url' posts.json)

if [ ! -d "$DL_FOLDER" ]; then
    echo "$DL_FOLDER does not exist, creating"
    mkdir "$DL_FOLDER"
fi
dl_folder_abs=$(realpath "$DL_FOLDER")

for url in $urls; do
    filename=$(basename "$url")
    filename_abs="$dl_folder_abs/$filename"
    if [ ! -f "$filename_abs" ]; then
        echo "Downloading $filename from $url"
        curl "$url" -s -o "$filename_abs"
        if file "$filename_abs" | grep empty > /dev/null; then
            echo "Error downloading file $url"
            rm "$filename_abs"
        fi
    else
        echo "File $filename exists under $filename_abs, skipping"
    fi
done