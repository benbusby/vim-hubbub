" ============================================================================
" File:        vimgmt.vim
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://github.com/benbusby/vimgmt
" Version:     1.0
" ============================================================================
scriptencoding utf-8

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

let s:vimgmt_spacer = repeat('─ ', 27)
let s:vimgmt_spacer_small = repeat('─', 33)
"let s:vimgmt_comment_pad = repeat(' ', 4)

let s:vimgmt_bufs = {
    \'issue':     '/tmp/issue.vimgmt.diff',
    \'main':      '/tmp/vimgmt.vimgmt',
    \'comment':   '/tmp/comment.vimgmt',
    \'new_issue': '/tmp/new_issue.vimgmt',
    \'new_req':   '/tmp/new_req.vimgmt'
\}

let s:vimgmt = {
    \'token_pw': '',
    \'current_issue': -1,
    \'in_pr': 0
\}

let s:reactions = {
    \'+1': '👍',
    \'-1': '👎',
    \'laugh': '🤣',
    \'eyes': '👀',
    \'hooray': '🎉',
    \'confused': '🤔',
    \'heart': '🫀',
    \'rocket': '🚀'
\}

" Set language, if available
let lang_dict = json_decode(readfile(s:dir . '/assets/strings.json'))
let s:strings = lang_dict[(exists('g:vimgmt_lang') ? g:vimgmt_lang : 'en')]

" ============================================================================
" Commands
" ============================================================================

" --------------------------------------------------------------
" Navigation ---------------------------------------------------
" --------------------------------------------------------------
" :Vimgmt can either:
"   - Open a new instance of Vimgmt to the 'home' view. If
"     there's already a Vimgmt buffer open, it will:
"   - Refresh the currently active Vimgmt buffers
function! vimgmt#Vimgmt() abort
    if len(s:vimgmt.token_pw) > 0
        set cmdheight=4
        echo s:strings.refresh

        " User is already using Vimgmt, treat as a refresh
        if bufexists(bufnr(s:vimgmt_bufs.main)) > 0
            execute 'bw! ' . fnameescape(s:vimgmt_bufs.main)
        endif

        if bufexists(bufnr(s:vimgmt_bufs.issue)) > 0
            execute 'bw! ' . fnameescape(s:vimgmt_bufs.issue)
        endif
    else
        " New session, prompt for token pw
        call inputsave()
        let s:vimgmt.token_pw = inputsecret(s:strings.pw_prompt)
        call inputrestore()
    endif

    " Recreate home buffer, and optionally the issue buffer
    " as well
    call CreateHomeBuffer(HomePageQuery())
    if s:vimgmt.current_issue != -1
        call CreateIssueBuffer(IssueQuery(s:vimgmt.current_issue, s:vimgmt.in_pr))
    endif
endfunction

" :VimgmtBack can be used to navigate back to the home page buffer
" in instances where the issue buffer was opened on top of it.
function! vimgmt#VimgmtBack() abort
    " Reopen main 'vimgmt.tmp' buffer, and close the issue buffer
    execute 'b ' . fnameescape(s:vimgmt_bufs.main)
    execute 'bw! ' . fnameescape(s:vimgmt_bufs.issue)

    " Reset issue number
    let s:vimgmt.current_issue = -1
    let s:vimgmt.in_pr = 0
endfunction

" --------------------------------------------------------------
" Interaction --------------------------------------------------
" --------------------------------------------------------------
" :VimgmtComment splits the issue buffer in half horizontally,
" and allows the user to enter a comment of any length.
"
" Used in conjunction with :VimgmtPost to post the comment.
function! vimgmt#VimgmtComment() abort
    if bufexists(bufnr(s:vimgmt_bufs.comment)) > 0
        echo s:strings.error . 'Post buffer already open'
        return
    elseif s:vimgmt.current_issue <= 0
        echo s:strings.error . 'Must be on an issue/PR page to comment!'
        return
    endif

    call CreateCommentBuffer()
endfunction

" :VimgmtPost posts the contents of the comment buffer to the
" comment section for whichever issue/PR/MR is currently open.
function! vimgmt#VimgmtPost() abort
    if bufexists(bufnr(s:vimgmt_bufs.new_issue)) > 0 || bufexists(bufnr(s:vimgmt_bufs.new_req))
        " Determine which buffer to use for the post
        let l:post_buf = s:vimgmt_bufs.new_issue
        let l:pr = 0
        if bufexists(bufnr(s:vimgmt_bufs.new_req))
            let l:post_buf = s:vimgmt_bufs.new_req
            let l:pr = 1
        endif

        " Focus on active buffer for issue/request creation
        execute 'b ' . fnameescape(l:post_buf)

        " Format double quotes
        silent %s/\"/\\\\\\"/ge

        " Extract title and body segments
        let l:title = getline(1)
        let l:body = join(getline(3, '$'), '\n')
        call NewItem(l:pr, l:title, l:body)
        execute 'bw! ' . fnameescape(l:post_buf)
    elseif bufexists(bufnr(s:vimgmt_bufs.comment)) > 0
        execute 'b ' . fnameescape(s:vimgmt_bufs.comment)

        " Format double quotes
        silent %s/\"/\\\\\\"/ge

        " Condense buffer into a single line with line break chars
        let l:comment_text = join(getline(1, '$'), '\n')
        call PostComment(l:comment_text)
        execute 'bw! ' . fnameescape(s:vimgmt_bufs.comment)
    else
        echo s:strings.error . 'No buffers open to post'
        return
    endif

    call vimgmt#Vimgmt()
endfunction

" :VimgmtNew creates a new issue/PR/MR.
" - a:1: Either 'issue' or 'pr'/'mr'
function! vimgmt#VimgmtNew(...) abort
    let l:item_type = a:1
    if bufexists(bufnr(s:vimgmt_bufs.new_issue)) > 0 || bufexists(bufnr(s:vimgmt_bufs.new_req))
        echo s:strings.error . 'New item buffer already open'
        return
    endif

    call NewItemBuffer(l:item_type)
endfunction

" :VimgmtClose closes the currently selected issue/PR/MR, depending
" on the current active buffer.
function! vimgmt#VimgmtClose() abort
    let l:number_to_close = s:vimgmt.current_issue
    let l:pr = s:vimgmt.in_pr
    let l:reset_current = 1

    " Check to see if the user is not in an issue buffer, and
    " if not, close the issue under their cursor
    if expand('%:p') =~ s:vimgmt_bufs.main
        let l:number_to_close = b:issue_lookup[getcurpos()[1]]['number']
        let l:pr = b:issue_lookup[getcurpos()[1]]['is_pr']
        let l:reset_current = 0
    endif

    call inputsave()
    let s:answer = input(s:strings.close . '#' . l:number_to_close . '? (y/n) ')
    call inputrestore()

    if s:answer ==? 'y'
        call CloseItem(l:number_to_close, l:pr)
        if l:reset_current
            let s:vimgmt.current_issue = -1
        endif
        call vimgmt#Vimgmt()
    endif
endfunction

" ============================================================================
" External Script Calls
" ============================================================================

function! HomePageQuery() abort
    let s:vimgmt.command = 'view_all'
    return json_decode(VimgmtScript())
endfunction

function! IssueQuery(number, pr) abort
    let s:vimgmt.command = 'view'
    let s:vimgmt.number = a:number
    let s:vimgmt.pr = a:pr
    return json_decode(VimgmtScript())
endfunction

function! PostComment(comment) abort
    let s:vimgmt.command = 'comment'
    let s:vimgmt.body = a:comment
    let s:vimgmt.number = s:vimgmt.current_issue
    let s:vimgmt.pr = s:vimgmt.in_pr
    call VimgmtScript()
endfunction

function! NewItem(type, title, body) abort
    let s:vimgmt.command = 'new'
    let s:vimgmt.title = a:title
    let s:vimgmt.body = a:body
    let s:vimgmt.pr = (a:type ==? 'issue' ? 0 : 1)
    call VimgmtScript()
endfunction

function! CloseItem(number, pr) abort
    let s:vimgmt.command = 'close'
    let s:vimgmt.number = a:number
    let s:vimgmt.pr = a:pr
    call VimgmtScript()
endfunction

function! VimgmtScript() abort
    " Use double quotes here to avoid unneccessary confusion when calling the
    " script with a single-quoted json body
    let l:response = system(
                \s:dir . "/scripts/vimgmt.sh '" .
                \substitute(json_encode(s:vimgmt), "'", "'\\\\''", "g")
                \. "'")
    call ResetState()
    return l:response
endfunction

" ============================================================================
" Interactions
" ============================================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, in_pr) abort
    let s:vimgmt.in_pr = a:in_pr
    set cmdheight=4
    echo s:strings.load

    call CreateIssueBuffer(IssueQuery(a:issue_number, a:in_pr))
endfunction

" ============================================================================
" Buffer Functions
" ============================================================================

" Write out header to buffer, including the name of the repo.
function! SetHeader() abort
    let l:line_idx = 1
    for line in readfile(s:dir . '/assets/header.txt')
        if l:line_idx == 1
            let l:repo_name = system(
                \'source ' . s:dir . '/scripts/vimgmt_utils.sh && get_path'
            \)
            let l:line_idx = WriteLine(line . ' ' . l:repo_name)
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
    execute "file " . fnameescape(s:vimgmt_bufs.comment)
    call WriteLine(s:strings.comment_help)
    call CloseBuffer()

    " Re-enable modifiable so that we can write something
    set modifiable
endfunction

" Create a buffer for a new item (issue/pr/mr/etc)
function! NewItemBuffer(type) abort
    set splitbelow
    new

    let l:descriptor = 'Issue'

    if a:type ==? 'issue'
        execute "file " . fnameescape(s:vimgmt_bufs.new_issue)
    else
        execute "file " . fnameescape(s:vimgmt_bufs.new_req)
        let l:descriptor = 'Request'
    endif

    call WriteLine(l:descriptor . ' ' . s:strings.title)
    call WriteLine(repeat('-', 20))
    call WriteLine(l:descriptor . ' ' . s:strings.desc)
    call CloseBuffer()

    " Re-enable modifiable so that we can write something
    set modifiable
endfunction

" Create issue/(pull|merge) request buffer
function! CreateIssueBuffer(contents) abort
    if winwidth(0) > winheight(0) * 2
        vnew   " Window is wide enough for vertical split
    else
        enew   " Window is too narrow, use new buffer
    endif

    " Clear buffer if it already exists
    if bufexists(bufnr(s:vimgmt_bufs.issue)) > 0
        execute 'bw! ' . fnameescape(s:vimgmt_bufs.issue)
    endif
    execute "file " . fnameescape(s:vimgmt_bufs.issue)
    set hidden ignorecase
    setlocal bufhidden=hide noswapfile wrap

    let l:line_idx = SetHeader()
    let s:results_line = l:line_idx

    " Write issue and comments to buffer
    let l:type = (s:vimgmt.in_pr ? s:strings.pr : s:strings.issue)
    call WriteLine(l:type . '#' . a:contents['number'] . ': ' . a:contents['title'])
    let l:line_idx = WriteLine(s:vimgmt_spacer_small)

    " Split body on line breaks for proper formatting
    let l:line_idx += InsertBodyText(a:contents['body'])

    call WriteLine(s:vimgmt_spacer_small)
    call WriteLine(s:strings.created . FormatTime(a:contents['created_at']))
    call WriteLine(s:strings.updated . FormatTime(a:contents['updated_at']))
    call WriteLine(s:strings.author . a:contents['user']['login'])
    call WriteLine(s:vimgmt_spacer_small)

    " Add reactions to issue (important)
    let l:reactions_str = s:strings.no_reactions
    if has_key(a:contents, 'reactions')
        let l:reactions_str = GenerateReactionsStr(a:contents['reactions'])
    endif

    call WriteLine(l:reactions_str)
    call WriteLine(s:vimgmt_spacer_small)
    call WriteLine('')

    let l:line_idx = WriteLine(s:strings.comments_alt . '(' . len(a:contents['comments']) . ')')
    call InsertComments(a:contents['comments'])

    " Store issue number for interacting with the issue (commenting, closing,
    " etc)
    let s:vimgmt.current_issue = a:contents['number']

    call CloseBuffer()
endfunction

" Creates a buffer for the list of issues or PRs.
function! CreateHomeBuffer(results) abort
    if line('$') ==? 1 && getline(1) ==? ''
        enew  " Use whole window for results
    elseif winwidth(0) > winheight(0) * 2
        vnew  " Window is wide enough for vertical split
    else
        new   " Window is too narrow, use horizontal split
    endif
    execute "file " . fnameescape(s:vimgmt_bufs.main)
    setlocal bufhidden=hide noswapfile wrap

    let l:line_idx = SetHeader()
    let s:results_line = l:line_idx
    let b:issue_lookup = {}

    " Write issue details to buffer
    for item in a:results
        " Start index begins one line before content is written to allow
        " selecting an issue starting at the '- - - -' separator
        let start_idx = l:line_idx - 1

        " Set title and indicator for whether or not the item is a Pull
        " Request
        let l:item_name = (has_key(item, 'pull_request')
            \? s:strings.pr : s:strings.issue) .
            \'#' . item['number'] . ': ' . item['title']
        call WriteLine(l:item_name)

        " Draw boundary between title and body
        let l:line_idx = WriteLine(s:vimgmt_spacer_small)

        let l:label_list = ParseLabels(item['labels'])
        call WriteLine(s:strings.comments . item['comments'])
        call WriteLine(s:strings.labels . l:label_list)
        call WriteLine(s:strings.updated . FormatTime(item['updated_at']))
        call WriteLine('')
        call WriteLine(s:vimgmt_spacer)
        let l:line_idx = WriteLine('')

        " Store issue number and title to use for viewing issue details later
        while start_idx <= l:line_idx
            let b:issue_lookup[start_idx] = {
                \'number': item['number'],
                \'title': item['title'],
                \'is_pr': has_key(item, 'pull_request')
            \}
            let start_idx += 1
        endwhile
    endfor

    " Set up the ability to hit Enter on any issue section to open an issue
    " buffer
    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue(
        \b:issue_lookup[getcurpos()[1]]['number'],
        \b:issue_lookup[getcurpos()[1]]['is_pr'])<cr>

    call CloseBuffer()
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

" Inserts comments into the buffer.
"
" Returns a cursor position for the next line draw
function! InsertComments(comments) abort
    for comment in a:comments
        let commenter = comment['user']['login']
        if has_key(comment, 'author_association') && comment['author_association'] !=? 'none'
            let commenter = '(' . tolower(comment['author_association']) . ') ' . commenter
        endif
        call WriteLine(s:vimgmt_spacer)
        call WriteLine(FormatTime(comment['created_at']))
        call WriteLine(commenter . ':')
        call WriteLine('')

        " Split comment body on line breaks for proper formatting
        for comment_line in split(comment['body'], '\n')
            call WriteLine(comment_line)
        endfor

        call WriteLine('')
    endfor
endfunction

" Generates a string from a set of reactions
"
" Returns a string
function! GenerateReactionsStr(reactions) abort
    let l:reactions = ''
    for key in keys(s:reactions)
        if has_key(a:reactions, key) && a:reactions[key] > 0
            let l:reactions = l:reactions .
                \s:reactions[key] . ' x' . a:reactions[key] . ' '
        endif
    endfor

    return (len(l:reactions) > 0 ? l:reactions : s:strings.no_reactions)
endfunction

" Removes alphabetical characters from time string.
" Returns an easily readable time str (ex: 2020-10-07 15:10:03)
function! FormatTime(time_str) abort
    return substitute(a:time_str, '[a-zA-Z]', ' ', 'g')
endfunction

" Filters out bad characters, brings the cursor to the top of the
" buffer, and sets the buffer as not modifiable
function! CloseBuffer() abort
    set cmdheight=4
    silent %s///ge
    silent %s/\\"/"/ge
    silent %s/\%x00//ge
    normal gg
    setlocal nomodifiable
    set cmdheight=1 hidden bt=nofile splitright
endfunction

" Writes a line to the buffer
"
" Returns the current line position
function! WriteLine(line) abort
    if empty(getline(1))
        " Write over line 1 if empty
        call setline(1, a:line)
        return 2
    endif

    " Write to the next line
    let l:pos = line('$') + 1
    call setline(l:pos, a:line)
    return l:pos
endfunction

" Resets the Vimgmt script dictionary
function! ResetState() abort
    let s:vimgmt = {
        \'token_pw': s:vimgmt.token_pw,
        \'current_issue': s:vimgmt.current_issue,
        \'in_pr': s:vimgmt.in_pr
    \}
endfunction
