" =========================================================================
" File:    autoload/repoman.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: A set of functions for handling user input, buffer
" modifications, and interaction with the host API.
" =========================================================================
scriptencoding utf-8

let g:repoman_dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')
let s:buffers = function('repoman#buffers#Buffers')
let s:constants = function('repoman#constants#Constants')()

let s:repoman = {
    \'token_pw': '',
    \'current_issue': -1,
    \'pr': 0,
    \'page': 1,
    \'repo': repoman#utils#GetRepoPath()
\}

let s:repoman_max_page = -1

" Set language and response keys
let response_keys = json_decode(join(readfile(g:repoman_dir . '/assets/response_keys.json')))
let s:r_keys = response_keys[repoman#utils#GetRepoHost()]

let lang_dict = json_decode(join(readfile(g:repoman_dir . '/assets/strings.json')))
let s:strings = lang_dict[(exists('g:repoman_language') ? g:repoman_language : 'en')]

let s:gh_token_path = g:repoman_dir . '/.github.repoman'
let s:gl_token_path = g:repoman_dir . '/.gitlab.repoman'
let s:api = {}

" =========================================================================
" Commands
" =========================================================================

" --------------------------------------------------------------
" Init ---------------------------------------------------------
" --------------------------------------------------------------
" :RepoManInit allows the user to set up using their tokens to
" access the GitHub and/or GitLab API
function! repoman#RepoManInit() abort
    call inputsave()
    let l:token_gh = input('GitHub Token (leave empty to skip): ')

    " TODO: GitLab integration
    let l:token_gl = ''
    "let l:token_gl = input('GitLab Token (leave empty to skip): ')
    let l:token_pw = inputsecret('Enter a password to encrypt your token(s): ')
    call inputrestore()

    if empty(l:token_pw)
        echo 'Error: Password must be > 0 characters long'
        return
    endif

    if !empty(l:token_gh)
        call repoman#crypto#Encrypt(l:token_gh, s:gh_token_path, l:token_pw)
    endif

    if !empty(l:token_gl)
        call repoman#crypto#Encrypt(l:token_gl, s:gl_token_path, l:token_pw)
    endif

    if !filereadable(s:gh_token_path) && !filereadable(s:gl_token_path)
        echo s:strings.error . ' Unable to encrypt token ' .
            \'-- do you have OpenSSL or LibreSSL installed?'
    endif

    echo ''
endfunction

" --------------------------------------------------------------
" Navigation ---------------------------------------------------
" --------------------------------------------------------------
" :RepoMan can either:
"   - Open a new instance of RepoMan to the 'home' view. If
"     there's already a RepoMan buffer open, it will:
"   - Refresh the currently active RepoMan buffer(s)
function! repoman#RepoMan() abort
    let l:repo_host = repoman#utils#GetRepoHost()
    let s:in_repo = repoman#utils#InGitRepo()

    if !filereadable(s:gh_token_path) && !filereadable(s:gl_token_path)
        " At least one token should exist
        echo 'No tokens found -- have you run :RepoManInit?'
        return
    elseif !s:in_repo && !exists('g:repoman_default_host')
        if filereadable(s:gh_token_path) && !filereadable(s:gl_token_path)
            let g:repoman_default_host = 'github'
        elseif filereadable(s:gl_token_path) && !filereadable(s:gh_token_path)
            let g:repoman_default_host = 'gitlab'
        else
            " If user hasn't set their default host, and is using both tokens, so there's nothing to do
            echo 'Not in git repo -- run :RepoMan from within a repository, or set g:repoman_default_host'
            return
        endif
    endif

    let l:issue_open = 0
    if len(s:repoman.token_pw) > 0
        set cmdheight=4
        echo s:strings.refresh

        " User is already using RepoMan, treat as a refresh
        if bufexists(bufnr(s:constants.buffers.issue_list)) > 0
            execute 'bw! ' . fnameescape(s:constants.buffers.issue_list)
        endif

        if bufexists(bufnr(s:constants.buffers.issue)) > 0
            execute 'bw! ' . fnameescape(s:constants.buffers.issue)
            let l:issue_open = 1
        endif
    else
        " New session, prompt for token pw
        call inputsave()
        let s:repoman.token_pw = inputsecret(s:strings.pw_prompt)
        call inputrestore()

        if len(s:repoman.token_pw) == 0
            return
        endif
    endif

    if !s:in_repo && g:repoman_default_host
        let l:repo_host = g:repoman_default_host
    endif

    " Initialize script API object
    let s:api = function('repoman#' . l:repo_host . '#API')(s:repoman.token_pw)

    " Recreate home buffer, and optionally the issue buffer
    " as well
    let l:results = s:in_repo || !empty(s:repoman.repo) ?
        \IssueListQuery() : RepoListQuery()
    if len(l:results) < 10
        let s:repoman_max_page = 1
    endif

    if !s:in_repo && empty(s:repoman.repo)
        call s:buffers(s:repoman).CreateRepoListBuffer(l:results)
    else
        call s:buffers(s:repoman).CreateIssueListBuffer(l:results)
        if s:repoman.current_issue > 0 && l:issue_open
            call s:buffers(s:repoman).CreateIssueBuffer(
                \IssueQuery(s:repoman.current_issue, s:repoman.pr))
        else
            let s:repoman.current_issue = -1
        endif
    endif
endfunction

" :RepoManBack can be used to navigate back to the home page buffer
" in instances where the issue buffer was opened on top of it.
function! repoman#RepoManBack() abort
    let l:post_bufs = [
        \s:constants.buffers.comment,
        \s:constants.buffers.new_issue,
        \s:constants.buffers.new_req,
        \s:constants.buffers.labels,
        \s:constants.buffers.review
    \]

    " Reopen listview buffer, and close the issue buffer
    if bufwinnr(s:constants.buffers.issue_list) < 0
        execute 'b ' . fnameescape(s:constants.buffers.issue_list)
    endif

    " Navigate back to issue list buffer if the buffer is open, or if currently
    " viewing an issue
    if bufwinnr(s:constants.buffers.issue) > 0 || s:repoman.current_issue > 0
        for buffer in l:post_bufs
            if bufexists(bufnr(buffer))
                echo s:strings.error . ' Cannot close issue while updating'
                execute 'b ' . fnameescape(buffer)
                return
            endif
        endfor
        execute 'bw! ' . fnameescape(s:constants.buffers.issue)
    elseif bufwinnr(s:constants.buffers.issue_list) > 0 && !s:in_repo
        " Reset view to repo list
        set modifiable
        let s:repoman.repo = ''
        let s:repoman.page = 1
        let s:repoman_max_page = -1
        call repoman#RepoMan()
    endif

    " Reset issue number
    let s:repoman.current_issue = -1
    let s:repoman.pr = 0
endfunction

" :RepoManPage is used to navigate to fetch the next page
" of results in the issues/requests list
function! repoman#RepoManPage(...) abort
    if a:1 < 1 && s:repoman.page == 1
        return
    elseif s:repoman.page == s:repoman_max_page && a:1 > 0
        echo 'Max page reached'
        return
    endif

    if bufexists(bufnr(s:constants.buffers.issue_list)) > 0
        execute 'bw! ' . fnameescape(s:constants.buffers.issue_list)
    endif

    let s:repoman.page += a:1
    let l:page_issues = s:in_repo || !empty(s:repoman.repo)
    let l:response = l:page_issues ? IssueListQuery() : RepoListQuery()

    if len(l:response) < 10
        let s:repoman_max_page = s:repoman.page
    endif
    let s:buf_create = l:page_issues ?
        \s:buffers(s:repoman).CreateIssueListBuffer :
        \s:buffers(s:repoman).CreateRepoListBuffer
    call s:buf_create(l:response)
endfunction

" :RepoManJump can be used on buffers to jump between
" items by direction (1 for forwards, -1 for backwards)
function! repoman#RepoManJump(...) abort
    let l:current_line = getcurpos()[1]
    let l:direction = a:1
    let l:idx = 0

    while l:idx < len(b:jump_guide)
        let l:jump_idx = b:jump_guide[l:idx]
        if l:direction > 0 && l:jump_idx > l:current_line
            let l:current_line = l:jump_idx
            break
        elseif l:direction < 0 && l:jump_idx >= l:current_line
            let l:current_line = b:jump_guide[l:idx - 1]
            break
        endif

        let l:idx += 1
    endwhile

    if l:current_line == getcurpos()[1]
        " Line hasn't changed, cycle to beginning/end
        let l:current_line = b:jump_guide[l:direction ? 0 : -1]
    endif

    call cursor(l:current_line, 0)
endfunction

" --------------------------------------------------------------
" Interaction --------------------------------------------------
" --------------------------------------------------------------
function! repoman#RepoManReact(reaction) abort
    if index(keys(s:constants.reactions), a:reaction) < 0
        echo 'Invalid arg: must be one of ' . string(keys(s:constants.reactions))
        return
    endif

    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call NewReaction('comment', a:reaction, b:comment_lookup[getcurpos()[1]]['id'])
    elseif bufwinnr(s:constants.buffers.issue) > 0 && s:repoman.current_issue > 0
        call NewReaction('issue', a:reaction, s:repoman.current_issue)
    endif
endfunction

function! repoman#RepoManMerge(...) abort
    if !s:repoman.pr
        echo s:strings.error . 'Must have a PR open to merge'
        return
    endif

    let l:merge_method = s:constants.merge_methods[0]
    if a:0 > 0 && index(s:constants.merge_methods, a:1) >= 0
        let l:merge_method = a:1
    else
        echo s:strings.error . 'Invalid merge method "' . a:1 . '"'
        return
    endif

    call Merge(l:merge_method)
endfunction

function! repoman#RepoManReview(action) abort
    let l:actions = ['new', 'approve', 'request_changes', 'comment', 'pending']
    let l:body = ''

    if !s:repoman.pr
        echo s:strings.error . 'Must have a PR open to review'
        return
    elseif index(l:actions, a:action) < 0
        echo s:strings.error .
            \'Invalid action -- must be one of ' . string(l:actions)
    elseif bufexists(bufnr(s:constants.buffers.review)) && a:action ==# 'new'
        echo s:strings.error .
            \'Cannot create a new review while one is already open'
        return
    endif

    if a:action =~# 'new'
        call s:buffers(s:repoman).CreateReviewBuffer(Review(a:action, l:body))
        return
    elseif a:action =~# 'request_changes' || a:action =~# 'comment'
        let l:body = input('Comment (required -- use \n for line breaks): ')
        if empty(l:body)
            echo s:strings.error . ' Invalid comment for "' . a:action . '" review submission'
            return
        endif
    endif

    call Review(toupper(a:action), l:body)
    execute 'bw! ' . s:constants.buffers.review
    call repoman#RepoMan()
endfunction

function! repoman#RepoManSuggest() range
    if !bufexists(bufnr(s:constants.buffers.review))
        echo s:strings.error .
            \'Cannot make a suggestion outside of a code review'
        return
    endif

    let l:code = []
    for line in getline(a:firstline, a:lastline)
        call add(l:code, substitute(line, '^[^ ]', '', ''))
    endfor

    call s:buffers(s:repoman).CreateSuggestionBuffer(l:code, a:firstline, a:lastline)
endfunction

function! repoman#RepoManSave() abort
    if @% !=# s:constants.buffers.review
        echo s:strings.error . 'Must be in a review to save'
        return
    endif
endfunction

" :RepoManReply functions similarly to RepoManComment, but
" posts a reply to an existing review comment instead of a
" regular issue comment.
"
" Used in conjunction with :RepoManPost to post the reply.
function! repoman#RepoManReply() abort
    if !exists('b:comment_lookup')
        echo 'No review comments to reply to'
        return
    elseif !has_key(b:comment_lookup, getcurpos()[1])
        echo 'Cursor is not positioned over a review comment'
        return
    endif

    let l:parent_id = b:comment_lookup[getcurpos()[1]][s:r_keys.id]
    call s:buffers(s:repoman).CreateReplyBuffer(l:parent_id, 0)
endfunction

" :RepoManComment splits the issue buffer in half horizontally,
" and allows the user to enter a comment of any length.
"
" Used in conjunction with :RepoManPost to post the comment.
function! repoman#RepoManComment() range
    if s:repoman.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to comment!'
        return
    elseif exists('b:review_lookup') && (
        \!has_key(b:review_lookup, getcurpos()[1]) || !b:review_lookup[getcurpos()[1]]['position'])
        echo s:strings.error . 'Invalid review line for a comment'
        return
    endif

    call s:buffers(s:repoman).CreateCommentBuffer(a:firstline, a:lastline)
endfunction

" :RepoManEdit allows editing the contents of an issue or comment, depending
" on the current location of the cursor.
function! repoman#RepoManEdit() abort
    " Edit comment if the cursor is over a comment
    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call s:buffers(s:repoman).EditCommentBuffer(b:comment_lookup[getcurpos()[1]])
        return
    elseif exists('b:review_comment_lookup') &&
        \has_key(b:review_comment_lookup, getcurpos()[1])
        call s:buffers(s:repoman).EditCommentBuffer(b:review_comments[
            \b:review_comment_lookup[getcurpos()[1]]])
        return
    elseif s:repoman.current_issue > 0 && exists('b:details')
        call s:buffers(s:repoman).EditItemBuffer(b:details)
        return
    endif

    echo 'No issue or comment available to edit'
endfunction

function! repoman#RepoManLabel() abort
    if exists('b:issue_lookup') && has_key(b:issue_lookup, getcurpos()[1])
        let s:repoman.current_issue = b:issue_lookup[getcurpos()[1]]['number']
        let s:repoman.pr = b:issue_lookup[getcurpos()[1]]['pr']
    endif

    if s:repoman.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to label'
        return
    endif

    set cmdheight=4
    echo s:strings.load

    call s:buffers(s:repoman).CreateLabelsBuffer(LabelsQuery(s:repoman.current_issue))
endfunction

" :RepoManPost posts the contents of the comment buffer to the
" comment section for whichever issue/PR/MR is currently open.
function! repoman#RepoManPost() abort
    if exists('b:review_data') && bufexists(bufnr(s:constants.buffers.review))
        call PostReviewData()
        return
    elseif bufexists(bufnr(s:constants.buffers.edit)) && exists('b:edit_values')
        call PostEdit()
    elseif bufexists(bufnr(s:constants.buffers.new_issue)) > 0
            \|| bufexists(bufnr(s:constants.buffers.new_req))
        call PostNewIssue()
    elseif bufexists(bufnr(s:constants.buffers.comment)) > 0
        call PostNewComment()
    elseif bufexists(bufnr(s:constants.buffers.labels)) > 0
        call PostNewLabels()
    else
        echom s:strings.error . 'No buffers open to post'
        return
    endif

    set modifiable
    call repoman#RepoMan()
endfunction

" :RepoManNew creates a new issue/PR/MR.
" - a:1: Either 'issue' or 'pr'/'mr'
function! repoman#RepoManNew(type) abort
    let l:item_type = a:type
    let l:pr_branch = ''

    if l:item_type !~# 'issue'
        let l:pr_branch = s:api.RepoInfo().default_branch
    endif

    call s:buffers(s:repoman).NewItemBuffer(l:item_type, l:pr_branch)
endfunction

" :RepoManClose closes the currently selected issue/PR/MR, depending
" on the current active buffer.
function! repoman#RepoManClose() abort
    let l:number_to_close = s:repoman.current_issue
    let l:pr = s:repoman.pr
    let l:reset_current = 1

    " Check to see if the user is not in an issue buffer, and
    " if not, close the issue under their cursor
    if expand('%:p') =~ s:constants.buffers.issue_list
        let l:number_to_close = b:issue_lookup[getcurpos()[1]]['number']
        let l:pr = b:issue_lookup[getcurpos()[1]]['pr']
        let l:reset_current = 0
    endif

    call inputsave()
    let s:answer = input(s:strings.close . '#' . l:number_to_close . '? (y/n) ')
    call inputrestore()

    if s:answer ==? 'y'
        call CloseItem(l:number_to_close, l:pr)
        if l:reset_current
            let s:repoman.current_issue = -1
        endif
        call repoman#RepoMan()
    endif
endfunction

function! repoman#RepoManDelete() abort
    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call DeleteComment(b:comment_lookup[getcurpos()[1]])
    elseif exists('b:review_comment_lookup') && has_key(b:review_comment_lookup, getcurpos()[1])
        let l:comment_id = b:review_comment_lookup[getcurpos()[1]]
        call s:buffers(s:repoman).RemoveReviewBufferComment(b:review_comments[l:comment_id])
    end
endfunction

" =========================================================================
" External Script Calls
" =========================================================================
function! RepoListQuery() abort
    return s:api.ViewRepos(s:repoman)
endfunction

function! IssueListQuery(...) abort
    if a:0 > 0
        let s:repoman.page = 1
        let s:repoman_max_page = -1
        let s:repoman.repo = a:1
        let s:api.api_path = s:api.api_path . a:1
    endif

    let l:response = s:api.ViewAll(s:repoman)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.home, s:repoman.token_pw)
    return l:response
endfunction

function! IssueQuery(number, pr) abort
    let s:repoman.number = a:number
    let s:repoman.pr = a:pr
    let l:response = s:api.View(s:repoman)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.issue, s:repoman.token_pw)
    return l:response
endfunction

function! EditIssue(details) abort
    let s:repoman.title = a:details[s:r_keys.title]
    let s:repoman.body = a:details[s:r_keys.body]
    call s:api.UpdateIssue(a:details)
endfunction

function! LabelsQuery(number) abort
    let s:repoman.number = a:number
    let l:response = s:api.ViewLabels(s:repoman)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.labels, s:repoman.token_pw)
    return l:response
endfunction

function! NewComment(comment, parent_id) abort
    let s:repoman.body = a:comment
    let s:repoman.parent_id = a:parent_id
    let s:repoman.number = s:repoman.current_issue
    let s:repoman.pr = s:repoman.pr
    call s:api.PostComment(s:repoman)
endfunction

function! DeleteComment(comment) abort
    let s:repoman.comment_id = a:comment.id
    let s:repoman.type = a:comment.type
    call s:api.DeleteComment(s:repoman)
    call repoman#RepoMan()
endfunction

function! EditComment(comment) abort
    let s:repoman.comment_id = a:comment.id
    let s:repoman.body = a:comment.body
    let s:repoman.type = a:comment.type
    call s:api.EditComment(s:repoman)
endfunction

function! NewReaction(item_type, reaction, id) abort
    let s:repoman.id = a:id
    let s:repoman.type = a:item_type
    let s:repoman.reaction = a:reaction
    call s:api.PostReaction(s:repoman)
    call repoman#RepoMan()
endfunction

function! Merge(method) abort
    let s:repoman.method = a:method
    let s:repoman.number = s:repoman.current_issue
    call s:api.Merge(s:repoman)
    call repoman#RepoMan()
endfunction

function! Review(action, body) abort
    let s:repoman.number = s:repoman.current_issue
    let s:repoman.action = a:action
    let s:repoman.body = a:body
    return s:api.Review(s:repoman)
endfunction

function! UpdateLabels(number, labels) abort
    let s:repoman.number = a:number
    let s:repoman.labels = a:labels
    let l:response = s:api.UpdateLabels(s:repoman)
    "call repoman#utils#UpdateLocalLabels(s:repoman)
    return l:response
endfunction

function! NewItem(pr, data) abort
    call extend(s:repoman, a:data)
    let s:repoman.pr = a:pr
    call s:api.NewItem(s:repoman)
endfunction

function! CloseItem(number, pr) abort
    let s:repoman.number = a:number
    let s:repoman.pr = a:pr
    call s:api.CloseItem(s:repoman)
endfunction

" =========================================================================
" Interactions
" =========================================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, pr) abort
    let s:repoman.pr = a:pr
    set cmdheight=4
    echo s:strings.load

    let l:result = IssueQuery(a:issue_number, a:pr)
    call s:buffers(s:repoman).CreateIssueBuffer(l:result)
    let b:details = l:result
endfunction

" Resets the RepoMan script dictionary
function! ResetState() abort
    let s:repoman = {
        \'token_pw': s:repoman.token_pw,
        \'current_issue': s:repoman.current_issue,
        \'pr': s:repoman.pr,
        \'page': s:repoman.page,
        \'repo': s:repoman.repo
    \}
endfunction

" Reloads the current view using locally updated content
function! SoftReload() abort
    " Remove existing buffers
    if bufexists(bufnr(s:constants.buffers.issue_list)) > 0
        execute 'bw! ' . fnameescape(s:constants.buffers.issue_list)
    endif

    if bufexists(bufnr(s:constants.buffers.issue)) > 0
        execute 'bw! ' . fnameescape(s:constants.buffers.issue)
    endif

    " Recreate home and issue buffer w/ locally updated files
    call CreateIssueListBuffer(json_decode(
        \repoman#crypto#Decrypt(
        \s:constants.local_files.home, s:repoman.token_pw)))
    if s:repoman.current_issue != -1
        call CreateIssueBuffer(json_decode(
            \repoman#crypto#Decrypt(
            \s:constants.local_files.issue, s:repoman.token_pw)))
    endif
endfunction

" =========================================================================
" Post handlers
" =========================================================================
function! PostReviewData() abort
    let l:comment = getline(1, '$')
    let l:data = b:review_data

    if bufexists(bufnr(s:constants.buffers.edit)) && exists('b:edit_values')
        let l:edit_values = b:edit_values
        execute 'bw! ' . fnameescape(s:constants.buffers.edit)

        " Edit existing review comment in the buffer
        call s:buffers(s:repoman).RemoveReviewBufferComment(l:edit_values)
    else
        execute 'bw! ' . fnameescape(s:constants.buffers.comment)
    endif

    " Add review comment to the review buffer
    call s:buffers(s:repoman).AddReviewBufferComment(l:comment, l:data)
endfunction

function! PostEdit() abort
    if b:edit_values.edit ==# 'comment'
        let b:edit_values.body = join(getline(1, '$'), '\n')
        call EditComment(b:edit_values)
    elseif b:edit_values.edit ==# 'issue'
        let b:edit_values.title = getline(1)
        let b:edit_values.body = join(getline(3, '$'), '\n')
        call EditIssue(b:edit_values)
    endif
    execute 'bw! ' . fnameescape(s:constants.buffers.edit)
endfunction

function! PostNewIssue() abort
    " Determine which buffer to use for the post
    let l:post_buf = s:constants.buffers.new_issue
    let l:pr = 0
    let l:line_offset = 0
    let l:post_data = {}
    if bufexists(bufnr(s:constants.buffers.new_req))
        let l:post_buf = s:constants.buffers.new_req
        let l:pr = 1
        let l:line_offset = 3
        let l:post_data.head = substitute(getline(1), s:strings.head . ': ', '', 'ge')
        let l:post_data.base = substitute(getline(2), s:strings.base . ': ', '', 'ge')
    endif

    " Focus on active buffer for issue/request creation
    execute 'b ' . fnameescape(l:post_buf)

    " Extract title and body segments
    let l:post_data.title = getline(1 + l:line_offset)
    let l:post_data.body = join(getline(3 + l:line_offset, '$'), '\n')
    call NewItem(l:pr, l:post_data)
    execute 'bw! ' . fnameescape(l:post_buf)
endfunction

function! PostNewComment() abort
    execute 'b ' . fnameescape(s:constants.buffers.comment)

    " Condense buffer into a single line with line break chars
    let l:comment_text = join(getline(1, '$'), '\n')

    call NewComment(l:comment_text, exists('b:parent_id') ? b:parent_id : -1)
    execute 'bw! ' . fnameescape(s:constants.buffers.comment)
endfunction

function! PostNewLabels() abort
    execute 'b ' . fnameescape(s:constants.buffers.labels)

    " Determine which labels are active
    let active_labels = []
    for label in getline(1, '$')
        if stridx(label, '[x]') == 0
            let label_name = substitute(label, '\[x\] ', '', '')
            call add(active_labels, label_name)
        endif
    endfor

    call UpdateLabels(s:repoman.current_issue, l:active_labels)
    execute 'bw! ' . fnameescape(s:constants.buffers.labels)
endfunction

nnoremap <script> <silent> <BS> :RepoManBack<CR>

