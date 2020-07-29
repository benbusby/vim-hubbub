" ============================================================================
" File:        vissues.vim
" Description: Lists, and allows interactions with, issues for the git repo
" Author:      Ben Busby <contact@benbusby.com>
" Licence:     MIT
" Website:     https://benbusby.com/vissues/
" Version:     1.0
" ============================================================================

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

" =====================
" Vissues Commands
" =====================

function! vissues#VissuesOpen()
    call inputsave()
    let w:token_password = inputsecret("Enter token password: ")
    call inputrestore()
    call MakeVissuesBuffer(IssuesQuery())
endfunction

function! vissues#VissuesBack()
    b /tmp/vissues.tmp
    bw! /tmp/issue.tmp
endfunction

function! vissues#VissuesExit()
    if bufexists(bufnr("/tmp/vissues.tmp")) > 0
        bw! /tmp/vissues.tmp
    endif

    if bufexists(bufnr("/tmp/issue.tmp")) > 0
        bw! /tmp/issue.tmp
    endif
endfunction

" =====================
" External Script Calls
" =====================

function! IssuesQuery()
    let result = json_decode(system(s:dir . "/scripts/vissues.sh " . w:token_password . " view"))
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
function! MakeVissuesBuffer(results)
    vnew
    file /tmp/vissues.tmp
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
            let label_color = '#' . label['color']

            " Use colors provided by json to color the tag text
            exe 'hi ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' guifg=' . label_color
            exe 'syn match ' . substitute(label['name'], "[^a-zA-Z]", "", "g") . ' /' . label_name . '/'

            " Append a comma if there is more than one tag
            if label_list =~ '[^\s]'
                let label_list = label_list . ', '
            endif

            let label_list = label_list . label_name
        endfor
        call setline(line_idx + 2, label_list)
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

