#!/bin/bash
# Script for viewing and creating github/gitlab issues
#
# Usage: ./vimgmt.sh <token pw> <command (create|view)> [issue title] [issue body] [label]

PREFIXES=("https://github.com/" "git@github.com:" "https://gitlab.com/" "git@gitlab.com:")
SUFFIXES=(".git")
REPO_PATH=$(git ls-remote --get-url)
TOKEN_PW="$1"
COMMAND="$2"
TITLE="$3"
BODY="$4"
LABEL="$5"

function github_command {
    FOOTER="<hr>\n\n<sub>_This issue was created with [vimgmt](https://github.com/benbusby/vimgmt)!_</sub>"

    API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in $VIMGMT_TOKEN_GH -k $TOKEN_PW)"
    if [[ "$COMMAND" == "create" ]]; then
        # Create new issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"title\": \"$TITLE\", \"body\": \"$BODY\n\n$FOOTER\", \"labels\": [\"$LABEL\"]}" \
            -X POST "https://api.github.com/repos/$REPO_PATH/issues")
    elif [[ "$COMMAND" == "view" ]]; then
        # View list of github issues / pull requests
        RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            "https://api.github.com/repos/${REPO_PATH}/issues?state=open")
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

    echo $RESULT | jq -r .
}

function gitlab_command {
    FOOTER="<hr>\n\n<sub>_This issue was created with [vimgmt](https://gitlab.com/benbusby/vimgmt)!_</sub>"
    API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in $VIMGMT_TOKEN_GL -k $TOKEN_PW)"

    # GitLab requires the repo path to be url encoded
    REPO_PATH=${REPO_PATH//\//%2F}

    # Retrieve project id for subsequent api calls
    RESULT=$(curl -s -A "$USERNAME" \
        -H "PRIVATE-TOKEN: $API_KEY" \
        "https://gitlab.com/api/v4/projects/$REPO_PATH")
    PROJECT_ID=$(echo $RESULT | jq -r .id)

    if [[ "$COMMAND" == "create" ]]; then
        # Create new placeholder issue
        RESULT=$(curl -o /dev/null -s -w "%{http_code}" \
            -A "$USERNAME" \
            -H "Content-Type: application/json" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            --data "{\"title\": \"$TITLE\", \"description\": \"$BODY\n\n$FOOTER\", \"labels\": \"$LABEL\"}" \
            -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues")
    elif [[ "$COMMAND" == "view" ]]; then
        RESULT=$(curl -s -A "$USERNAME" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues")
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

    echo $RESULT | jq '[.[] | .["number"] = .iid | .["body"] = .description | .["comments"] = .user_notes_count | del(.iid, .description, .user_notes_count) | .labels |= [{"name": .[]}]]'
    #echo $RESULT | jq .
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
