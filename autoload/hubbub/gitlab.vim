" ============================================================================
" File:    autoload/hubbub/gitlab.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A constructor and collection of functions for interacting
" with the GitLab API.
" ============================================================================
scriptencoding utf-8
let s:footer = '\n\n<sub>— _%s with [vim-hubbub](https://github.com/benbusby/vim-hubbub)!_</sub>'

" ============================================================================
" GitLab API
" ============================================================================
let s:gitlab_api = 'https://gitlab.com/api/v4/projects/'

function! hubbub#gitlab#API(token_pw) abort
    let l:encoded_path = substitute(hubbub#utils#GetRepoPath(), '/', '%2F', 'ge')
    let l:project_id = json_decode(system(hubbub#request#Curl().Send(
        \hubbub#utils#ReadToken(a:token_pw),
        \s:gitlab_api . l:encoded_path, {}, '')))['id']

    let request = {
        \'token_pw': a:token_pw,
        \'api_path': s:gitlab_api . l:project_id}

    " --------------------------------------------------------------
    " Views --------------------------------------------------------
    " --------------------------------------------------------------
    function! request.ViewAll(...) abort
        let l:issues = json_decode(system(hubbub#request#Curl().Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues?state=opened',
            \{}, '')))
        let l:merge_reqs = json_decode(system(hubbub#request#Curl().Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/merge_requests?state=opened',
            \{}, '')))

        for merge_req in l:merge_reqs
            let merge_req['pull_request'] = 1
        endfor

        let l:response = l:issues + l:merge_reqs

        for item in l:response
            let item['labels'] = FormatLabels(item['labels'])
        endfor

        call sort(l:response, function('SortByDate'))
        return l:response
    endfunction

    function! request.View(hubbub) abort
        let l:path_type = (a:hubbub.pr ? 'merge_requests' : 'issues')
        let l:token = hubbub#utils#ReadToken(self.token_pw)

        let l:issue_result = json_decode(system(
            \hubbub#request#Curl().Send(
            \l:token, self.api_path . '/' . l:path_type . '/' . a:hubbub.number,
            \{}, '')))
        let l:issue_result['labels'] = FormatLabels(l:issue_result['labels'])

        let l:comments_result = json_decode(system(
            \hubbub#request#Curl().Send(
            \l:token, self.api_path . '/' . l:path_type . '/' . a:hubbub.number . '/notes')))

        " If this is a merge request, we have to format the comments so that
        " comments on the same code changes appear grouped together
        if a:hubbub.pr
            let l:rev_comments = []
            for comment in l:comments_result
                let l:formatted_comment = FormatReviewComment(comment)
                let l:comment_index = FindItemIndex(l:rev_comments, 'diff_hunk', comment['diff_hunk'])

                if l:comment_index > 0
                    call add(l:rev_comments[l:comment_index]['review_comments'], formatted_comment)
                else
                    let comment['review_comments'] = l:formatted_comment
                    call add(l:rev_comments, comment)
                endif
            endfor

            let l:comments_result = l:rev_comments + json_decode(system(hubbub#request#Send(
                \l:token, self.api_path . '/issues/' . a:hubbub.number . '/comments')))
        endif

        echo l:comments_result
        let l:issue_result['user_notes_count'] = l:comments_result
        return l:issue_result
    endfunction

    " --------------------------------------------------------------
    " Comments -----------------------------------------------------
    " --------------------------------------------------------------
    function! request.PostComment(hubbub) abort
        let l:footer = ''
        if !exists('g:hubbub_footer') || g:hubbub_footer
            let l:footer = printf(s:footer, 'Posted')
        endif

        let l:comment_data = '{"body": "' .
            \hubbub#utils#SanitizeText(a:hubbub.body) . l:footer .
            \'"}'

        call system(hubbub#request#Curl().BackgroundSend(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:hubbub.number . '/notes',
            \l:comment_data, 'POST'))

        let l:temp_comment = {
            \'created_at': strftime('%G-%m-%d %H:%M:%S'),
            \'body': a:hubbub.body,
            \'author': {'username': 'You'}
        \}
        call hubbub#utils#AddLocalComment(
            \l:temp_comment, a:hubbub.current_issue, a:hubbub.token_pw)
    endfunction

    " --------------------------------------------------------------
    " Issues/PRs ---------------------------------------------------
    " --------------------------------------------------------------
    function! request.NewItem(hubbub) abort
        let l:footer = ''
        if !exists('g:hubbub_footer') || g:hubbub_footer
            let l:footer = printf(s:footer, 'Created')
        endif

        let l:issue_data = '{
            \"title": "' . hubbub#utils#SanitizeText(a:hubbub.title) . '",
            \"description": "' . hubbub#utils#SanitizeText(a:hubbub.body) . l:footer . '"
        \}'

        call system(hubbub#request#Curl().Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues',
            \l:issue_data, 'POST'))
    endfunction

    " ============================================================================
    " Formatting
    " ============================================================================
    function! SortByDate(left, right) abort
        if a:left['updated_at'] ==# a:right['updated_at']
            return 0
        elseif a:left['updated_at'] ># a:right['updated_at']
            return -1
        else
            return 1
        endif
    endfunction

    function! FormatLabels(labels) abort
        let l:new_labels = []
        for label in a:labels
            call add(l:new_labels, {'name': label})
        endfor

        return l:new_labels
    endfunction

    return request
endfunction
