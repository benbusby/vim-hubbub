#!/bin/bash
# Primary entry point for all external vimgmt commands
#
# Usage: ./vimgmt.sh <json>

SCRIPT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source $SCRIPT_DIR/vimgmt_utils.sh

# The script accepts a single json formatted argument to use for each
# request.
#
# Example:
# {
#    "token_pw": "supersecret",
#    "command": "view_all"
# }
export JSON_ARG="$1"

# Run command dependent on github/gitlab location
case $(git ls-remote --get-url) in
    *"github"*)
        export API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in \
            $VIMGMT_TOKEN_GH -k $(jq_read "$JSON_ARG" token_pw))"
        $SCRIPT_DIR/vimgmt_github.sh
        ;;
    *"gitlab"*)
        export API_KEY="$(openssl aes-256-cbc -d -a -pbkdf2 -in \
            $VIMGMT_TOKEN_GL -k $(jq_read "$JSON_ARG" token_pw))"
        $SCRIPT_DIR/vimgmt_gitlab.sh
        ;;
    *)
        echo "ERROR: Unrecognized repo location"
        exit 1
        ;;
esac
