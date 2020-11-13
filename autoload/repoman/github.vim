" ============================================================================
" File:    autoload/repoman/github.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" ============================================================================
let s:footer = '\n\n___\n<sub>_%s with [vim-repoman](https://github.com/benbusby/vim-repoman)!_</sub>'

" ============================================================================
" GitHub API
" ============================================================================
let s:github_reactions_type = 'application/vnd.github.squirrel-girl-preview'
let s:github_multiline_type = 'application/vnd.github.comfort-fade-preview+json'

function! repoman#github#API(token_pw) abort
    let l:github_api = 'https://api.github.com/repos/' . repoman#utils#GetRepoPath()
    let request = {
        \'token_pw': a:token_pw,
        \'api_path': l:github_api
    \}

    " --------------------------------------------------------------
    " Views --------------------------------------------------------
    " --------------------------------------------------------------
    function! request.ViewRepos(repoman) abort
        return json_decode(system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \'https://api.github.com/user/repos?sort=updated&type=owner&per_page=10&page=' . a:repoman.page)))
    endfunction

    function! request.ViewAll(repoman) abort
        return reverse(json_decode(system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues?state=open&per_page=10&page=' . a:repoman.page,
            \{}, ''))))
    endfunction

    function! request.View(repoman) abort
        let l:path_type = (a:repoman.pr ? 'pulls' : 'issues')
        let l:accept_type = (a:repoman.pr ? s:github_multiline_type : s:github_reactions_type)
        let l:token = repoman#utils#ReadToken(self.token_pw)

        let l:issue_result = json_decode(system(
            \repoman#request#Curl(l:accept_type).Send(
            \l:token, self.api_path . '/' . l:path_type . '/' . a:repoman.number,
            \{}, '')))

        let l:comments_result = json_decode(system(
            \repoman#request#Curl(l:accept_type).Send(
            \l:token, self.api_path . '/' . l:path_type . '/' . a:repoman.number . '/comments')))

        " If this is a pull request, we have to format the comments so that
        " comments on the same code changes appear grouped together
        if a:repoman.pr
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

            let l:comments_result = l:comments_result + json_decode(system(repoman#request#Curl(s:github_reactions_type).Send(
                \l:token, self.api_path . '/issues/' . a:repoman.number . '/comments')))
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

        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:repoman.number . '/comments',
            \l:comment_data, 'POST'))

        "let l:temp_comment = {
            "\'created_at': strftime('%G-%m-%d %H:%M:%S'),
            "\'body': a:repoman.body,
            "\'user': {'login': 'You'}
        "\}
        "call repoman#utils#AddLocalComment(
            "\l:temp_comment, a:repoman.current_issue, a:repoman.token_pw)
    endfunction

    function! request.DeleteComment(repoman) abort
        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . a:repoman.type . '/comments/' . a:repoman.comment_id,
            \{}, 'DELETE'))
    endfunction

    function! request.EditComment(repoman) abort
        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/' . a:repoman.type . '/comments/' . a:repoman.comment_id,
            \'{"body": "' . repoman#utils#SanitizeText(a:repoman.body) . '"}', 'PATCH'))
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
            \self.api_path . '/issues',
            \l:issue_data, 'POST'))
    endfunction

    function! request.CloseItem(repoman) abort
        call system(repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/issues/' . a:repoman.number,
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
            \self.api_path . '/issues/' . a:repoman.number . '/labels')))
        let l:all_labels = json_decode(system(
            \repoman#request#Curl().Send(
            \repoman#utils#ReadToken(self.token_pw),
            \self.api_path . '/labels')))

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
            \self.api_path . '/issues/' . a:repoman.number . '/labels',
            \'{"labels": ' . repoman#utils#SanitizeText(json_encode(a:repoman.labels)) . '}', 'PUT'))
    endfunction

    " ============================================================================
    " Reactions
    " ============================================================================
    function! request.PostReaction(repoman) abort
        if a:repoman.type ==# 'comment'
            call system(repoman#request#Curl(s:github_reactions_type).Send(
                \repoman#utils#ReadToken(self.token_pw),
                \self.api_path . '/issues/comments/' . a:repoman.id . '/reactions',
                \'{"content": "' . a:repoman.reaction . '"}', 'POST'))
        else
            echom 'Reaction error: Unknown type'
        endif
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
            let l:index += 1
        endwhile

        return -1
    endfunction

    return request
endfunction

