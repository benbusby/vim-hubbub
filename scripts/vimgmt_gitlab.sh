#!/bin/bash

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR"/vimgmt_utils.sh

# GitLab requires the repo path to be url encoded
REPO_PATH=${REPO_PATH//\//%2F}

# Retrieve project id for subsequent api calls
RESULT=$(curl -s -A "$VIMGMT_USERNAME_GL" \
    -H "PRIVATE-TOKEN: $API_KEY" \
    "$GITLAB_API/projects/$REPO_PATH")
PROJECT_ID=$(echo "$RESULT" | jq -r .id)

case $(jq_read "$JSON_ARG" command) in

    *"view_all"*)
        # GitLab needs issues and merge requests combine to replicate
        # the combined issues/requests view from GitHub
        ISSUE_RESULT=$(curl -s -A "$VIMGMT_USERNAME_GL" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "$GITLAB_API/projects/$PROJECT_ID/issues?state=opened")
        MR_RESULT=$(curl -s -A "$VIMGMT_USERNAME_GL" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "$GITLAB_API/projects/$PROJECT_ID/merge_requests?state=opened")

        echo "$ISSUE_RESULT" | jq '[.[] |
            .["number"] = .iid |
            .["body"] = .description |
            .["comments"] = .user_notes_count |
            del(.iid, .description, .user_notes_count) |
            .labels |= [{"name": .[]}]]' > /tmp/.vimgmt.issue.json
        echo "$MR_RESULT" | jq '[.[] |
            .["number"] = .iid |
            .["body"] = .description |
            .["comments"] = .user_notes_count |
            .["pull_request"] = 1 |
            del(.iid, .description, .user_notes_count) |
            .labels |= [{"name": .[]}]]' > /tmp/.vimgmt.mr.json

        jq -s '[.[][]]' /tmp/.vimgmt.issue.json /tmp/.vimgmt.mr.json > /tmp/.vimgmt.group.json
        jq -r '[. |= sort_by(.updated_at) | reverse[]]' /tmp/.vimgmt.group.json

        rm -f /tmp/.vimgmt.*
        ;;

    *"view"*)
        # Split requests for issue details and comments
        ISSUE_RESULT=$(curl -s -A "$VIMGMT_USERNAME_GL" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "$GITLAB_API/projects/$PROJECT_ID/issues/$(jq_read "$JSON_ARG" number)")
        COMMENTS_RESULT=$(curl -s -A "$VIMGMT_USERNAME_GL" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            "$GITLAB_API/projects/$PROJECT_ID/issues/$(jq_read "$JSON_ARG" number)/notes")

        # Combine comments and issue info into one json object
        echo "$ISSUE_RESULT" | jq '. |
            .number = .iid |
            .body = .description |
            .author.login = .author.username |
            .user = .author |
            del(.iid, .description, .author)' > /tmp/.vimgmt.issue.json

        # Retrieve and format comments for the issue, removing system messages
        echo "$COMMENTS_RESULT" | jq '[.[] |
            .author.login = .author.username |
            .user = .author |
            del(.author) ] |
            map(select(.system != true))' > /tmp/.vimgmt.comments.json

        jq -r -s '.[0] + {comments: .[1]}' /tmp/.vimgmt.issue.json /tmp/.vimgmt.comments.json

        rm -f /tmp/.vimgmt.*
        ;;

    *"comment"*)
        # Create new comment on the current issue
        RESULT=$(curl -o /dev/null -s -w "%{http_code}" \
            -A "$VIMGMT_USERNAME_GL" \
            -H "Content-Type: application/json" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            --data "{\"body\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\"}" \
            -X POST "$GITLAB_API/projects/$PROJECT_ID/issues/$(jq_read "$JSON_ARG" number)/notes")

        echo "$RESULT" | jq .
        ;;

    *"new_issue"*)
        # Create new placeholder issue
        RESULT=$(curl -o /dev/null -s -w "%{http_code}" \
            -A "$USERNAME" \
            -H "Content-Type: application/json" \
            -H "PRIVATE-TOKEN: $API_KEY" \
            --data "{\"title\": \"$(jq_read "$JSON_ARG" title)\", \"description\": \"$(jq_read "$JSON_ARG" body)\n\n$FOOTER\", \"labels\": \"$(jq_read "$JSON_ARG" labels)\"}" \
            -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/issues")
        echo "$RESULT" | jq .
        ;;

    *)
        echo "ERROR: Unrecognized command"
        exit 1
        ;;
esac
