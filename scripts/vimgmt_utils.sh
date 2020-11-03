#!/bin/bash

PREFIXES=("https://github.com/" "git@github.com:" "https://gitlab.com/" "git@gitlab.com:")
SUFFIXES=(".git")
REPO_PATH=$(git ls-remote --get-url)

# API Paths
export GITHUB_API="https://api.github.com/repos"
export GITLAB_API="https://gitlab.com/api/v4/projects"

# User Agent
export VIMGMT_UA="benbusby/vimgmt"

# Footers for issues/comments
export FOOTER="<hr>\n\n<sub>_Posted with [vimgmt](https://github.com/benbusby/vimgmt)!_</sub>"

# GitHub extra media types (enables receiving reactions, multi-line review comments, etc)
# application/vnd.github.squirrel-girl-preview -- reactions
# application/vnd.github.comfort-fade-preview+json -- review multiline comments
export GITHUB_REACTIONS="application/vnd.github.squirrel-girl-preview"
export GITHUB_MULTILINE="application/vnd.github.comfort-fade-preview+json"

# Setup path for encrypting responses into the local cache
SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export CACHE_DIR="$SCRIPT_DIR/.."

# -------------------------------------------------
# Initialization
# -------------------------------------------------

# Exit early if not in a git repo
if [[ -z "$REPO_PATH" ]]; then
    echo "Not in a git repo"
    exit 1
fi

# Clean up prefixes/suffixes to determine <username>/<repo> string
for PREFIX in "${PREFIXES[@]}"; do
    REPO_PATH=${REPO_PATH#"$PREFIX"}
done

for SUFFIX in "${SUFFIXES[@]}"; do
    REPO_PATH=${REPO_PATH%"$SUFFIX"}
done

# -------------------------------------------------
# Functions
# -------------------------------------------------

function jq_read {
    # Returns the value for a key ($2)
    # within a json string ($1)
    # Usage: jq_read "$1" $2
    echo "$1" | jq -r ."$2"
}

function get_path {
    echo "$REPO_PATH"
}
