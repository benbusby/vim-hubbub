#!/bin/bash

PREFIXES=("https://github.com/" "git@github.com:" "https://gitlab.com/" "git@gitlab.com:")
SUFFIXES=(".git")
REPO_PATH=$(git ls-remote --get-url)

# API Paths
GITHUB_API="https://api.github.com"
GITLAB_API="https://gitlab.com/api/v4"

# Footers for issues/comments
GH_FOOTER="<hr>\n\n<sub>_Posted using [vimgmt](https://github.com/benbusby/vimgmt)!_</sub>"
GL_FOOTER="<hr>\n\n<sub>_Posted using [vimgmt](https://gitlab.com/benbusby/vimgmt)!_</sub>"

# -------------------------------------------------
# Initialization
# -------------------------------------------------

# Exit early if not in a git repo
if [[ -z "$REPO_PATH" ]]; then
    echo "Not in a git repo"
    exit 1
fi

# Clean up prefixes/suffixes to determine <username>/<repo> string
for PREFIX in ${PREFIXES[@]}; do
    REPO_PATH=${REPO_PATH#"$PREFIX"}
done

for SUFFIX in ${SUFFIXES[@]}; do
    REPO_PATH=${REPO_PATH%"$SUFFIX"}
done

# -------------------------------------------------
# Functions
# -------------------------------------------------

function jq_read {
    # Returns the value for a key ($2)
    # within a json string ($1)
    # Usage: jq_read "$1" $2
    echo $1 | jq -r .$2
}
