" ============================================================================
" File:    autoload/repoman.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" ============================================================================
scriptencoding utf-8

let g:repoman_dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

let s:decorations = repoman#utils#Decorations()

let s:repoman_bufs = {
    \'issue':      '/dev/null/issue.repoman.diff',
    \'issue_list': '/dev/null/issue_list.repoman',
    \'comment':    '/dev/null/comment.repoman',
    \'new_issue':  '/dev/null/new_issue.repoman',
    \'new_req':    '/dev/null/new_req.repoman',
    \'labels':     '/dev/null/labels.repoman'
\}

let s:repoman = {
    \'token_pw': '',
    \'current_issue': -1,
    \'in_pr': 0,
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

" ============================================================================
" Commands
" ============================================================================

" --------------------------------------------------------------
" Init ---------------------------------------------------------
" --------------------------------------------------------------
" :RepoManInit allows the user to set up using their tokens to
" access the GitHub and/or GitLab API
function! repoman#RepoManInit() abort
    call inputsave()
    let l:token_gh = input('GitHub Token (leave empty to skip): ')
    let l:token_gl = input('GitLab Token (leave empty to skip): ')
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

    if len(s:repoman.token_pw) > 0
        set cmdheight=4
        echo s:strings.refresh

        " User is already using RepoMan, treat as a refresh
        if bufexists(bufnr(s:repoman_bufs.issue_list)) > 0
            execute 'bw! ' . fnameescape(s:repoman_bufs.issue_list)
        endif

        if bufexists(bufnr(s:repoman_bufs.issue)) > 0
            execute 'bw! ' . fnameescape(s:repoman_bufs.issue)
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
    let l:results = s:in_repo ? IssueListQuery() : RepoListQuery()
    if len(l:results) < 10
        let s:repoman_max_page = 1
    endif

    if !s:in_repo
        call CreateRepoListBuffer(l:results)
    else
        call CreateIssueListBuffer(l:results)
        if s:repoman.current_issue != -1
            call CreateIssueBuffer(IssueQuery(s:repoman.current_issue, s:repoman.in_pr))
        endif
    endif
endfunction

" :RepoManBack can be used to navigate back to the home page buffer
" in instances where the issue buffer was opened on top of it.
function! repoman#RepoManBack() abort
    let l:post_bufs = [
        \s:repoman_bufs.comment,
        \s:repoman_bufs.new_issue,
        \s:repoman_bufs.new_req,
        \s:repoman_bufs.labels
    \]

    " Reopen listview buffer, and close the issue buffer
    if bufwinnr(s:repoman_bufs.issue_list) < 0
        execute 'b ' . fnameescape(s:repoman_bufs.issue_list)
    endif

    if bufwinnr(s:repoman_bufs.issue) > 0
        for buffer in l:post_bufs
            if bufwinnr(buffer) > 0
                echo s:strings.error . ' Cannot close issue while updating'
                return
            endif
        endfor
        execute 'bw! ' . fnameescape(s:repoman_bufs.issue)
    elseif bufwinnr(s:repoman_bufs.issue_list) > 0 && !s:in_repo
        " Reset view to repo list
        set modifiable
        let s:repoman.repo = ''
        let s:repoman.page = 1
        let s:repoman_max_page = -1
        call repoman#RepoMan()
    endif

    " Reset issue number
    let s:repoman.current_issue = -1
    let s:repoman.in_pr = 0
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

    if bufexists(bufnr(s:repoman_bufs.issue_list)) > 0
        execute 'bw! ' . fnameescape(s:repoman_bufs.issue_list)
    endif

    let s:repoman.page += a:1
    let l:page_issues = s:in_repo || !empty(s:repoman.repo)
    let l:response = l:page_issues ? IssueListQuery() : RepoListQuery()

    if len(l:response) < 10
        let s:repoman_max_page = s:repoman.page
    endif
    let s:buf_create = l:page_issues ? function('CreateIssueListBuffer') : function('CreateRepoListBuffer')
    call s:buf_create(l:response)
endfunction

" :RepoManJump can be used on the home page buffer to jump between
" issues by direction (1 for forwards, -1 for backwards)
function! repoman#RepoManJump(...) abort
    let l:current_line = getcurpos()[1]
    let l:direction = a:1
    let l:idx = 0
    let l:has_new_pos = 0

    while l:idx < len(b:jump_guide)
        let l:jump_idx = b:jump_guide[l:idx]
        if l:direction > 0 && l:jump_idx > l:current_line
            let l:has_new_pos = 1
            let l:current_line = l:jump_idx
            break
        elseif l:direction < 0 && l:jump_idx >= l:current_line
            let l:has_new_pos = 1
            let l:current_line = b:jump_guide[l:idx - 1]
            break
        endif

        let l:idx += 1
    endwhile

    if !l:has_new_pos
        " Cycle back to beginning/end
        let l:current_line = b:jump_guide[l:direction ? 0 : -1]
    endif

    call cursor(l:current_line, 0)
endfunction

" --------------------------------------------------------------
" Interaction --------------------------------------------------
" --------------------------------------------------------------
" :RepoManComment splits the issue buffer in half horizontally,
" and allows the user to enter a comment of any length.
"
" Used in conjunction with :RepoManPost to post the comment.
function! repoman#RepoManComment() abort
    if bufexists(bufnr(s:repoman_bufs.comment)) > 0
        echo s:strings.error . 'Post buffer already open'
        return
    elseif s:repoman.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to comment!'
        return
    endif

    call CreateCommentBuffer()
endfunction

function! repoman#RepoManLabel() abort
    if bufexists(bufnr(s:repoman_bufs.labels)) > 0
        echo s:strings.error . 'Labels buffer already open'
        return
    elseif s:repoman.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to label'
        return
    endif

    set cmdheight=4
    echo s:strings.load

    call CreateLabelsBuffer(LabelsQuery(s:repoman.current_issue))
endfunction

" :RepoManPost posts the contents of the comment buffer to the
" comment section for whichever issue/PR/MR is currently open.
function! repoman#RepoManPost() abort
    if bufexists(bufnr(s:repoman_bufs.new_issue)) > 0 || bufexists(bufnr(s:repoman_bufs.new_req))
        " Determine which buffer to use for the post
        let l:post_buf = s:repoman_bufs.new_issue
        let l:pr = 0
        if bufexists(bufnr(s:repoman_bufs.new_req))
            let l:post_buf = s:repoman_bufs.new_req
            let l:pr = 1
        endif

        " Focus on active buffer for issue/request creation
        execute 'b ' . fnameescape(l:post_buf)

        " Extract title and body segments
        let l:title = getline(1)
        let l:body = join(getline(3, '$'), '\n')
        call NewItem(l:pr, l:title, l:body)
        execute 'bw! ' . fnameescape(l:post_buf)
    elseif bufexists(bufnr(s:repoman_bufs.comment)) > 0
        execute 'b ' . fnameescape(s:repoman_bufs.comment)

        " Condense buffer into a single line with line break chars
        let l:comment_text = join(getline(1, '$'), '\n')

        call PostComment(l:comment_text)
        execute 'bw! ' . fnameescape(s:repoman_bufs.comment)
    elseif bufexists(bufnr(s:repoman_bufs.labels)) > 0
        execute 'b ' . fnameescape(s:repoman_bufs.labels)

        " Determine which labels are active
        let active_labels = []
        for label in getline(1, '$')
            if stridx(label, '[x]') == 0
                let label_name = substitute(label, '\[x\] ', '', '')
                call add(active_labels, label_name)
            endif
        endfor

        call UpdateLabels(s:repoman.current_issue, l:active_labels)
        execute 'bw! ' . fnameescape(s:repoman_bufs.labels)
    else
        echo s:strings.error . 'No buffers open to post'
        return
    endif

    set modifiable
    call SoftReload()
endfunction

" :RepoManNew creates a new issue/PR/MR.
" - a:1: Either 'issue' or 'pr'/'mr'
function! repoman#RepoManNew(...) abort
    let l:item_type = a:1
    if bufexists(bufnr(s:repoman_bufs.new_issue)) > 0 || bufexists(bufnr(s:repoman_bufs.new_req))
        echo s:strings.error . 'New item buffer already open'
        return
    endif

    call NewItemBuffer(l:item_type)
endfunction

" :RepoManClose closes the currently selected issue/PR/MR, depending
" on the current active buffer.
function! repoman#RepoManClose() abort
    let l:number_to_close = s:repoman.current_issue
    let l:pr = s:repoman.in_pr
    let l:reset_current = 1

    " Check to see if the user is not in an issue buffer, and
    " if not, close the issue under their cursor
    if expand('%:p') =~ s:repoman_bufs.issue_list
        let l:number_to_close = b:issue_lookup[getcurpos()[1]][s:r_keys.number]
        let l:pr = b:issue_lookup[getcurpos()[1]]['is_pr']
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

" ============================================================================
" External Script Calls
" ============================================================================
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
        \repoman#utils#GetCacheFile('home'), s:repoman.token_pw)
    return l:response
endfunction

function! IssueQuery(number, pr) abort
    let s:repoman.number = a:number
    let s:repoman.pr = a:pr
    let l:response = s:api.View(s:repoman)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:response)),
        \repoman#utils#GetCacheFile('issue'), s:repoman.token_pw)
    return l:response
endfunction

function! LabelsQuery(number) abort
    let s:repoman.number = a:number
    let l:response = s:api.ViewLabels(s:repoman)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:response)),
        \repoman#utils#GetCacheFile('labels'), s:repoman.token_pw)
    return l:response
endfunction

function! PostComment(comment) abort
    let s:repoman.body = a:comment
    let s:repoman.number = s:repoman.current_issue
    let s:repoman.pr = s:repoman.in_pr
    call s:api.PostComment(s:repoman)
endfunction

function! UpdateLabels(number, labels) abort
    let s:repoman.number = a:number
    let s:repoman.labels = a:labels
    let l:response = s:api.UpdateLabels(s:repoman)
    call repoman#utils#UpdateLocalLabels(s:repoman)
    return l:response
endfunction

function! NewItem(type, title, body) abort
    let s:repoman.title = a:title
    let s:repoman.body = a:body
    let s:repoman.pr = (a:type ==? 'issue' ? 0 : 1)
    call s:api.NewItem(s:repoman)
endfunction

function! CloseItem(number, pr) abort
    let s:repoman.number = a:number
    let s:repoman.pr = a:pr
    call s:api().CloseItem(s:repoman)
endfunction

" ============================================================================
" Interactions
" ============================================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, in_pr) abort
    let s:repoman.in_pr = a:in_pr
    set cmdheight=4
    echo s:strings.load

    call CreateIssueBuffer(IssueQuery(a:issue_number, a:in_pr))
endfunction

" ============================================================================
" Buffer Functions
" ============================================================================

" Write out header to buffer, including the name of the repo.
function! SetHeader(show_page_num) abort
    let l:line_idx = 1
    for line in readfile(g:repoman_dir . '/assets/header.txt')
        let l:page_id = a:show_page_num ? ' (page ' . s:repoman.page . ')' : ''
        if l:line_idx == 1
            if empty(s:repoman.repo)
                let l:line_idx = WriteLine(line[:-3] . l:page_id)
            else
                let l:line_idx = WriteLine(line . ' ' . s:repoman.repo . l:page_id)
            endif
        else
            let l:line_idx = WriteLine(line)
        endif
    endfor

    return l:line_idx
endfunction

" Create a buffer for a comment
function! CreateCommentBuffer() abort
    set splitbelow
    new
    execute 'file ' . fnameescape(s:repoman_bufs.comment)
    call WriteLine(s:strings.comment_help)
    call FinishOutput()

    " Re-enable modifiable so that we can write something
    set modifiable
endfunction

" Create a buffer to pick labels for an issue/pr/etc
function! CreateLabelsBuffer(contents) abort
    set splitbelow
    new
    execute 'file ' . fnameescape(s:repoman_bufs.labels)
    for label in a:contents
        let l:toggle = '[ ] '
        if has_key(label, 'active')
            let l:toggle = '[x] '
        endif
        call WriteLine(l:toggle . label['name'])
        call WriteLine('    ' . label['description'])
    endfor

    nnoremap <buffer> <silent> <CR> :call ToggleLabel()<cr>

    call FinishOutput()
endfunction

function! ToggleLabel() abort
    set modifiable

    let l:line = getline(getcurpos()[1])
    if stridx(l:line, '[x]') == 0
        let l:line = substitute(l:line, '\[x\]', '\[ \]', '')
    else
        let l:line = substitute(l:line, '\[ \]', '\[x\]', '')
    endif

    call setline(getcurpos()[1], l:line)
    set nomodifiable
endfunction

" Create a buffer for a new item (issue/pr/mr/etc)
function! NewItemBuffer(type) abort
    set splitbelow
    new

    let l:descriptor = 'Issue'

    if a:type ==? 'issue'
        execute 'file ' . fnameescape(s:repoman_bufs.new_issue)
    else
        execute 'file ' . fnameescape(s:repoman_bufs.new_req)
        let l:descriptor = 'Request'
    endif

    call WriteLine(l:descriptor . ' ' . s:strings.title)
    call WriteLine(repeat('-', 20))
    call WriteLine(l:descriptor . ' ' . s:strings.desc)
    call FinishOutput()

    " Re-enable modifiable so that we can write something
    set modifiable
endfunction

" Create issue/(pull|merge) request buffer
function! CreateIssueBuffer(contents) abort
    let l:line_idx = OpenBuffer(s:repoman_bufs.issue, 0)
    let s:results_line = l:line_idx

    " Write issue and comments to buffer
    let l:type = (s:repoman.in_pr ? s:strings.pr : s:strings.issue)
    call WriteLine(l:type . '#' . a:contents[s:r_keys.number] . ': ' . a:contents[s:r_keys.title])
    let l:line_idx = WriteLine(s:decorations.spacer_small)

    " Split body on line breaks for proper formatting
    let l:line_idx += InsertBodyText(a:contents[s:r_keys.desc])

    call WriteLine(s:decorations.spacer_small)
    call WriteLine(s:strings.created . FormatTime(a:contents[s:r_keys.created_at]))
    call WriteLine(s:strings.updated . FormatTime(a:contents[s:r_keys.updated_at]))
    call WriteLine(s:strings.author . a:contents[s:r_keys.user][s:r_keys.login])
    call WriteLine(s:strings.labels . ParseLabels(a:contents[s:r_keys.labels]))
    call WriteLine(s:decorations.spacer_small)

    " Add reactions to issue (important)
    let l:reactions_str = GenerateReactionsStr(a:contents)
    if !empty(l:reactions_str)
        call WriteLine(l:reactions_str)
    endif

    call WriteLine(s:decorations.spacer_small)
    call WriteLine('')

    let l:line_idx = WriteLine(s:strings.comments_alt . '(' . len(a:contents[s:r_keys.comments]) . ')')

    for comment in a:contents[s:r_keys.comments]
        call InsertComment(comment)
    endfor

    " Store issue number for interacting with the issue (commenting, closing,
    " etc)
    let s:repoman.current_issue = a:contents[s:r_keys.number]

    call FinishOutput()
endfunction

" Creates a buffer for the list of issues or PRs.
function! CreateIssueListBuffer(results) abort
    let l:line_idx = OpenBuffer(s:repoman_bufs.issue_list, 1)
    let s:results_line = l:line_idx
    let b:issue_lookup = {}
    let b:jump_guide = []

    " Write issue details to buffer
    for item in a:results
        " Set title and indicator for whether or not the item is a Pull
        " Request
        let l:item_name = (has_key(item, 'pull_request')
            \? s:strings.pr : s:strings.issue) .
            \'#' . item[s:r_keys.number] . ': ' . item[s:r_keys.title]
        let l:start_idx = WriteLine(l:item_name)
        call add(b:jump_guide, l:start_idx)

        " Draw boundary between title and body
        let l:line_idx = WriteLine(s:decorations.spacer_small)

        let l:label_list = ParseLabels(item[s:r_keys.labels])
        call WriteLine(s:strings.comments . item[s:r_keys.comments])
        call WriteLine(s:strings.labels . l:label_list)
        call WriteLine(s:strings.updated . FormatTime(item[s:r_keys.updated_at]))

        " Mark line number where the issue interaction should stop
        let l:line_idx = WriteLine('')
        call WriteLine(s:decorations.spacer)
        call WriteLine('')

        " Store issue number and title to use for viewing issue details later
        while l:start_idx <= l:line_idx
            let b:issue_lookup[l:start_idx] = {
                \'number': item[s:r_keys.number],
                \'title': item[s:r_keys.title],
                \'is_pr': has_key(item, 'pull_request')
            \}
            let l:start_idx += 1
        endwhile
    endfor

    " Set up the ability to hit Enter on any issue section to open an issue
    " buffer
    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue(
        \b:issue_lookup[getcurpos()[1]]['number'],
        \b:issue_lookup[getcurpos()[1]]['is_pr'])<cr>

    " Allow gn shortcut for jumping to next issue in the list
    nnoremap <buffer> <silent> J :RepoManJump 1<CR>
    nnoremap <buffer> <silent> K :RepoManJump -1<CR>
    nnoremap <script> <silent> L :RepoManPage 1<CR>
    nnoremap <script> <silent> H :RepoManPage -1<CR>
    call FinishOutput()
endfunction

function! CreateRepoListBuffer(repos) abort
    let l:line_idx = OpenBuffer(s:repoman_bufs.issue_list, 1)
    let s:results_line = l:line_idx
    let b:repo_lookup = {}
    let b:jump_guide = []

    " Write repo details to buffer
    for item in a:repos
        let l:start_idx = WriteLine(item['full_name'] . (item['private'] ? ' (Private)' : ''))
        call add(b:jump_guide, l:start_idx)

        call WriteLine(s:decorations.spacer_small)
        call WriteLine(item['description'])
        call WriteLine(s:strings.updated . FormatTime(item[s:r_keys.updated_at]))
        call WriteLine('Issues:   ' . item['open_issues_count'])
        call WriteLine('★ ' . item['stargazers_count'])
        call WriteLine(s:decorations.spacer_small)

        let l:line_idx = WriteLine('')
        call WriteLine(s:decorations.spacer)
        call WriteLine('')

        while l:start_idx <= l:line_idx
            let b:repo_lookup[l:start_idx] = {
                \'path': item['full_name']
            \}
            let l:start_idx += 1
        endwhile
    endfor

    " Set up the ability to hit Enter on any issue section to open an issue
    " buffer
    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call CreateIssueListBuffer(
        \IssueListQuery(b:repo_lookup[getcurpos()[1]]['path']))<cr>

    call FinishOutput()
endfunction

" ============================================================================
" Utils
" ============================================================================

" Parses labels from an array into a comma separated list, as well as sets
" highlighting rules for each label (if a color is returned in the
" response).
"
" Returns a comma separated list of label.
function! ParseLabels(labels) abort
    let l:label_list = ''

    for label in a:labels
        let l:label_name = '|' . label['name'] . '|'

        " Use colors for labels if provided by the response
        if has_key(label, 'color')
            let l:label_color = '#' . label['color']

            exe 'hi ' . substitute(label['name'], '[^a-zA-Z]', '', 'g') . ' gui=bold guifg=' . l:label_color
            exe 'syn match ' . substitute(label['name'], '[^a-zA-Z]', '', 'g') . ' /' . l:label_name . '/'
        endif

        " Append a comma if there is more than one tag
        if l:label_list =~? '[^\s]'
            let l:label_list = l:label_list . ', '
        endif

        let l:label_list = l:label_list . l:label_name
    endfor

    return l:label_list
endfunction

" Insert segments of issue/request body, inserting line breaks as
" needed.
"
" Returns a cursor position for the next line draw
function! InsertBodyText(body) abort
    let l:chunk_num = 0
    for chunk in split(a:body, '\n')
        let chunk = substitute(chunk, '\"', '', 'ge')
        call WriteLine(chunk)
        let l:chunk_num += 1
    endfor

    return l:chunk_num
endfunction

" Inserts comments into the buffer
function! InsertComment(comment) abort
    let commenter = a:comment[s:r_keys.user][s:r_keys.login]
    if has_key(a:comment, 'author_association') && a:comment['author_association'] !=? 'none'
        let commenter = '(' . tolower(a:comment['author_association']) . ') ' . commenter
    endif

    call WriteLine(s:decorations.spacer)

    " If this is a review comment, it needs different formatting/coloring
    if has_key(a:comment, 'pull_request_review_id')
        set syntax=diff
        call InsertReviewComment(a:comment)
    else
        call WriteLine(FormatTime(a:comment[s:r_keys.created_at]))
        call WriteLine(commenter . ': ')
        call WriteLine('')

        " Split comment body on line breaks for proper formatting
        for comment_line in split(a:comment[s:r_keys.body], '\n')
            call WriteLine(comment_line)
        endfor

        let l:reactions_str = GenerateReactionsStr(a:comment)
        if !empty(l:reactions_str)
            call WriteLine('')
            call WriteLine(l:reactions_str)
        endif
    endif

    call WriteLine('')
endfunction

" Inserts a comment for a Pull Request review
function! InsertReviewComment(comment) abort
    " The 'position' element indicates if this comment is still relevant
    " in the current state of the pull request
    if !a:comment['position']
        if exists('g:repoman_show_outdated') && g:repoman_show_outdated
            call WriteLine(s:strings.outdated)
        else
            call WriteLine(s:strings.outdated . ' ' . s:strings.hidden)
            return
        endif
    endif

    " Write out the file name and 'diff hunk' (the snippet of the
    " diff that is relevant for the comment)
    call WriteLine('[' . a:comment['path'] . ']')
    for diff_line in split(a:comment['diff_hunk'], '\n')
        call WriteLine(diff_line)
    endfor

    call WriteLine('|------')

    " Each individual review comment can have its own subdiscussion, which
    " is tracked in the 'review_comments' array
    for review_comment in a:comment['review_comments']
        let commenter = review_comment[s:r_keys.login]
        if has_key(review_comment, 'author_association') && review_comment['author_association'] !=? 'none'
            let commenter = '(' . tolower(review_comment['author_association']) . ') ' . commenter
        endif
        call WriteLine('| ' . FormatTime(review_comment[s:r_keys.created_at]))
        call WriteLine('| ' . commenter . ': ')
        for body_line in split(review_comment['comment'], '\n')
            " If there's a suggestion, replace w/ relevant syntax highlighting
            " for the file
            if body_line =~# 'suggestion'
                call WriteLine('| ' . s:strings.suggestion)
                let extension = fnamemodify(a:comment['path'], ':e')
                let body_line = substitute(body_line, 'suggestion', extension, '')
            endif
            call WriteLine('| ' . body_line)
        endfor

        let l:reactions_str = GenerateReactionsStr(review_comment)
        if !empty(l:reactions_str)
            call WriteLine('| ')
            call WriteLine('| ' . l:reactions_str)
        endif

        call WriteLine('|------')
    endfor
endfunction

" Generates a string from a set of reactions
"
" Returns a string
function! GenerateReactionsStr(item) abort
    let l:reaction_map = {
        \'+1': '👍 ',
        \'-1': '👎 ',
        \'laugh': '😂 ',
        \'eyes': '👀 ',
        \'hooray': '🎉 ',
        \'confused': '😕 ',
        \'heart': '❤️ ',
        \'rocket': '🚀 '
    \}

    if !has_key(a:item, 'reactions')
        return s:strings.no_reactions
    endif

    let l:reactions = a:item['reactions']
    let l:reaction_str = ''

    for key in keys(l:reaction_map)
        if has_key(l:reactions, key) && l:reactions[key] > 0
            let l:reaction_str = l:reaction_str .
                \l:reaction_map[key] . 'x' . l:reactions[key] . ' '
        endif
    endfor

    return (len(l:reaction_str) > 0 ? l:reaction_str : s:strings.no_reactions)
endfunction

" Removes alphabetical characters from time string.
" Returns an easily readable time str (ex: 2020-10-07 15:10:03)
function! FormatTime(time_str) abort
    return substitute(a:time_str, '[a-zA-Z]', ' ', 'g')
endfunction

function! OpenBuffer(buf_name, show_page_num) abort
    if bufexists(bufnr(a:buf_name)) > 0
        execute 'bw! ' . fnameescape(a:buf_name)
    endif

    if line('$') ==? 1 && getline(1) ==? ''
        enew  " Use whole window for results
    elseif winwidth(0) > winheight(0) * 2
        vnew  " Window is wide enough for vertical split
    else
        new   " Window is too narrow, use horizontal split
    endif

    execute 'file ' . fnameescape(a:buf_name)
    setlocal bufhidden=hide noswapfile wrap

    let l:line_idx = SetHeader(a:show_page_num)
    return l:line_idx
endfunction

" Filters out bad characters, brings the cursor to the top of the
" buffer, and sets the buffer as not modifiable
function! FinishOutput() abort
    setlocal nomodifiable
    set cmdheight=1 hidden bt=nofile splitright
    call repoman#utils#LoadSyntaxColoring()

    " Add HJKL shortcuts if in the buffer supports it
    if exists('b:jump_guide')
        nnoremap <buffer> <silent> J :RepoManJump 1<CR>
        nnoremap <buffer> <silent> K :RepoManJump -1<CR>
        nnoremap <buffer> <silent> L :RepoManPage 1<CR>
        nnoremap <buffer> <silent> H :RepoManPage -1<CR>
    endif
endfunction

" Writes a line to the buffer
"
" Returns the current line position
function! WriteLine(line) abort
    if empty(getline(1))
        " Write over line 1 if empty
        call setline(1, substitute(a:line, '', '', 'ge'))
        return 2
    endif

    " Write to the next line
    let l:pos = line('$') + 1
    call setline(l:pos, substitute(a:line, '', '', 'ge'))
    return l:pos
endfunction

" Resets the RepoMan script dictionary
function! ResetState() abort
    let s:repoman = {
        \'token_pw': s:repoman.token_pw,
        \'current_issue': s:repoman.current_issue,
        \'in_pr': s:repoman.in_pr,
        \'page': s:repoman.page,
        \'repo': s:repoman.repo
    \}
endfunction

" Reloads the current view using locally updated content
function! SoftReload() abort
    " Remove existing buffers
    if bufexists(bufnr(s:repoman_bufs.issue_list)) > 0
        execute 'bw! ' . fnameescape(s:repoman_bufs.issue_list)
    endif

    if bufexists(bufnr(s:repoman_bufs.issue)) > 0
        execute 'bw! ' . fnameescape(s:repoman_bufs.issue)
    endif

    " Recreate home and issue buffer w/ locally updated files
    call CreateIssueListBuffer(json_decode(
        \repoman#crypto#Decrypt(
        \repoman#utils#GetCacheFile('home'), s:repoman.token_pw)))
    if s:repoman.current_issue != -1
        call CreateIssueBuffer(json_decode(
            \repoman#crypto#Decrypt(
            \repoman#utils#GetCacheFile('issue'), s:repoman.token_pw)))
    endif
endfunction

nnoremap <script> <silent> <BS> :RepoManBack<CR>

