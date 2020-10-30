#!/bin/bash

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR"/vimgmt_utils.sh

case $(jq_read "$JSON_ARG" command) in

    *"view_all"*)
        # View list of github issues / pull requests
        RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_UA" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            "$GITHUB_API/$REPO_PATH/issues?state=open")

        # Default sort by when it was updated
        #echo "$RESULT" | jq -r '[. |= sort_by(.updated_at) | reverse[]]'
        echo $RESULT
        ;;

    *"view"*)
        PATH_TYPE="$(jq_read "$JSON_ARG" type)"
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            PATH_TYPE="pulls"
        fi

        # View issue details and comments
        ISSUE_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_UA" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            -H "Accept: $GITHUB_REACTIONS" \
            "$GITHUB_API/$REPO_PATH/$PATH_TYPE/$(jq_read "$JSON_ARG" number)")

        COMMENTS_RESULT=$(curl -o /dev/null -s \
            -A "$VIMGMT_UA" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            -H "Accept: $GITHUB_REACTIONS" \
            "$GITHUB_API/$REPO_PATH/$PATH_TYPE/$(jq_read "$JSON_ARG" number)/comments")

        # Also need issue comments if in a pull request
        if [[ "$(jq_read "$JSON_ARG" type)" == "pulls" ]]; then
            COMMENTS_RESULT=$(echo "$COMMENTS_RESULT" | jq 'group_by( [.diff_hunk]) | map((.[0]|del(.body)) +
                { review_comments: (map(
                { comment_id: .id } +
                { login: .user.login } +
                { comment: .body } +
                { created_at: .created_at } +
                { author_association: .author_association} +
                { reactions: .reactions })) })')

            ISSUE_COMMENTS=$(curl -o /dev/null -s \
                -A "$VIMGMT_UA" \
                -bc /tmp/vimgmt-cookies \
                -H "Authorization: token $API_KEY" \
                -H "Accept: $GITHUB_REACTIONS" \
                "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

            COMMENTS_RESULT=$(jq -n "$ISSUE_COMMENTS + $COMMENTS_RESULT" | jq '. |= sort_by(.updated_at)')
        fi

        # Combine comments and issue info into one json object
        jq -n "$ISSUE_RESULT + {comments: $COMMENTS_RESULT}"
        ;;

    *"comment"*)
        # Post a comment on the current issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$VIMGMT_UA" \
            -bc /tmp/vimgmt-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\"}" \
            -X POST "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

        echo "$RESULT" | jq .
        ;;

    *"new"*)
        # Create new issue/PR/MR
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            RESULT="{}"
        else
            RESULT=$(curl -o /dev/null -s \
                -w "%{http_code}" \
                -A "$VIMGMT_UA" \
                -bc /tmp/vimgmt-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"title\": \"$(jq_read "$JSON_ARG" title)\", \"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\", \"labels\": [\"$(jq_read "$JSON_ARG" labels)\"]}" \
                -X POST "https://api.github.com/$REPO_PATH/issues")
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
                -A "$VIMGMT_UA" \
                -bc /tmp/vimgmt-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"state\": \"closed\"}" \
                -X PATCH "https://api.github.com/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)")
        fi

        echo "$RESULT" | jq -r .
        ;;
    *)
        echo "ERROR: Unrecognized command"
        exit 1
        ;;
esac
