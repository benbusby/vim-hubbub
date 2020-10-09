" ============================================================================
" File:        vimgmt.vim
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

let s:dir = '/' . join(split(expand('<sfile>:p:h'), '/')[:-2], '/')

" Formatting constants
let g:vimgmt_spacer = '======================================================='
let g:vimgmt_spacer_small = '-------------------------------'
let g:vimgmt_comment_pad = '    '

" Issue variables
let g:current_issue = -1
let g:in_pr = 0

set ff=unix

" ==============================================================
" Commands
" ==============================================================

" Navigation ---------------------------------------------------
function! vimgmt#Vimgmt()
    call inputsave()
    let g:token_password = inputsecret("Enter token password: ")
    call inputrestore()
    call MakeBuffer(HomePageQuery())
endfunction

function! vimgmt#VimgmtBack()
    b /tmp/vimgmt.tmp
    bw! /tmp/issue.tmp

    " Reset issue number
    let g:current_issue = -1
    let g:in_pr = 0
endfunction

function! vimgmt#VimgmtExit()
    if bufexists(bufnr("/tmp/vimgmt.tmp")) > 0
        bw! /tmp/vimgmt.tmp
    endif

    if bufexists(bufnr("/tmp/issue.tmp")) > 0
        bw! /tmp/issue.tmp
    endif
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
    if a:in_pr
        " TODO
        echo "TODO"
        let g:in_pr = a:is_pr
    else
        set cmdheight=2
        echo "Fetching issue, please wait..."
        call MakeIssueBuffer(IssueQuery(a:issue_number))
        echo ""
        set cmdheight=1
    endif

    normal gg
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
    enew
    file /tmp/issue.tmp
    set hidden ignorecase
    setlocal bufhidden=hide noswapfile wrap

    let line_idx = MakeHeader()
    let s:results_line = line_idx

    " Write issue and comments to buffer
    call setline(line_idx, '(Issue) #' . a:contents['number'] . ': ' . a:contents['title'])
    call setline(line_idx + 1, g:vimgmt_spacer_small)

    " Split body on line breaks for proper formatting
    let break_num = 0
    for chunk in split(a:contents['body'], '\n')
        call setline(line_idx + break_num + 2, chunk)
        let break_num += 1
    endfor

    " Decrement break_num to return cursor to next line
    let break_num -= 1

    call setline(line_idx + break_num + 3, g:vimgmt_spacer_small)
    call setline(line_idx + break_num + 4, 'Created: ' . a:contents['created_at'])
    call setline(line_idx + break_num + 5, 'Updated: ' . a:contents['updated_at'])
    call setline(line_idx + break_num + 6, 'Author:  ' . a:contents['user']['login'])
    call setline(line_idx + break_num + 7, g:vimgmt_spacer_small)
    call setline(line_idx + break_num + 8, '')
    call setline(line_idx + break_num + 9, g:vimgmt_comment_pad . 'Comments (' . len(a:contents['comments']) . ')')

    let line_idx += break_num + 10

    for comment in a:contents['comments']
        let commenter = comment['user']['login']
        if has_key(comment, 'author_association') && comment['author_association'] != 'none'
            let commenter = '(' . tolower(comment['author_association']) . ') ' . commenter
        endif
        call setline(line_idx, g:vimgmt_comment_pad . g:vimgmt_spacer)
        call setline(line_idx + 1, g:vimgmt_comment_pad . comment['created_at'])
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

    %s///ge
    call feedkeys('gg')
    setlocal nomodifiable
endfunction


" Create buffer for the list of issues
function! MakeBuffer(results)
    if line('$') == 1 && getline(1) == ''
        enew  " Use whole window for results
    elseif winwidth(0) > winheight(0) * 2
        vnew  " Window is wide enough for vertical split
    else
        new   " Window is too narrow, use horizontal split
    endif
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

        if has_key(item, 'pull_request')  " GitHub only
            call setline(line_idx, '(Pull Request) #' . item['number'] . ': ' . item['title'])
        else
            call setline(line_idx, '(Issue) #' . item['number'] . ': ' . item['title'])
        endif

        " Draw boundary between title and body
        call setline(line_idx + 1, g:vimgmt_spacer_small)
        let line_idx += 1

        " Split body on line breaks to properly format
        let break_num = 0
        for chunk in split(item['body'], '\n')
            call setline(line_idx + break_num + 1, chunk)
            let break_num += 1
        endfor

        " Draw boundary between body and info
        call setline(line_idx + break_num + 1, g:vimgmt_spacer_small)

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
        call setline(line_idx + break_num + 2, 'Labels: ' . label_list)
        call setline(line_idx + break_num + 3, 'Comments: ' . item['comments'])
        call setline(line_idx + break_num + 4, 'Created: ' . item['created_at'])
        call setline(line_idx + break_num + 5, 'Updated: ' . item['updated_at'])
        call setline(line_idx + break_num + 6, '')
        call setline(line_idx + break_num + 7, g:vimgmt_spacer)
        call setline(line_idx + break_num + 8, '')

        let idx = line_idx

        " Store issue number and title to use for viewing issue details later
        while idx <= line_idx + break_num + 8
            let b:issue_lookup[idx] = {'number': item['number'], 'title': item['title'], 'is_pr': has_key(item, 'pull_request')}
            let idx += 1
        endwhile

        " Offset index to account for the previous lines of issue detail
        let line_idx += break_num + 9
    endfor

    call cursor(s:results_line, 1)
    nnoremap <buffer> <silent> <CR> :call ViewIssue(b:issue_lookup[getcurpos()[1]]['number'], b:issue_lookup[getcurpos()[1]]['is_pr'])<cr>

    %s///ge
    normal gg
    setlocal nomodifiable
endfunction

