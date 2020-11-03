#!/bin/bash

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR"/repoman_utils.sh

case $(jq_read "$JSON_ARG" command) in

    *"view_all"*)
        # View list of github issues / pull requests
        RESULT=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            "$GITHUB_API/$REPO_PATH/issues?state=open&per_page=10&page=$(jq_read "$JSON_ARG" page)")

        # Default sort by when it was updated
        RESPONSE=$(echo "$RESULT" | jq -c -r '[. |= sort_by(.updated_at) | reverse[]]')
        ;;

    *"view_labels"*)
        # Get current + all labels to compare
        CURRENT_LABELS=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/labels")
        ALL_LABELS=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            "$GITHUB_API/$REPO_PATH/labels")

        ACTIVE_LABELS=$(jq -n "$CURRENT_LABELS + $ALL_LABELS" | jq 'group_by(.) |
            map(select(length>1)) | map(.[] + {active: "yes"}) | . |= unique_by(.id)')
        REMAINING_LABELS=$(jq -n "$CURRENT_LABELS + $ALL_LABELS" | jq 'group_by(.) | map(select(length==1)[0])')

        RESPONSE=$(jq -n "$ACTIVE_LABELS + $REMAINING_LABELS")
        ;;

    *"update_labels"*)
        UPDATE_LABELS=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"labels\": $(jq_read "$JSON_ARG" labels)}" \
            -X PUT "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/labels")

        RESPONSE=$("$UPDATE_LABELS")
        ;;

    *"view"*)
        PATH_TYPE="$(jq_read "$JSON_ARG" type)"
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            PATH_TYPE="pulls"
        fi

        # View issue details and comments
        ISSUE_RESULT=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            -H "Accept: $GITHUB_REACTIONS" \
            "$GITHUB_API/$REPO_PATH/$PATH_TYPE/$(jq_read "$JSON_ARG" number)")

        COMMENTS_RESULT=$(curl -o /dev/null -s \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
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
                -A "$REPOMAN_UA" \
                -bc /tmp/repoman-cookies \
                -H "Authorization: token $API_KEY" \
                -H "Accept: $GITHUB_REACTIONS" \
                "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

            COMMENTS_RESULT=$(jq -n "$ISSUE_COMMENTS + $COMMENTS_RESULT" | jq '. |= sort_by(.updated_at)')
        fi

        # Combine comments and issue info into one json object
        RESPONSE=$(jq -n "$ISSUE_RESULT + {comments: $COMMENTS_RESULT}")
        ;;

    *"comment"*)
        # Post a comment on the current issue
        RESULT=$(curl -o /dev/null -s \
            -w "%{http_code}" \
            -A "$REPOMAN_UA" \
            -bc /tmp/repoman-cookies \
            -H "Authorization: token $API_KEY" \
            --data "{\"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\"}" \
            -X POST "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)/comments")

        RESPONSE=$("$RESULT" | jq .)
        ;;

    *"new"*)
        # Create new issue/PR/MR
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            RESULT="{}"
        else
            RESULT=$(curl -o /dev/null -s \
                -w "%{http_code}" \
                -A "$REPOMAN_UA" \
                -bc /tmp/repoman-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"title\": \"$(jq_read "$JSON_ARG" title)\", \"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\"}" \
                -X POST "$GITHUB_API/$REPO_PATH/issues")
        fi

        RESPONSE=$("$RESULT" | jq -r .)
        ;;
    *"close"*)
        # Close issue/PR/MR
        if [[ "$(jq_read "$JSON_ARG" pr)" == "1" ]]; then
            RESULT="{}"
        else
            RESULT=$(curl -o /dev/null -s \
                -w "%{http_code}" \
                -A "$REPOMAN_UA" \
                -bc /tmp/repoman-cookies \
                -H "Authorization: token $API_KEY" \
                --data "{\"state\": \"closed\"}" \
                -X PATCH "$GITHUB_API/$REPO_PATH/issues/$(jq_read "$JSON_ARG" number)")
        fi

        RESPONSE=$("$RESULT" | jq -r .)
        ;;
    *)
        echo "ERROR: Unrecognized command"
        exit 1
        ;;
esac

# Encrypt and write response to cache and echo back to vim
echo "$RESPONSE" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt \
    -out "$CACHE_DIR/.$(jq_read "$JSON_ARG" command).repoman" \
    -k "$(jq_read "$JSON_ARG" token_pw)"
echo "$RESPONSE"
