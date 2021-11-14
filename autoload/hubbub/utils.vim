" ============================================================================
" File:    autoload/hubbub/utils.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A collection of various syntax, file, and git related
" operations.
" ============================================================================
scriptencoding utf-8
let s:constants = function('hubbub#constants#Constants')()

" ============================================================================
" Syntax
" ============================================================================
let s:syntax_types = [
    \'c', 'cpp', 'python', 'javascript', 'vim', 'ruby', 'sh', 'rust',
    \'clojure', 'scala', 'java'
\]

" From https://vim.fandom.com/wiki/Different_syntax_highlighting_within_regions_of_a_file
function! TextEnableCodeSnip(filetype, start, end, textSnipHl) abort
    let ft = toupper(a:filetype)
    let group = 'textGroup' . ft
    if exists('b:current_syntax')
        let s:current_syntax = b:current_syntax
        " Remove current syntax definition, as some syntax files (e.g. cpp.vim)
        " do nothing if b:current_syntax is defined.
        unlet b:current_syntax
    endif
    execute 'syntax include @' . group . ' syntax/' . a:filetype . '.vim'
    try
        execute 'syntax include @' . group . ' after/syntax/' . a:filetype . '.vim'
    catch
    endtry
    if exists('s:current_syntax')
        let b:current_syntax = s:current_syntax
    else
        unlet b:current_syntax
    endif
    execute 'syntax region textSnip' . ft . '
        \ matchgroup='.a:textSnipHl.'
        \ keepend
        \ start="'.a:start.'" end="'.a:end.'"
        \ contains=@'.group
endfunction

function! hubbub#utils#LoadSyntaxColoring(strings) abort
    " Color code blocks
    for type in s:syntax_types
        call TextEnableCodeSnip(type, '```' . type, '```', 'SpecialComment')
    endfor

    " Color the UI
    let l:deco = hubbub#decorations#Decorations()

    exe 'hi hubbub_spacer gui=bold ' . l:deco.colors.ui
    for val in values(hubbub#decorations#Decorations().ui)
        exe 'syn match hubbub_spacer /' . val . '/'
    endfor

    exe 'hi hubbub_issues ' . l:deco.colors.issue
    exe 'hi hubbub_prs ' . l:deco.colors.pr
    exe 'hi star_color ' . l:deco.colors.star
    exe 'syn match star_color /★/'
    exe 'syn match hubbub_issues /\[' . a:strings.issue . '\]/'
    exe 'syn match hubbub_prs /\[' . a:strings.pr . '\]/'
endfunction

" ============================================================================
" Local File Read/Write
" ============================================================================
function! hubbub#utils#SanitizeText(text, ...) abort
    let l:replacements = [[system('echo ""'), '\\n'], ["'", "'\"'\"'"]]
    let l:result = a:text
    if a:0 > 0 && a:1
        let l:result = substitute(l:result, '"', '\\"', 'ge')
    endif

    for item in l:replacements
        let l:result = substitute(l:result, item[0], item[1], 'ge')
    endfor

    return l:result
endfunction

function! hubbub#utils#ReadFile(name, password) abort
    return json_decode(hubbub#crypto#Decrypt(s:constants.local_files[a:name], a:password))
endfunction

function! hubbub#utils#ReadToken(password) abort
    if empty(a:password)
        return substitute(
            \system('cat ' . s:constants.local_files[hubbub#utils#GetRepoHost()]),
            \'[[:cntrl:]]', '', 'ge')
    endif

    return substitute(
        \hubbub#crypto#Decrypt(s:constants.local_files[hubbub#utils#GetRepoHost()], a:password),
        \'[[:cntrl:]]', '', 'ge')
endfunction

function! hubbub#utils#AddLocalComment(comment, number, password) abort
    " Update comments count for current issue
    let l:home_json = json_decode(hubbub#crypto#Decrypt(s:constants.local_files.home, a:password))
    for issue in l:home_json
        if issue['number'] == a:number
            let issue['comments'] += 1
            break
        endif
    endfor
    call hubbub#crypto#Encrypt(
        \hubbub#utils#SanitizeText(json_encode(l:home_json)),
        \'home', a:password)

    " Update comments array with new comment
    let l:issue_json = json_decode(hubbub#crypto#Decrypt(s:constants.local_files.home, a:password))
    call add(l:issue_json['comments'], a:comment)
    call hubbub#crypto#Encrypt(
        \hubbub#utils#SanitizeText(json_encode(l:issue_json)),
        \'issue', a:password)
endfunction

" ============================================================================
" Git Specific Functions
" ============================================================================
let s:github_prefixes = ['https://github.com/', 'git@github.com:']
let s:gitlab_prefixes = ['https://gitlab.com/', 'git@gitlab.com:']

function! hubbub#utils#GetRepoPath() abort
    let l:prefixes = s:github_prefixes + s:gitlab_prefixes
    let l:repo_path = substitute(system('git ls-remote --get-url'), '[[:cntrl:]]', '', 'ge')

    if l:repo_path =~? 'fatal:'
        return ''
    endif

    for prefix in l:prefixes
        let l:repo_path = substitute(l:repo_path, prefix, '', 'ge')
    endfor

    if l:repo_path[len(l:repo_path) - 4:] ==# '.git'
        return l:repo_path[:len(l:repo_path) - 5]
    endif

    return l:repo_path
endfunction

function! hubbub#utils#GetRepoHost() abort
    let l:full_path = substitute(system('git ls-remote --get-url'), '[[:cntrl:]]', '', 'ge')

    for prefix in s:gitlab_prefixes
        if match(l:full_path, prefix) == 0
            return 'gitlab'
        endif
    endfor

    return 'github'
endfunction

function! hubbub#utils#InGitRepo() abort
    return len(system('git -C . rev-parse')) == 0
endfunction

function! hubbub#utils#GetBranchName() abort
    if hubbub#utils#InGitRepo()
        let l:branch_name = system('git rev-parse --abbrev-ref HEAD')
        return substitute(l:branch_name, '[[:cntrl:]]', '', 'ge')
    endif

    return ''
endfunction

function! hubbub#utils#GetDiffPosition(start, end) abort
    let l:start_right = a:start.line_nr_right > 0
    let l:start_left = a:start.line_nr_left > 0 && !l:start_right

    let l:end_right = a:end.line_nr_right > 0
    let l:end_left = a:end.line_nr_left > 0 && !l:end_right

    return {
        \'start_line': l:start_left ? a:start.line_nr_left : a:start.line_nr_right,
        \'line': l:end_left ? a:end.line_nr_left : a:end.line_nr_right,
        \'start_side': l:start_left ? 'LEFT' : 'RIGHT',
        \'side': l:end_left ? 'LEFT' : 'RIGHT'
    \}
endfunction

function! hubbub#utils#github_NoPass() abort
    return filereadable(g:hubbub_dir . '/.github.hubbub.nopass')
endfunction

function! hubbub#utils#gitlab_NoPass() abort
    return filereadable(g:hubbub_dir . '/.gitlab.hubbub.nopass')
endfunction
