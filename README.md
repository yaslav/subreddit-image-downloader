# subreddit-image-downloader
Downloads images from top posts in a subreddit, up to max. 100 per week/day/month/year/all.
# Requirements
*curl* needed to download JSON data, *jq* to parse JSON data, *tput* from ncurses package for progress bar
# Execution
```
./srid.sh [options]
  -d|--directory          Directory to store downloaded images"
  -f|--frequency          Post frequency (day|week|month|year|all)"
  -s|--subreddit          Subreddit name from which to download images"
  -j|--json               Alternatively: json file containing above parameters"
  -h|--help               Print help"
  -v|--verbose            Print debug messages"
```
## Example
```
./srid.sh -d ~/Pictures/pics -s pics -f week
./srid.sh -j subreddits.json
```
