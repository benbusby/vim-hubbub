" ============================================================================
" File:        vimgmt.vim
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

" Formatting constants
let g:vimgmt_spacer = '░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░'
let g:vimgmt_spacer_small = '─────────────────────────────────'
let g:vimgmt_comment_pad = '    '

" Issue variables
let g:current_issue = -1
let g:in_pr = 0

let g:token_password = ""

set ff=unix

" ==============================================================
" Commands
" ==============================================================

" Navigation ---------------------------------------------------
function! vimgmt#Vimgmt()
    if len(g:token_password) > 0
        " User is already using Vimgmt, treat as a refresh
        if bufexists(bufnr("/tmp/vimgmt.tmp")) > 0
            bw! /tmp/vimgmt.tmp
        endif

        if bufexists(bufnr("/tmp/issue.tmp")) > 0
            bw! /tmp/issue.tmp
        endif
    else
        " New session, prompt for token pw
        call inputsave()
        let g:token_password = inputsecret("Enter token password: ")
        call inputrestore()
    endif
    call MakeBuffer(HomePageQuery())
endfunction

function! vimgmt#VimgmtBack()
    b /tmp/vimgmt.tmp
    bw! /tmp/issue.tmp

    " Reset issue number
    let g:current_issue = -1
    let g:in_pr = 0
endfunction

" Interaction --------------------------------------------------
function! vimgmt#VimgmtComment()
    if g:current_issue == -1
        echo "Error: Must be on an issue/PR page to comment!"
        return
    endif

    set cmdheight=4
    let comment = input("Type comment here (press enter to submit): ")
    call inputrestore()
    echo ""
    set cmdheight=1

    call PostComment(comment)

    bw! /tmp/issue.tmp
    call ViewIssue(g:current_issue, g:in_pr)
endfunction

" ==============================================================
" External Script Calls
" ==============================================================

function! HomePageQuery()
    let result = json_decode(system(s:dir . "/scripts/vimgmt.sh " . g:token_password . " view"))
    return result
endfunction

function! IssueQuery(number)
    let result = json_decode(system(s:dir . "/scripts/vimgmt_issue.sh " . g:token_password . " view " . a:number))
    return result
endfunction

function! PostComment(comment)
    if g:in_pr
        echo "TODO"
    else
        call system(s:dir . "/scripts/vimgmt_issue.sh " . g:token_password . " comment " . g:current_issue . " \"" . a:comment . "\"")
    endif
endfunction

" ==============================================================
" Interactions
" ==============================================================

" Open issue based on the provided issue number
function! ViewIssue(issue_number, in_pr)
    let g:in_pr = a:in_pr
    set cmdheight=4
    echo "Loading..."

    if a:in_pr
        " TODO
        echo "TODO"
    else
        call MakeIssueBuffer(IssueQuery(a:issue_number))
    endif
endfunction

" ==============================================================
" Buffer Functions
" ==============================================================

" Write out header to buffer
function! MakeHeader()
    let line_idx = 1
    for line in readfile(s:dir . '/assets/header.txt')
        call setline(line_idx, line)
        let line_idx += 1
    endfor

    return line_idx
endfunction

" Create issue/(pull|merge) request buffer
function! MakeIssueBuffer(contents)
    if winwidth(0) > winheight(0) * 2
        vnew  " Window is wide enough for vertical split
    else
        enew   " Window is too narrow, use new buffer
    endif

    " Clear buffer if it already exists
    if bufexists(bufnr("/tmp/issue.tmp")) > 0
        bw! /tmp/issue.tmp
    endif
    file /tmp/issue.tmp
    set hidden ignorecase
    setlocal bufhidden=hide noswapfile wrap

    let line_idx = MakeHeader()
    let s:results_line = line_idx

    " Write issue and comments to buffer
    call setline(line_idx, '(Issue) #' . a:contents['number'] . ': ' . a:contents['title'])
    call setline(line_idx + 1, g:vimgmt_spacer_small)

    " Split body on line breaks for proper formatting
    let break_num = InsertBodyText(a:contents['body'], line_idx + 2)

    call setline(line_idx + break_num + 2, g:vimgmt_spacer_small)
    call setline(line_idx + break_num + 3, 'Created: ' . FormatTime(a:contents['created_at']))
    call setline(line_idx + break_num + 4, 'Updated: ' . FormatTime(a:contents['updated_at']))
    call setline(line_idx + break_num + 5, 'Author:  ' . a:contents['user']['login'])
    call setline(line_idx + break_num + 6, g:vimgmt_spacer_small)
    call setline(line_idx + break_num + 7, '')
    call setline(line_idx + break_num + 8, g:vimgmt_comment_pad . 'Comments (' . len(a:contents['comments']) . ')')

    let line_idx += break_num + 9

    for comment in a:contents['comments']
        let commenter = comment['user']['login']
        if has_key(comment, 'author_association') && comment['author_association'] != 'none'
            let commenter = '(' . tolower(comment['author_association']) . ') ' . commenter
        endif
        call setline(line_idx, g:vimgmt_comment_pad . g:vimgmt_spacer)
        call setline(line_idx + 1, g:vimgmt_comment_pad . FormatTime(comment['created_at']))
        call setline(line_idx + 2, g:vimgmt_comment_pad . commenter . ':')
        call setline(line_idx + 3, g:vimgmt_comment_pad . '')

        " Split comment body on line breaks for proper formatting
        let break_num = 0
        for comment_line in split(comment['body'], '\n')
            call setline(line_idx + break_num + 4, g:vimgmt_comment_pad . comment_line)
            let break_num += 1
        endfor

        call setline(line_idx + break_num + 4, g:vimgmt_comment_pad . '')
        let line_idx += break_num + 5
    endfor

    " Store issue number for interacting with the issue (commenting, closing,
    " etc)
    let g:current_issue = a:contents['number']

    call CloseBuffer()
endfunction


function! MakeBuffer(results)
    " Creates a buffer for the list of issues or PRs.

    if line('$') == 1 && getline(1) == ''
        enew  " Use whole window for results
    elseif winwidth(0) > winheight(0) * 2
        vnew  " Window is wide enough for vertical split
    else
        new   " Window is too narrow, use horizontal split
    endif
    file /tmp/vimgmt.tmp
    setlocal bufhidden=hide noswapfile wrap

    let line_idx = MakeHeader()
    let s:results_line = line_idx
    let b:issue_lookup = {}

    " Write issue details to buffer
    for item in a:results
        let start_idx = line_idx
        " Establish title and type of issue (PRs are 'issues' in GitHub)
        let item_name = (has_key(item, 'pull_request') ? '(Pull Request) ' : '(Issue) ') . '#' . item['number'] . ': ' . item['title']
        call setline(line_idx, item_name)

        " Draw boundary between title and body
        call setline(line_idx + 1, g:vimgmt_spacer_small)
        let line_idx += 1

        let label_list = ParseLabels(item['labels'])
        call setline(line_idx + 1, 'Comments: ' . item['comments'])
        call setline(line_idx + 2, 'Labels:   ' . label_list)
        call setline(line_idx + 3, 'Updated:  ' . FormatTime(item['updated_at']))
        call setline(line_idx + 4, '')
        call setline(line_idx + 5, g:vimgmt_spacer)
        call setline(line_idx + 6, '')

        " Store issue number and title to use for viewing issue details later
        while start_idx <= line_idx + 6
            let b:issue_lookup[start_idx] = {'number': item['number'], 'title': item['title'], 'is_pr': has_key(item, 'pull_request')}
            let start_idx += 1
        endwhile

        " Offset index to account for the previous lines of issue detail
        let line_idx += 7
    endfor

    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue(b:issue_lookup[getcurpos()[1]]['number'], b:issue_lookup[getcurpos()[1]]['is_pr'])<cr>

    call CloseBuffer()
endfunction

" ==============================================================
" Utils
" ==============================================================

function! ParseLabels(labels)
    " Parses labels from an array into a comma separated list, as well as sets
    " highlighting rules for each label (if a color is returned in the
    " response).
    "
    " Returns a comma separated list of label.

    let label_list = ""

    for label in a:labels
        let label_name = '|' . label['name'] . '|'

        " Use colors for labels if provided by the response
        if has_key(label, 'color')
            let label_color = '#' . label['color']

            exe 'hi ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' gui=bold guifg=' . label_color
            exe 'syn match ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' /' . label_name . '/'
        endif

        " Append a comma if there is more than one tag
        if label_list =~ '[^\s]'
            let label_list = label_list . ', '
        endif

        let label_list = label_list . label_name
    endfor

    return label_list
endfunction

function! InsertBodyText(body, start_idx)
    " Insert segments of issue/request body, inserting line breaks as
    " needed.
    "
    " Returns a cursor position for the next line draw

    let break_num = 0
    for chunk in split(a:body, '\n')
        call setline(break_num + a:start_idx, chunk)
        let break_num += 1
    endfor

    return break_num
endfunction

function! FormatTime(time_str)
    " Removes alphabetical characters from time string
    "
    " Returns an easily readable time str (ex: 2020-10-07 15:10:03)

    return substitute(a:time_str, "[a-zA-Z]", " ", "g")
endfunction

function! CloseBuffer()
    " Filters out ^M characters, brings the cursor to the top of the
    " buffer, and sets the buffer as not modifiable

    set cmdheight=4
    silent %s///ge
    normal gg
    setlocal nomodifiable
    set cmdheight=1 hidden bt=nofile splitright
endfunction
