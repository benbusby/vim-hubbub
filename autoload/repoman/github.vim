" ============================================================================
" File:    autoload/repoman/github.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" ============================================================================
let s:footer = '<hr>\n\n<sub>_%s with [vim-repoman](https://github.com/benbusby/vim-repoman)!_</sub>'

" ============================================================================
" GitHub API
" ============================================================================
let s:github_api = 'https://api.github.com/repos/' . repoman#utils#GetRepoPath()
let s:github_reactions_type = 'application/vnd.github.squirrel-girl-preview'
let s:github_multiline_type = 'application/vnd.github.comfort-fade-preview+json'

function! repoman#github#API(token_pw) abort
    let request = {'token_pw': a:token_pw}

    " --------------------------------------------------------------
    " Views --------------------------------------------------------
    " --------------------------------------------------------------
    function! request.ViewAll(repoman) abort
        return json_decode(system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues?state=open&per_page=10&page=' . a:repoman.page,
            \{}, '')))
    endfunction

    function! request.View(repoman) abort
        let l:path_type = (a:repoman.pr ? 'pulls' : 'issues')
        let l:token = repoman#utils#ReadToken(self.token_pw)

        let l:issue_result = json_decode(system(
            \repoman#request#Curl(s:github_reactions_type).Send(
            \l:token, s:github_api . '/' . l:path_type . '/' . a:repoman.number,
            \{}, '')))

        let l:comments_result = json_decode(system(
            \repoman#request#Curl(s:github_reactions_type).Send(
            \l:token, s:github_api . '/' . l:path_type . '/' . a:repoman.number . '/comments')))

        " If this is a pull request, we have to format the comments so that
        " comments on the same code changes appear grouped together
        if a:repoman.pr
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

            let l:comments_result = l:rev_comments + json_decode(system(repoman#request#Curl().Send(
                \l:token, s:github_api . '/issues/' . a:repoman.number . '/comments')))
        endif

        let l:issue_result['comments'] = l:comments_result
        return l:issue_result
    endfunction

    " --------------------------------------------------------------
    " Comments -----------------------------------------------------
    " --------------------------------------------------------------

    function! request.PostComment(repoman) abort
        let l:footer = ''
        if !exists('g:repoman_footer') || g:repoman_footer
            let l:footer = printf(s:footer, 'Posted')
        endif

        let l:comment_data = '{"body": "' .
            \repoman#utils#SanitizeText(a:repoman.body) . l:footer .
            \'"}'

        call system(repoman#request#Curl().BackgroundSend(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues/' . a:repoman.number . '/comments',
            \l:comment_data, 'POST'))

        let l:temp_comment = {
            \'created_at': strftime('%G-%m-%d %H:%M:%S'),
            \'body': a:repoman.body,
            \'user': {'login': 'You'}
        \}
        call repoman#utils#AddLocalComment(
            \l:temp_comment, s:repoman.current_issue, s:repoman.token_pw)
    endfunction

    " --------------------------------------------------------------
    " Issues/PRs ---------------------------------------------------
    " --------------------------------------------------------------

    function! request.NewItem(repoman) abort
        let l:footer = ''
        if !exists('g:repoman_footer') || g:repoman_footer
            let l:footer = printf(s:footer, 'Created')
        endif

        let l:issue_data = '{
            \"title": "' . repoman#utils#SanitizeText(a:repoman.title) . '",
            \"body": "' . repoman#utils#SanitizeText(a:repoman.body) . l:footer . '"
        \}'

        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues',
            \l:issue_data, 'POST'))
    endfunction

    function! request.CloseItem(repoman) abort
        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues/' . a:repoman.number,
            \'{"state": "closed"}', 'PATCH'))
    endfunction

    " --------------------------------------------------------------
    " Labels -------------------------------------------------------
    " --------------------------------------------------------------

    function! request.ViewLabels(repoman) abort
        " Need to fetch all labels, then cross check against issue labels
        let l:current_labels = json_decode(system(
            \repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues/' . a:repoman.number . '/labels')))
        let l:all_labels = json_decode(system(
            \repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/labels')))

        for label in l:all_labels
            if index(l:current_labels, label) >= 0
                let label['active'] = 1
            endif
        endfor

        return l:all_labels
    endfunction

    function! request.UpdateLabels(repoman) abort
        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \s:github_api . '/issues/' . a:repoman.number . '/labels',
            \'{"labels": ' . repoman#utils#SanitizeText(json_encode(a:repoman.labels)) . '}', 'PUT'))
    endfunction

    " ============================================================================
    " Formatting
    " ============================================================================
    function! FormatReviewComment(comment) abort
        return {
            \'comment_id': a:comment['id'],
            \'reactions': a:comment['reactions'],
            \'login': a:comment['user']['login'],
            \'comment': a:comment['body'],
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
        endwhile

        return -1
    endfunction

    return request
endfunction

