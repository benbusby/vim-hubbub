" ============================================================================
" File:        vimgmt.vim
" Description: Lists (and allows interactions with) issues for the git repo
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

" =====================
" Commands
" =====================

function! vimgmt#Vimgmt()
    call inputsave()
    let w:token_password = inputsecret("Enter token password: ")
    call inputrestore()
    call MakeBuffer(IssuesQuery())
endfunction

function! vimgmt#VimgmtBack()
    b /tmp/vimgmt.tmp
    bw! /tmp/vimgmt.tmp
endfunction

function! vimgmt#VimgmtExit()
    if bufexists(bufnr("/tmp/vimgmt.tmp")) > 0
        bw! /tmp/vimgmt.tmp
    endif

    if bufexists(bufnr("/tmp/issue.tmp")) > 0
        bw! /tmp/issue.tmp
    endif
endfunction

" =====================
" External Script Calls
" =====================

function! IssuesQuery()
    let result = json_decode(system(s:dir . "/scripts/vimgmt.sh " . w:token_password . " view"))
    return result
endfunction

" =====================
" Interactions
" =====================

" Open issue based on which line the vim cursor is on
function! ViewIssue()
    let issue_data = b:issue_lookup[getcurpos()[1]]
    echo issue_data
    " TODO
endfunction

" =====================
" Buffer Functions
" =====================

" Write out header to buffer
function! MakeHeader()
    let line_idx = 1
    for line in readfile(s:dir . '/assets/header.txt')
        call setline(line_idx, line)
        let line_idx += 1
    endfor
    return line_idx
endfunction

" Create buffer for the list of issues
function! MakeBuffer(results)
    vnew
    file /tmp/vimgmt.tmp
    set hidden
    setlocal bufhidden=hide noswapfile wrap

    let line_idx = MakeHeader()
    let s:results_line = line_idx
    let b:issue_lookup = {}

    for item in a:results
        " Write issue details to buffer
        " #<Number> <Title>
        " <Description>
        " <Tag List>
        call setline(line_idx,     '#' . item['number'] . ': ' . item['title'])
        call setline(line_idx + 1, item['body'])

        let label_list = ""
        for label in item['labels']
            let label_name = '|' . label['name'] . '|'

            " Use colors for labels if provided by the response
            if has_key(label, 'color')
                let label_color = '#' . label['color']

                exe 'hi ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' guifg=' . label_color
                exe 'syn match ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' /' . label_name . '/'
            endif

            " Append a comma if there is more than one tag
            if label_list =~ '[^\s]'
                let label_list = label_list . ', '
            endif

            let label_list = label_list . label_name
        endfor
        call setline(line_idx + 2, 'Labels: ' . label_list)
        call setline(line_idx + 3, '=========================================')

        let idx = line_idx

        " Store issue number and title to use for viewing issue details later
        while idx <= line_idx + 3
            let b:issue_lookup[idx] = {'number': item['number'], 'title': item['title']}
            let idx += 1
        endwhile

        let line_idx += 4 " Offset index to account for the previous lines of issue detail
    endfor

    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue()<cr>

    setlocal nomodifiable

endfunction

