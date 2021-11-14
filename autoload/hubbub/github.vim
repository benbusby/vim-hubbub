" =========================================================================
" File:    autoload/hubbub/github.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A constructor and collection of functions for interacting
" with the GitHub API.
" =========================================================================
scriptencoding utf-8
let s:footer = '\n\n<sub>— _%s with [vim-hubbub](https://github.com/benbusby/vim-hubbub)!_</sub>'

" =========================================================================
" GitHub API
" =========================================================================
let s:api_root = 'https://api.github.com/user/repos'
let s:reactions_type = 'application/vnd.github.squirrel-girl-preview'
let s:multiline_type = 'application/vnd.github.comfort-fade-preview+json'
let s:diff_type = 'application/vnd.github.v3.diff'
let s:curl = hubbub#request#Curl(s:reactions_type . ', ' . s:multiline_type)
let s:constants = hubbub#constants#Constants()

" The primary class for interfacing with the GitHub API.
"
" Args:
" - token_pw: the password for the user's encrypted token
"
" Returns:
" - (API) the API object for sending requests to GitHub
function! hubbub#github#API(token_pw) abort
    let l:github_api = 'https://api.github.com/repos/' . hubbub#utils#GetRepoPath()
    let request = {
        \'token_pw': a:token_pw,
        \'api_path': l:github_api
    \}

    " --------------------------------------------------------------
    " Info ---------------------------------------------------------
    " --------------------------------------------------------------
    function! request.RepoInfo() abort
        return json_decode(s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path))
    endfunction

    " --------------------------------------------------------------
    " Views --------------------------------------------------------
    " --------------------------------------------------------------
    function! request.ViewRepos(hubbub) abort
        return json_decode(s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \s:api_root . '?sort=updated&type=owner&per_page=10&page=' .
            \a:hubbub.page))
    endfunction

    function! request.ViewAll(hubbub) abort
        return json_decode(s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues?state=open&per_page=10&sort=updated&page=' . a:hubbub.page,
            \{}, ''))
    endfunction

    function! request.View(hubbub) abort
        let l:path_type = (a:hubbub.pr ? 'pulls' : 'issues')
        let l:token = hubbub#utils#ReadToken(self.token_pw)

        let l:issue_result = json_decode(s:curl.Send(
            \l:token, self.api_path . '/' . l:path_type .
            \'/' . a:hubbub.number))

        let l:comments_result = json_decode(s:curl.Send(
            \l:token, self.api_path . '/' . l:path_type .
            \'/' . a:hubbub.number . '/comments'))

        " If this is a pull request, we need to format the comments so that
        " comments on the same code changes appear grouped together
        if a:hubbub.pr
            let l:idx = 0
            while l:idx < len(l:comments_result)
                let l:comment = l:comments_result[l:idx]
                let l:formatted_comment = FormatReviewComment(l:comment)
                if has_key(l:comment, 'in_reply_to_id')
                    let l:comment_index = FindItemIndex(l:comments_result, 'id', l:comment['in_reply_to_id'])
                    call add(l:comments_result[l:comment_index]['review_comments'], l:formatted_comment)
                    call remove(l:comments_result, l:idx)
                else
                    let comment['review_comments'] = [l:formatted_comment]
                endif

                let l:idx += 1
            endwhile

            let l:comments_result = l:comments_result +
                \json_decode(s:curl.Send(
                \l:token, self.api_path . '/issues/' . a:hubbub.number . '/comments'))
        endif

        let l:issue_result['comments'] = l:comments_result
        return l:issue_result
    endfunction

    " --------------------------------------------------------------
    " Comments -----------------------------------------------------
    " --------------------------------------------------------------

    function! request.PostComment(hubbub) abort
        let l:footer = ''
        if exists('g:hubbub_footer') && g:hubbub_footer
            let l:footer = printf(s:footer, 'Posted')
        endif

        let l:comment_data = '{"body": "' .
            \hubbub#utils#SanitizeText(a:hubbub.body, 1) . l:footer .
            \'"}'

        let l:reply_path = a:hubbub.parent_id > 0
            \? '/' . a:hubbub.parent_id . '/replies'
            \: ''
        let l:type = empty(l:reply_path) ? 'issues' : 'pulls'

        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . l:type . '/' . a:hubbub.number .
            \'/comments' . l:reply_path,
            \l:comment_data, 'POST')

        "let l:temp_comment = {
            "\'created_at': strftime('%G-%m-%d %H:%M:%S'),
            "\'body': a:hubbub.body,
            "\'user': {'login': 'You'}
        "\}
        "call hubbub#utils#AddLocalComment(
            "\l:temp_comment, a:hubbub.current_issue, a:hubbub.token_pw)
    endfunction

    function! request.DeleteComment(hubbub) abort
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . a:hubbub.type . '/comments/' . a:hubbub.comment_id,
            \{}, 'DELETE')
    endfunction

    function! request.EditComment(hubbub) abort
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . a:hubbub.type . '/comments/' . a:hubbub.comment_id,
            \'{"body": "' . hubbub#utils#SanitizeText(a:hubbub.body, 1) . '"}', 'PATCH')
    endfunction

    " --------------------------------------------------------------
    " Issues/PRs ---------------------------------------------------
    " --------------------------------------------------------------

    function! request.NewItem(hubbub) abort
        let l:type = 'issues'
        let l:footer = ''
        if exists('g:hubbub_footer') && g:hubbub_footer
            let l:footer = printf(s:footer, 'Created')
        endif

        let l:item_data = '
            \"title": "' . hubbub#utils#SanitizeText(a:hubbub.title, 1) . '",
            \"body": "' . hubbub#utils#SanitizeText(a:hubbub.body, 1) . l:footer . '"
        \'

        if a:hubbub.pr
            let l:type = 'pulls'
            let l:item_data = '{' . l:item_data . '
                \,"head": "' . a:hubbub.head . '","base":"' . a:hubbub.base . '"}'
        else
            let l:item_data = '{' . l:item_data . '}'
        endif

        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . l:type,
            \l:item_data, 'POST')
    endfunction

    function! request.UpdateIssue(hubbub) abort
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:hubbub.number,
            \'{"title": "' . hubbub#utils#SanitizeText(a:hubbub.title, 1) . '",' .
            \'"body": "' . hubbub#utils#SanitizeText(a:hubbub.body, 1) . '"}',
            \'PATCH')
    endfunction

    function! request.CloseItem(hubbub) abort
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:hubbub.number,
            \'{"state": "closed"}', 'PATCH')
    endfunction

    " --------------------------------------------------------------
    " PRs only -----------------------------------------------------
    " --------------------------------------------------------------

    function! request.Merge(hubbub) abort
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/pulls/' . a:hubbub.number . '/merge',
            \'{"merge_method": "' . a:hubbub.method . '"}', 'PUT')
    endfunction

    function! request.Review(hubbub) abort
        let l:curl = hubbub#request#Curl(s:diff_type)
        if a:hubbub.action =~# 'new'
            return l:curl.Send(
                \hubbub#utils#ReadToken(self.token_pw),
                \self.api_path . '/pulls/' . a:hubbub.number)
        else
            " Extract review comments
            let l:comments = []
            let l:event = a:hubbub.action ==# 'PENDING' ?
                \'' : '"event": "' . a:hubbub.action . '"'
            let l:body = empty(a:hubbub.body) ?
                \'' : '"body": "' . a:hubbub.body . '"'
            for item in items(b:review_comments)
                let l:comment = item[1]

                " Single-line and multi-line comments use different parameters
                " for determining where they appear in the review. See
                " hubbub#buffers#Buffers->CreateReviewBuffer for more info.
                let l:key_filter = s:constants.multiline_keys
                if l:comment.start_line ==# l:comment.line
                    let l:key_filter = s:constants.singleline_keys
                endif
                for key_val in items(l:comment)
                    if index(l:key_filter, key_val[0]) < 0
                        call remove(l:comment, key_val[0])
                    endif
                endfor
                call add(l:comments, l:comment)
            endfor

            return l:curl.Send(
                \hubbub#utils#ReadToken(self.token_pw),
                \self.api_path . '/pulls/' . a:hubbub.number . '/reviews',
                \'{' . l:event . (!empty(l:event) ? ',' : '') .
                \l:body . (!empty(l:body) ? ',' : '') .
                \'"comments": ' . substitute(json_encode(l:comments), '<br>', '\\n', 'ge') .
                \'}', 'POST')
        endif
    endfunction

    " --------------------------------------------------------------
    " Labels -------------------------------------------------------
    " --------------------------------------------------------------

    function! request.ViewLabels(hubbub) abort
        " Need to fetch all labels, then cross check against issue labels
        let l:current_labels = json_decode(s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:hubbub.number . '/labels'))
        let l:all_labels = json_decode(s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/labels'))

        for label in l:all_labels
            if index(l:current_labels, label) >= 0
                let label['active'] = 1
            endif
        endfor

        return l:all_labels
    endfunction

    function! request.UpdateLabels(hubbub) abort
        let l:labels = substitute(json_encode(a:hubbub.labels), "'", "'\"'\"'", 'ge')
        call s:curl.Send(
            \hubbub#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:hubbub.number . '/labels',
            \'{"labels": ' . l:labels . '}', 'PUT')
    endfunction

    " --------------------------------------------------------------
    " Reactions ----------------------------------------------------
    " --------------------------------------------------------------
    function! request.PostReaction(hubbub) abort
        if a:hubbub.type ==# 'comment'
            call s:curl.Send(
                \hubbub#utils#ReadToken(self.token_pw),
                \self.api_path . '/issues/comments/' . a:hubbub.id . '/reactions',
                \'{"content": "' . a:hubbub.reaction . '"}', 'POST')
        elseif a:hubbub.type ==# 'issue'
            call s:curl.Send(
                \hubbub#utils#ReadToken(self.token_pw),
                \self.api_path . '/issues/' . a:hubbub.id . '/reactions',
                \'{"content": "' . a:hubbub.reaction . '"}', 'POST')
        endif
    endfunction

    " =====================================================================
    " Formatting
    " =====================================================================
    function! FormatReviewComment(comment) abort
        return {
            \'id': a:comment['id'],
            \'reactions': a:comment['reactions'],
            \'login': a:comment['user']['login'],
            \'body': a:comment['body'],
            \'created_at': a:comment['created_at'],
            \'author_association': a:comment['author_association']
        \}
    endfunction

    function! FindItemIndex(list, key, value) abort
        let l:index = 0
        while l:index < len(a:list)
            if a:list[l:index][a:key] == a:value
                return l:index
            endif
            let l:index += 1
        endwhile

        return -1
    endfunction

    return request
endfunction
