" ============================================================================
" File:        vimgmt.vim
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================
scriptencoding utf-8

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

" Formatting constants
let g:vimgmt_spacer = '─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ '
let g:vimgmt_spacer_small = '─────────────────────────────────'
let g:vimgmt_comment_pad = '    '

" Buffer names
let g:buf_vimgmt = '/tmp/vimgmt.vimgmt'
let g:buf_issue = '/tmp/issue.vimgmt'
let g:buf_comment = '/tmp/comment.vimgmt'
let g:buf_new_issue = '/tmp/new_issue.vimgmt'
let g:buf_new_request = '/tmp/new_request.vimgmt'

" Issue variables
let g:current_issue = -1
let g:in_pr = 0

let g:vimgmt_dict = {'token_pw': ''}

set fileformat=unix

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
    if len(g:vimgmt_dict.token_pw) > 0
        set cmdheight=4
        echo 'Refreshing...'

        " User is already using Vimgmt, treat as a refresh
        if bufexists(bufnr(g:buf_vimgmt)) > 0
            execute 'bw! ' . fnameescape(g:buf_vimgmt)
        endif

        if bufexists(bufnr(g:buf_issue)) > 0
            execute 'bw! ' . fnameescape(g:buf_issue)
        endif
    else
        " New session, prompt for token pw
        call inputsave()
        let g:vimgmt_dict.token_pw = inputsecret('Enter token password: ')
        call inputrestore()
    endif

    " Recreate home buffer, and optionally the issue buffer
    " as well
    call CreateHomeBuffer(HomePageQuery())
    if g:current_issue != -1
        call CreateIssueBuffer(IssueQuery(g:current_issue, g:in_pr))
    endif
endfunction

" :VimgmtBack can be used to navigate back to the home page buffer
" in instances where the issue buffer was opened on top of it.
function! vimgmt#VimgmtBack() abort
    " Reopen main 'vimgmt.tmp' buffer, and close the issue buffer
    execute 'b ' . fnameescape(g:buf_vimgmt)
    execute 'bw! ' . fnameescape(g:buf_issue)

    " Reset issue number
    let g:current_issue = -1
    let g:in_pr = 0
endfunction

" --------------------------------------------------------------
" Interaction --------------------------------------------------
" --------------------------------------------------------------
" :VimgmtComment splits the issue buffer in half horizontally,
" and allows the user to enter a comment of any length.
"
" Used in conjunction with :VimgmtPost to post the comment.
function! vimgmt#VimgmtComment() abort
    if bufexists(bufnr(g:buf_comment)) > 0
        echo 'Error: Post buffer already open'
        return
    elseif g:current_issue <= 0
        echo 'Error: Must be on an issue/PR page to comment!'
        return
    endif

    call CreateCommentBuffer()
endfunction

" :VimgmtPost posts the contents of the comment buffer to the
" comment section for whichever issue/PR/MR is currently open.
function! vimgmt#VimgmtPost() abort
    if bufexists(bufnr(g:buf_new_issue)) > 0 || bufexists(bufnr(g:buf_new_request))
        " Determine which buffer to use for the post
        let l:post_buf = g:buf_new_issue
        let l:pr = 0
        if bufexists(bufnr(g:buf_new_request))
            let l:post_buf = g:buf_new_request
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
    elseif bufexists(bufnr(g:buf_comment)) > 0
        execute 'b ' . fnameescape(g:buf_comment)

        " Format double quotes
        silent %s/\"/\\\\\\"/ge

        " Condense buffer into a single line with line break chars
        let l:comment_text = join(getline(1, '$'), '\n')
        call PostComment(l:comment_text)
        execute 'bw! ' . fnameescape(g:buf_comment)
    else
        echo 'Error: No buffers open to post'
        return
    endif

    call Vimgmt()
endfunction

" :VimgmtNew creates a new issue/PR/MR.
" - a:1: Either 'issue' or 'pr'/'mr'
function! vimgmt#VimgmtNew(...) abort
    let l:item_type = a:1
    if bufexists(bufnr(g:buf_new_issue)) > 0 || bufexists(bufnr(g:buf_new_request))
        echo 'Error: New item buffer already open'
        return
    endif

    call CreateItemBuffer(l:item_type)
endfunction

" :VimgmtClose closes the currently selected issue/PR/MR, depending
" on the current active buffer.
function! vimgmt#VimgmtClose() abort
    let l:number_to_close = g:current_issue
    let l:pr = g:in_pr
    if s:number_to_close <= 0
        let l:number = b:issue_lookup[getcurpos()[1]]['number']
        let l:pr = b:issue_lookup[getcurpos()[1]]['is_pr']
    endif

    call inputsave()
    let s:answer = input('Close #' . l:number . '? (y/n)')
    call inputrestore()

    if s:answer ==? 'y'
        call CloseItem(l:number_to_close, l:pr)
    endif
endfunction

" ============================================================================
" External Script Calls
" ============================================================================

function! HomePageQuery() abort
    let g:vimgmt_dict.command = 'view_all'
    return json_decode(VimgmtScript())
endfunction

function! IssueQuery(number, pr) abort
    let g:vimgmt_dict.command = 'view'
    let g:vimgmt_dict.number = a:number
    let g:vimgmt_dict.pr = a:pr
    return json_decode(VimgmtScript())
endfunction

function! PostComment(comment) abort
    let g:vimgmt_dict.command = 'comment'
    let g:vimgmt_dict.body = a:comment
    let g:vimgmt_dict.number = g:current_issue
    let g:vimgmt_dict.pr = g:in_pr
    call VimgmtScript()
endfunction

function! NewItem(type, title, body) abort
    let g:vimgmt_dict.command = 'new'
    let g:vimgmt_dict.title = a:title
    let g:vimgmt_dict.body = a:body
    let g:vimgmt_dict.pr = (a:type ==? 'issue' ? 0 : 1)
    call VimgmtScript()
endfunction

function! CloseItem(number, pr) abort
    let g:vimgmt_dict.command = 'close'
    let g:vimgmt_dict.number = a:number
    let g:vimgmt_dict.pr = a:pr
    call VimgmtScript()
endfunction

function! VimgmtScript() abort
    " Use double quotes here to avoid unneccessary confusion when calling the
    " script with a single-quoted json body
    let l:response = system(s:dir . "/scripts/vimgmt.sh '" . substitute(json_encode(g:vimgmt_dict), "'", "'\\\\''", "g") . "'")
    call ResetDict()
    return l:response
endfunction

" ============================================================================
" Interactions
" ============================================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, in_pr) abort
    let g:in_pr = a:in_pr
    set cmdheight=4
    echo "Loading..."

    if a:in_pr
        " TODO
        echo "TODO"
    else
        call CreateIssueBuffer(IssueQuery(a:issue_number))
    endif
endfunction

" ============================================================================
" Buffer Functions
" ============================================================================

" Write out header to buffer, including the name of the repo.
function! SetHeader() abort
    let l:line_idx = 1
    for line in readfile(s:dir . '/assets/header.txt')
        if l:line_idx == 1
            let l:repo_name = system('source ' . s:dir . '/scripts/vimgmt_utils.sh && get_path')
            call setline(l:line_idx, line . ' ' . l:repo_name)
        else
            call setline(l:line_idx, line)
        endif
        let l:line_idx += 1
    endfor

    return l:line_idx
endfunction

" Create a buffer for a comment
function! CreateCommentBuffer() abort
    set splitbelow
    new
    execute "file " . fnameescape(g:buf_comment)
    call setline(1, '<!-- Write comment here -->')
    call CloseBuffer()

    " Re-enable modifiable so that we can write something
    set modifiable
endfunction

" Create a buffer for a new item (issue/pr/mr/etc)
function! CreateItemBuffer(type) abort
    set splitbelow
    new

    let l:descriptor = 'Issue'

    if a:type ==? 'issue'
        execute "file " . fnameescape(g:buf_new_issue)
    else
        execute "file " . fnameescape(g:buf_new_request)
        let l:descriptor = 'Request'
    endif

    call setline(1, l:descriptor . ' Title')
    call setline(2, '--------------------')
    call setline(3, l:descriptor . ' Description')
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
    if bufexists(bufnr(g:buf_issue)) > 0
        execute 'bw! ' . fnameescape(g:buf_issue)
    endif
    execute "file " . fnameescape(g:buf_issue)
    set hidden ignorecase
    setlocal bufhidden=hide noswapfile wrap

    let l:line_idx = SetHeader()
    let s:results_line = l:line_idx

    " Write issue and comments to buffer
    call setline(l:line_idx, '(Issue) #' . a:contents['number'] . ': ' . a:contents['title'])
    call setline(l:line_idx + 1, g:vimgmt_spacer_small)

    " Split body on line breaks for proper formatting
    let l:chunk_num = InsertBodyText(a:contents['body'], l:line_idx + 2)

    call setline(l:line_idx + l:chunk_num + 2, g:vimgmt_spacer_small)
    call setline(l:line_idx + l:chunk_num + 3, 'Created: ' . FormatTime(a:contents['created_at']))
    call setline(l:line_idx + l:chunk_num + 4, 'Updated: ' . FormatTime(a:contents['updated_at']))
    call setline(l:line_idx + l:chunk_num + 5, 'Author:  ' . a:contents['user']['login'])
    call setline(l:line_idx + l:chunk_num + 6, g:vimgmt_spacer_small)
    call setline(l:line_idx + l:chunk_num + 7, '')
    call setline(l:line_idx + l:chunk_num + 8, g:vimgmt_comment_pad . 'Comments (' . len(a:contents['comments']) . ')')

    let l:line_idx += l:chunk_num + 9

    for comment in a:contents['comments']
        let commenter = comment['user']['login']
        if has_key(comment, 'author_association') && comment['author_association'] !=? 'none'
            let commenter = '(' . tolower(comment['author_association']) . ') ' . commenter
        endif
        call setline(l:line_idx, g:vimgmt_comment_pad . g:vimgmt_spacer)
        call setline(l:line_idx + 1, g:vimgmt_comment_pad . FormatTime(comment['created_at']))
        call setline(l:line_idx + 2, g:vimgmt_comment_pad . commenter . ':')
        call setline(l:line_idx + 3, g:vimgmt_comment_pad . '')

        " Split comment body on line breaks for proper formatting
        let l:chunk_num = 0
        for comment_line in split(comment['body'], '\n')
            call setline(l:line_idx + l:chunk_num + 4, g:vimgmt_comment_pad . comment_line)
            let l:chunk_num += 1
        endfor

        call setline(l:line_idx + l:chunk_num + 4, g:vimgmt_comment_pad . '')
        let l:line_idx += l:chunk_num + 5
    endfor

    " Store issue number for interacting with the issue (commenting, closing,
    " etc)
    let g:current_issue = a:contents['number']

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
    execute "file " . fnameescape(g:buf_vimgmt)
    setlocal bufhidden=hide noswapfile wrap

    let l:line_idx = SetHeader()
    let s:results_line = l:line_idx
    let b:issue_lookup = {}

    " Write issue details to buffer
    for item in a:results
        " Start index begins one line before content is written to allow
        " selecting an issue starting at the '- - - -' separator
        let start_idx = l:line_idx - 1

        " Establish title and type of issue (PRs are 'issues' in GitHub)
        let l:item_name = (has_key(item, 'pull_request') ? '(Pull Request) ' : '(Issue) ') . '#' . item['number'] . ': ' . item['title']
        call setline(l:line_idx, l:item_name)

        " Draw boundary between title and body
        call setline(l:line_idx + 1, g:vimgmt_spacer_small)
        let l:line_idx += 1

        let l:label_list = ParseLabels(item['labels'])
        call setline(l:line_idx + 1, 'Comments: ' . item['comments'])
        call setline(l:line_idx + 2, 'Labels:   ' . l:label_list)
        call setline(l:line_idx + 3, 'Updated:  ' . FormatTime(item['updated_at']))
        call setline(l:line_idx + 4, '')
        call setline(l:line_idx + 5, g:vimgmt_spacer)
        call setline(l:line_idx + 6, '')

        " Store issue number and title to use for viewing issue details later
        while start_idx <= l:line_idx + 5
            let b:issue_lookup[start_idx] = {'number': item['number'], 'title': item['title'], 'is_pr': has_key(item, 'pull_request')}
            let start_idx += 1
        endwhile

        " Offset index to account for the previous lines of issue detail
        let l:line_idx += 6
    endfor

    " Set up the ability to hit Enter on any issue section to open an issue
    " buffer
    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue(b:issue_lookup[getcurpos()[1]]['number'], b:issue_lookup[getcurpos()[1]]['is_pr'])<cr>

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
function! InsertBodyText(body, start_idx) abort
    let l:chunk_num = 0
    for chunk in split(a:body, '\n')
        let chunk = substitute(chunk, '\"', '', 'ge')
        call setline(l:chunk_num + a:start_idx, chunk)
        let l:chunk_num += 1
    endfor

    return l:chunk_num
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

" Resets the Vimgmt script dictionary to a clean state.
function! ResetDict() abort
    let g:vimgmt_dict = {'token_pw': g:vimgmt_dict.token_pw}
endfunction
