" =========================================================================
" File:    autoload/hubbub.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A set of functions for handling user input, buffer
" modifications, and interaction with the host API.
" =========================================================================
scriptencoding utf-8

let g:hubbub_dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')
let g:hubbub_open = 0
let s:buffers = function('hubbub#buffers#Buffers')
let s:constants = function('hubbub#constants#Constants')()

let s:hubbub = {
    \'token_pw': '',
    \'current_issue': -1,
    \'pr': 0,
    \'page': 1,
    \'repo': hubbub#utils#GetRepoPath()
\}

let s:hubbub_max_page = -1

" Set language and response keys
let response_keys = json_decode(join(readfile(g:hubbub_dir . '/assets/response_keys.json')))
let s:r_keys = response_keys[hubbub#utils#GetRepoHost()]

let lang_dict = json_decode(join(readfile(g:hubbub_dir . '/assets/strings.json')))
let s:strings = lang_dict[(exists('g:hubbub_language') ? g:hubbub_language : 'en')]

let s:gh_token_path = g:hubbub_dir . '/.github.hubbub'
let s:gl_token_path = g:hubbub_dir . '/.gitlab.hubbub'
let s:api = {}

" =========================================================================
" Commands
" =========================================================================

" --------------------------------------------------------------
" Init ---------------------------------------------------------
" --------------------------------------------------------------
" :HubbubInit allows the user to set up using their tokens to
" access the GitHub and/or GitLab API
function! hubbub#HubbubInit() abort
    call inputsave()
    let l:token_gh = input('GitHub Token: ')

    " TODO: GitLab integration
    let l:token_gl = ''
    "let l:token_gl = input('GitLab Token (leave empty to skip): ')
    let l:token_pw = inputsecret('Enter a password to encrypt your token (optional): ')
    call inputrestore()

    if !empty(l:token_gh)
        call hubbub#crypto#Encrypt(l:token_gh, s:gh_token_path, l:token_pw)
    endif

    if !empty(l:token_gl)
        call hubbub#crypto#Encrypt(l:token_gl, s:gl_token_path, l:token_pw)
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
" :Hubbub can either:
"   - Open a new instance of Hubbub to the 'home' view. If
"     there's already a Hubbub buffer open, it will:
"   - Refresh the currently active Hubbub buffer(s)
function! hubbub#Hubbub() abort
    let l:repo_host = hubbub#utils#GetRepoHost()
    let s:in_repo = hubbub#utils#InGitRepo()

    if !filereadable(s:gh_token_path) && !filereadable(s:gl_token_path)
        " At least one token should exist
        echo 'No tokens found -- have you run :HubbubInit?'
        return
    elseif !s:in_repo && !exists('g:hubbub_default_host')
        if filereadable(s:gh_token_path) && !filereadable(s:gl_token_path)
            let g:hubbub_default_host = 'github'
        elseif filereadable(s:gl_token_path) && !filereadable(s:gh_token_path)
            let g:hubbub_default_host = 'gitlab'
        else
            " If user hasn't set their default host, and is using both tokens, so there's nothing to do
            echo 'Not in git repo -- run :Hubbub from within a repository, or set g:hubbub_default_host'
            return
        endif
    endif

    if !s:in_repo && g:hubbub_default_host
        let l:repo_host = g:hubbub_default_host
    endif

    let l:issue_open = 0

    " Skip password if the user has not set one
    let l:nopass = function('hubbub#utils#' . l:repo_host . '_NoPass')()

    if g:hubbub_open
        set cmdheight=4
        echo s:strings.refresh

        " User is already using Hubbub, treat as a refresh
        if bufexists(bufnr(s:constants.buffers.issue_list)) > 0
            execute 'bw! ' . fnameescape(s:constants.buffers.issue_list)
        endif

        if bufexists(bufnr(s:constants.buffers.issue)) > 0
            execute 'bw! ' . fnameescape(s:constants.buffers.issue)
            let l:issue_open = 1
        endif
    elseif !l:nopass
        " New session, prompt for token pw
        call inputsave()
        let s:hubbub.token_pw = inputsecret(s:strings.pw_prompt)
        call inputrestore()
    else
        " No password, continue without one
        let s:hubbub.token_pw = ''
    endif

    " Initialize script API object
    let s:api = function('hubbub#' . l:repo_host . '#API')(s:hubbub.token_pw)

    " Recreate home buffer, and optionally the issue buffer
    " as well
    let l:results = s:in_repo || !empty(s:hubbub.repo) ?
        \IssueListQuery() : RepoListQuery()
    if len(l:results) < 10
        let s:hubbub_max_page = 1
    endif

    if !s:in_repo && empty(s:hubbub.repo)
        call s:buffers(s:hubbub).CreateRepoListBuffer(l:results)
    else
        call s:buffers(s:hubbub).CreateIssueListBuffer(l:results)
        if s:hubbub.current_issue > 0 && l:issue_open
            call s:buffers(s:hubbub).CreateIssueBuffer(
                \IssueQuery(s:hubbub.current_issue, s:hubbub.pr))
        else
            let s:hubbub.current_issue = -1
        endif
    endif

    " Plugin is now initialized
    let g:hubbub_open = 1
endfunction

" :HubbubBack can be used to navigate back to the home page buffer
" in instances where the issue buffer was opened on top of it.
function! hubbub#HubbubBack() abort
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
    if bufwinnr(s:constants.buffers.issue) > 0 || s:hubbub.current_issue > 0
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
        let s:hubbub.repo = ''
        let s:hubbub.page = 1
        let s:hubbub_max_page = -1
        call hubbub#Hubbub()
    endif

    " Reset issue number
    let s:hubbub.current_issue = -1
    let s:hubbub.pr = 0
endfunction

" :HubbubPage is used to navigate to fetch the next page
" of results in the issues/requests list
function! hubbub#HubbubPage(...) abort
    if a:1 < 1 && s:hubbub.page == 1
        return
    elseif s:hubbub.page == s:hubbub_max_page && a:1 > 0
        echo 'Max page reached'
        return
    endif

    if bufexists(bufnr(s:constants.buffers.issue_list)) > 0
        execute 'bw! ' . fnameescape(s:constants.buffers.issue_list)
    endif

    let s:hubbub.page += a:1
    let l:page_issues = s:in_repo || !empty(s:hubbub.repo)
    let l:response = l:page_issues ? IssueListQuery() : RepoListQuery()

    if len(l:response) < 10
        let s:hubbub_max_page = s:hubbub.page
    endif
    let s:buf_create = l:page_issues ?
        \s:buffers(s:hubbub).CreateIssueListBuffer :
        \s:buffers(s:hubbub).CreateRepoListBuffer
    call s:buf_create(l:response)
endfunction

" :HubbubJump can be used on buffers to jump between
" items by direction (1 for forwards, -1 for backwards)
function! hubbub#HubbubJump(...) abort
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
function! hubbub#HubbubReact(reaction) abort
    if index(keys(s:constants.reactions), a:reaction) < 0
        echo 'Invalid arg: must be one of ' . string(keys(s:constants.reactions))
        return
    endif

    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call NewReaction('comment', a:reaction, b:comment_lookup[getcurpos()[1]]['id'])
    elseif bufwinnr(s:constants.buffers.issue) > 0 && s:hubbub.current_issue > 0
        call NewReaction('issue', a:reaction, s:hubbub.current_issue)
    endif
endfunction

function! hubbub#HubbubMerge(...) abort
    if !s:hubbub.pr
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

function! hubbub#HubbubReview(action) abort
    let l:actions = ['new', 'approve', 'request_changes', 'comment', 'pending']
    let l:body = ''

    if !s:hubbub.pr
        echo s:strings.error . 'Must have a PR open to review'
        return
    elseif index(l:actions, a:action) < 0
        echo s:strings.error .
            \'Invalid action -- must be one of ' . string(l:actions)
        return
    elseif bufexists(bufnr(s:constants.buffers.review)) && a:action ==# 'new'
        echo s:strings.error .
            \'Cannot create a new review while one is already open'
        return
    endif

    if a:action =~# 'new'
        call s:buffers(s:hubbub).CreateReviewBuffer(Review(a:action, l:body))
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
    call hubbub#Hubbub()
endfunction

function! hubbub#HubbubSuggest() range
    if !bufexists(bufnr(s:constants.buffers.review))
        echo s:strings.error .
            \'Cannot make a suggestion outside of a code review'
        return
    endif

    let l:code = []
    for line in getline(a:firstline, a:lastline)
        call add(l:code, substitute(line, '^[^ ]', '', ''))
    endfor

    call s:buffers(s:hubbub).CreateSuggestionBuffer(l:code, a:firstline, a:lastline)
endfunction

function! hubbub#HubbubSave() abort
    if @% !=# s:constants.buffers.review
        echo s:strings.error . 'Must be in a review to save'
        return
    endif

    " TODO
endfunction

" :HubbubReply functions similarly to HubbubComment, but
" posts a reply to an existing review comment instead of a
" regular issue comment.
"
" Used in conjunction with :HubbubPost to post the reply.
function! hubbub#HubbubReply() abort
    if !exists('b:comment_lookup')
        echo 'No review comments to reply to'
        return
    elseif !has_key(b:comment_lookup, getcurpos()[1])
        echo 'Cursor is not positioned over a review comment'
        return
    endif

    let l:parent_id = b:comment_lookup[getcurpos()[1]][s:r_keys.id]
    call s:buffers(s:hubbub).CreateReplyBuffer(l:parent_id, 0)
endfunction

" :HubbubComment splits the issue buffer in half horizontally,
" and allows the user to enter a comment of any length.
"
" Used in conjunction with :HubbubPost to post the comment.
function! hubbub#HubbubComment() range
    if s:hubbub.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to comment!'
        return
    elseif exists('b:review_lookup') && (
        \!has_key(b:review_lookup, getcurpos()[1]) || !b:review_lookup[getcurpos()[1]]['position'])
        echo s:strings.error . 'Invalid review line for a comment'
        return
    endif

    call s:buffers(s:hubbub).CreateCommentBuffer(a:firstline, a:lastline)
endfunction

" :HubbubEdit allows editing the contents of an issue or comment, depending
" on the current location of the cursor.
function! hubbub#HubbubEdit() abort
    " Edit comment if the cursor is over a comment
    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call s:buffers(s:hubbub).EditCommentBuffer(b:comment_lookup[getcurpos()[1]])
        return
    elseif exists('b:review_comment_lookup') &&
        \has_key(b:review_comment_lookup, getcurpos()[1])
        call s:buffers(s:hubbub).EditCommentBuffer(b:review_comments[
            \b:review_comment_lookup[getcurpos()[1]]])
        return
    elseif s:hubbub.current_issue > 0 && exists('b:details')
        call s:buffers(s:hubbub).EditItemBuffer(b:details)
        return
    endif

    echo 'No issue or comment available to edit'
endfunction

function! hubbub#HubbubLabel() abort
    if exists('b:issue_lookup') && has_key(b:issue_lookup, getcurpos()[1])
        let s:hubbub.current_issue = b:issue_lookup[getcurpos()[1]]['number']
        let s:hubbub.pr = b:issue_lookup[getcurpos()[1]]['pr']
    endif

    if s:hubbub.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to label'
        return
    endif

    set cmdheight=4
    echo s:strings.load

    call s:buffers(s:hubbub).CreateLabelsBuffer(LabelsQuery(s:hubbub.current_issue))
endfunction

" :HubbubPost posts the contents of the comment buffer to the
" comment section for whichever issue/PR/MR is currently open.
function! hubbub#HubbubPost() abort
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
    call hubbub#Hubbub()
    " TODO: Not sure if this feature should be supported
    " until there are reasonable error messages when it fails
    "call SoftReload()
endfunction

" :HubbubNew creates a new issue/PR/MR.
" - a:1: Either 'issue' or 'pr'/'mr'
function! hubbub#HubbubNew(type) abort
    let l:item_type = a:type
    let l:pr_branch = ''

    if l:item_type !~# 'issue'
        let l:pr_branch = s:api.RepoInfo().default_branch
    endif

    call s:buffers(s:hubbub).NewItemBuffer(l:item_type, l:pr_branch)
endfunction

" :HubbubClose closes the currently selected issue/PR/MR, depending
" on the current active buffer.
function! hubbub#HubbubClose() abort
    let l:number_to_close = s:hubbub.current_issue
    let l:pr = s:hubbub.pr
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
            let s:hubbub.current_issue = -1
        endif
        call hubbub#Hubbub()
    endif
endfunction

function! hubbub#HubbubDelete() abort
    if exists('b:comment_lookup') && has_key(b:comment_lookup, getcurpos()[1])
        call DeleteComment(b:comment_lookup[getcurpos()[1]])
    elseif exists('b:review_comment_lookup') && has_key(b:review_comment_lookup, getcurpos()[1])
        let l:comment_id = b:review_comment_lookup[getcurpos()[1]]
        call s:buffers(s:hubbub).RemoveReviewBufferComment(b:review_comments[l:comment_id])
    end
endfunction

" =========================================================================
" External Script Calls
" =========================================================================
function! RepoListQuery() abort
    return s:api.ViewRepos(s:hubbub)
endfunction

function! IssueListQuery(...) abort
    if a:0 > 0
        let s:hubbub.page = 1
        let s:hubbub_max_page = -1
        let s:hubbub.repo = a:1
        let s:api.api_path = s:api.api_path . a:1
    endif

    let l:response = s:api.ViewAll(s:hubbub)
    call hubbub#crypto#Encrypt(
        \hubbub#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.home, s:hubbub.token_pw)
    return l:response
endfunction

function! IssueQuery(number, pr) abort
    let s:hubbub.number = a:number
    let s:hubbub.pr = a:pr
    let l:response = s:api.View(s:hubbub)
    call hubbub#crypto#Encrypt(
        \hubbub#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.issue, s:hubbub.token_pw)
    return l:response
endfunction

function! EditIssue(details) abort
    let s:hubbub.title = a:details[s:r_keys.title]
    let s:hubbub.body = a:details[s:r_keys.body]
    call s:api.UpdateIssue(a:details)
endfunction

function! LabelsQuery(number) abort
    let s:hubbub.number = a:number
    let l:response = s:api.ViewLabels(s:hubbub)
    call hubbub#crypto#Encrypt(
        \hubbub#utils#SanitizeText(json_encode(l:response)),
        \s:constants.local_files.labels, s:hubbub.token_pw)
    return l:response
endfunction

function! NewComment(comment, parent_id) abort
    let s:hubbub.body = a:comment
    let s:hubbub.parent_id = a:parent_id
    let s:hubbub.number = s:hubbub.current_issue
    let s:hubbub.pr = s:hubbub.pr
    call s:api.PostComment(s:hubbub)
endfunction

function! DeleteComment(comment) abort
    let s:hubbub.comment_id = a:comment.id
    let s:hubbub.type = a:comment.type
    call s:api.DeleteComment(s:hubbub)
    call hubbub#Hubbub()
endfunction

function! EditComment(comment) abort
    let s:hubbub.comment_id = a:comment.id
    let s:hubbub.body = a:comment.body
    let s:hubbub.type = a:comment.type
    call s:api.EditComment(s:hubbub)
endfunction

function! NewReaction(item_type, reaction, id) abort
    let s:hubbub.id = a:id
    let s:hubbub.type = a:item_type
    let s:hubbub.reaction = a:reaction
    call s:api.PostReaction(s:hubbub)
    call hubbub#Hubbub()
endfunction

function! Merge(method) abort
    let s:hubbub.method = a:method
    let s:hubbub.number = s:hubbub.current_issue
    call s:api.Merge(s:hubbub)
    call hubbub#Hubbub()
endfunction

function! Review(action, body) abort
    let s:hubbub.number = s:hubbub.current_issue
    let s:hubbub.action = a:action
    let s:hubbub.body = a:body
    return s:api.Review(s:hubbub)
endfunction

function! UpdateLabels(number, labels) abort
    let s:hubbub.number = a:number
    let s:hubbub.labels = a:labels
    let l:response = s:api.UpdateLabels(s:hubbub)
    "call hubbub#utils#UpdateLocalLabels(s:hubbub)
    return l:response
endfunction

function! NewItem(pr, data) abort
    call extend(s:hubbub, a:data)
    let s:hubbub.pr = a:pr
    call s:api.NewItem(s:hubbub)
endfunction

function! CloseItem(number, pr) abort
    let s:hubbub.number = a:number
    let s:hubbub.pr = a:pr
    call s:api.CloseItem(s:hubbub)
endfunction

" =========================================================================
" Interactions
" =========================================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, pr) abort
    let s:hubbub.pr = a:pr
    set cmdheight=4
    echo s:strings.load

    let l:result = IssueQuery(a:issue_number, a:pr)
    call s:buffers(s:hubbub).CreateIssueBuffer(l:result)
    let b:details = l:result
endfunction

" Resets the Hubbub script dictionary
function! ResetState() abort
    let s:hubbub = {
        \'token_pw': s:hubbub.token_pw,
        \'current_issue': s:hubbub.current_issue,
        \'pr': s:hubbub.pr,
        \'page': s:hubbub.page,
        \'repo': s:hubbub.repo
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
        \hubbub#crypto#Decrypt(
        \s:constants.local_files.home, s:hubbub.token_pw)))
    if s:hubbub.current_issue != -1
        call CreateIssueBuffer(json_decode(
            \hubbub#crypto#Decrypt(
            \s:constants.local_files.issue, s:hubbub.token_pw)))
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
        call s:buffers(s:hubbub).RemoveReviewBufferComment(l:edit_values)
    else
        execute 'bw! ' . fnameescape(s:constants.buffers.comment)
    endif

    " Add review comment to the review buffer
    call s:buffers(s:hubbub).AddReviewBufferComment(l:comment, l:data)
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

    call UpdateLabels(s:hubbub.current_issue, l:active_labels)
    execute 'bw! ' . fnameescape(s:constants.buffers.labels)
endfunction

nnoremap <script> <silent> <BS> :HubbubBack<CR>

