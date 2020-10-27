#!/bin/bash

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR"/vimgmt_utils.sh

case $(jq_read "$JSON_ARG" command) in

    *"view_all"*)
        # View list of github issues / pull requests
        RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            "$GITHUB_API/repos/$REPO_PATH/issues?state=open")

        # Default sort by when it was updated
        echo "$RESULT" | jq -r '[. |= sort_by(.updated_at) | reverse[]]'
        ;;

    *"view"*)
        # View issue details and comments
        ISSUE_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            -H "Accept: $GITHUB_REACTIONS" \
            "$GITHUB_API/repos/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)")

        COMMENTS_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            -H "Accept: $GITHUB_REACTIONS" \
            "$GITHUB_API/repos/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

        # Combine comments and issue info into one json object
        echo "$ISSUE_RESULT" > /tmp/.tmp.issue.json
        echo "$COMMENTS_RESULT" > /tmp/.tmp.comments.json
        jq -s '.[0] + {comments: .[1]}' /tmp/.tmp.issue.json /tmp/.tmp.comments.json

        rm -f /tmp/.tmp.issue.json
        rm -f /tmp/.tmp.comments.json
        ;;

    *"comment"*)
        # Post a comment on the current issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$VIMGMT_USERNAME_GH" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\"}" \
            -X POST "$GITHUB_API/repos/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

        echo "$RESULT" | jq .
        ;;

    *"new"*)
        # Create new issue/PR/MR
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            RESULT="{}"
        else
            RESULT=$(curl -o /dev/null -s \
                -w "%{http_code}" \
                -A "$VIMGMT_USERNAME_GH" \
                -bc /tmp/vimgmt-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"title\": \"$(jq_read "$JSON_ARG" title)\", \"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\", \"labels\": [\"$(jq_read "$JSON_ARG" labels)\"]}" \
                -X POST "https://api.github.com/repos/$REPO_PATH/issues")
        fi

        echo "$RESULT" | jq -r .
        ;;
    *"close"*)
        # Close issue/PR/MR
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            RESULT="{}"
        else
            RESULT=$(curl -o /dev/null -s \
                -w "%{http_code}" \
                -A "$VIMGMT_USERNAME_GH" \
                -bc /tmp/vimgmt-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"state\": \"closed\"}" \
                -X PATCH "https://api.github.com/repos/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)")
        fi

        echo "$RESULT" | jq -r .
        ;;
    *)
        echo "ERROR: Unrecognized command"
        exit 1
        ;;
esac
