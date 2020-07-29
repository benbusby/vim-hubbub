#!/bin/bash
# Script for viewing and creating github/gitlab issues
#
# Usage: ./vissues.sh <token file location> <command (create|view)>

PREFIXES=("https://github.com/" "git@github.com:" "https://gitlab.com/" "git@gitlab.com:")
SUFFIXES=(".git")
API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in $VISSUES_TOKEN_GH -k $1)"
REPO_PATH=$(git ls-remote --get-url)
COMMAND="$2"

function github_command {
    if [[ "$COMMAND" == "create" ]]; then
        # Create new placeholder issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$VISSUES_USERNAME_GH" \
            -bc /tmp/vissues-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"title\": \"Vissues Test\", \"body\": \"$BODY\n\n$FOOTER\", \"labels\": [\"ignore\"]}" \
            -X POST "https://api.github.com/repos/$REPO_PATH/issues")
    elif [[ "$COMMAND" == "view" ]]; then
        # View list of github issues
        RESULT=$(curl -o /dev/null -s \
            -A "$VISSUES_USERNAME_GH" \
            -bc /tmp/vissues-cookies \
            -H "Authorization: token $API_KEY" \
            "https://api.github.com/repos/${REPO_PATH}/issues?state=open")
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

    echo $RESULT | jq -r .
}

function gitlab_command {
    if [[ "$COMMAND" == "create" ]]; then
        # Create new placeholder issue
        RESULT=$(curl -o /dev/null -s -w "%{http_code}" \
            -A "$USERNAME" \
            -H "Content-Type: application/json"
            -H "PRIVATE-TOKEN: $API_KEY" \
            --data '{"title": "Vissues Test", "description": "Test\n\n<hr>\n\n<sub>_This issue was created with [Vissues](https://gitlab.com/benbusby/vissues)!_</sub>", "labels": ["ignore"]}' \
            -X POST "https://gitlab.com/repos/$REPO_PATH/issues")
    elif [[ "$COMMAND" == "view" ]]; then
        RESULT=$(curl -A "$USERNAME" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "https://gitlab.com/api/v4/repos/${REPO_PATH}/issues")
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

    echo $RESULT | jq -r .
}

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

# Run command dependent on github/gitlab location
case $(git ls-remote --get-url) in
    *"github"*)
        github_command
        ;;
    *"gitlab"*)
        gitlab_command
        ;;
    *)
        echo "ERROR: Unrecognized repo location"
        exit 1
        ;;
esac
