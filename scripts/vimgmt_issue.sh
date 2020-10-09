#!/bin/bash
# Script for viewing and commenting on a single github/gitlab issue
#
# Usage: ./vimgmt.sh <token pw> <command (comment|view)> <issue id> [comment str]

PREFIXES=("https://github.com/" "git@github.com:" "https://gitlab.com/" "git@gitlab.com:")
SUFFIXES=(".git")
REPO_PATH=$(git ls-remote --get-url)
TOKEN_PW="$1"
COMMAND="$2"
ISSUE_ID="$3"
COMMENT="$4"

function github_command {
    API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in $VIMGMT_TOKEN_GH -k $TOKEN_PW)"
    FOOTER="<sub>_— Posted with [vimgmt](https://github.com/benbusby/vimgmt)</a>_</sub>"

    if [[ "$COMMAND" == "comment" ]]; then
        # Post a comment on the current issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"body\": \"$COMMENT\n\n$FOOTER\"}" \
            -X POST "https://api.github.com/repos/$REPO_PATH/issues/$ISSUE_ID/comments")

        echo $RESULT | jq .
    elif [[ "$COMMAND" == "view" ]]; then
        # View issue details and comments
        ISSUE_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            "https://api.github.com/repos/${REPO_PATH}/issues/$ISSUE_ID")

        COMMENTS_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            "https://api.github.com/repos/${REPO_PATH}/issues/$ISSUE_ID/comments")

        # Combine comments and issue info into one json object
        echo $ISSUE_RESULT > /tmp/.tmp.issue.json
        echo $COMMENTS_RESULT > /tmp/.tmp.comments.json
        jq -s '.[0] + {comments: .[1]}' /tmp/.tmp.issue.json /tmp/.tmp.comments.json

        rm -f /tmp/.tmp.issue.json
        rm -f /tmp/.tmp.comments.json
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

}

function gitlab_command {
    API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in $VIMGMT_TOKEN_GL -k $TOKEN_PW)"

    # GitLab requires the repo path to be url encoded
    REPO_PATH=${REPO_PATH//\//%2F}

    # Retrieve project id for subsequent api calls
    RESULT=$(curl -s -A "$USERNAME" \
        -H "PRIVATE-TOKEN: $API_KEY" \
        "https://gitlab.com/api/v4/projects/$REPO_PATH")
    PROJECT_ID=$(echo $RESULT | jq -r .id)

    if [[ "$COMMAND" == "comment" ]]; then
        # Create new comment on the current issue
        RESULT=$(curl -o /dev/null -s -w "%{http_code}" \
            -A "$USERNAME" \
            -H "Content-Type: application/json" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            --data "{\"body\": \"$COMMENT\"}" \
            -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues/$ISSUE_ID/notes")

        echo $RESULT | jq .
    elif [[ "$COMMAND" == "view" ]]; then
        # Split requests for issue details and comments
        ISSUE_RESULT=$(curl -s -A "$USERNAME" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues/$ISSUE_ID")
        COMMENTS_RESULT=$(curl -s -A "$USERNAME" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues/$ISSUE_ID/notes")

        # Combine comments and issue info into one json object
        echo $ISSUE_RESULT | jq '. | .number = .iid | .body = .description | .author.login = .author.username | .user = .author | del(.iid, .description, .author)' > /tmp/.tmp.issue.json
        echo $COMMENTS_RESULT | jq '[.[] | .author.login = .author.username | .user = .author | del(.author)]' > /tmp/.tmp.comments.json

        jq -s '.[0] + {comments: .[1]}' /tmp/.tmp.issue.json /tmp/.tmp.comments.json

        rm -f /tmp/.tmp.issue.json
        rm -f /tmp/.tmp.comments.json
    else
        echo "ERROR: Unknown command (should be 'create' or 'view')"
        exit 1
    fi

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
