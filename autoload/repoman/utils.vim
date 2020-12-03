" ============================================================================
" File:    autoload/repoman/utils.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: A collection of various syntax, file, and git related
" operations.
" ============================================================================
scriptencoding utf-8

function! repoman#utils#Decorations() abort
    let decorations = {
        \'spacer': repeat('─ ', min([27, winwidth(0)])),
        \'spacer_small': repeat('─', min([33, winwidth(0)])),
        \'comment_header_start': '┌' . repeat('─', min([52, winwidth(0)]) - 1) . '┐',
        \'comment_header_end': '└' . repeat('─', min([52, winwidth(0)]) - 1) . '┘',
        \'comment': '    ',
        \'new_review_comment': '├' . repeat('─', min([51, winwidth(0)])),
        \'review_comment': '│ ',
    \}

    return decorations
endfunction

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

function! repoman#utils#LoadSyntaxColoring() abort
    for type in s:syntax_types
        call TextEnableCodeSnip(type, '```' . type, '```', 'SpecialComment')
    endfor

    " Color UI decorations as comments
    let l:spacer_color = '#aaaaaa'
    let l:comment_colors = filter(split(execute(':hi Comment')), 'v:val =~? "guifg="')
    if len(l:comment_colors) > 0
        let l:spacer_color = l:comment_colors[0]
    endif

    exe 'hi repoman_spacer gui=bold guifg=' . substitute(l:spacer_color, 'guifg=', '', 'ge')
    for val in values(repoman#utils#Decorations())
        exe 'syn match repoman_spacer /' . val . '/'
    endfor

    " Highlight stars as yellow
    exe 'hi star_color guifg=#ffff00'
    exe 'syn match star_color /★/'
endfunction

" ============================================================================
" Local File Read/Write
" ============================================================================
let s:local_files = {
    \'github': g:repoman_dir . '/.github.repoman',
    \'gitlab': g:repoman_dir . '/.gitlab.repoman',
    \'home':   g:repoman_dir . '/.view_all.repoman',
    \'issue':  g:repoman_dir . '/.view.repoman',
    \'labels': g:repoman_dir . '/.view_labels.repoman'
\}

function! repoman#utils#GetCacheFile(name) abort
    return s:local_files[a:name]
endfunction

function! repoman#utils#SanitizeText(text, ...) abort
    let l:replacements = [[system('echo ""'), '\\n'], ["'", "'\"'\"'"]]
    if a:0 > 0 && a:1
        let l:replacements += ['"', '\\"']
    endif
    let l:text = a:text

    for item in l:replacements
        let l:text = substitute(l:text, item[0], item[1], 'ge')
    endfor
    return l:text
endfunction

function! repoman#utils#ReadFile(name, password) abort
    return json_decode(repoman#crypto#Decrypt(s:local_files[a:name], a:password))
endfunction

function! repoman#utils#ReadToken(password) abort
    return substitute(
        \repoman#crypto#Decrypt(s:local_files[repoman#utils#GetRepoHost()], a:password),
        \'[[:cntrl:]]', '', 'ge')
endfunction

function! repoman#utils#AddLocalComment(comment, number, password) abort
    " Update comments count for current issue
    let l:home_json = json_decode(repoman#crypto#Decrypt(s:local_files['home'], a:password))
    for issue in l:home_json
        if issue['number'] == a:number
            let issue['comments'] += 1
            break
        endif
    endfor
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:home_json)),
        \'home', a:password)

    " Update comments array with new comment
    let l:issue_json = json_decode(repoman#crypto#Decrypt(s:local_files['home'], a:password))
    call add(l:issue_json['comments'], a:comment)
    call repoman#crypto#Encrypt(
        \repoman#utils#SanitizeText(json_encode(l:issue_json)),
        \'issue', a:password)
endfunction

" ============================================================================
" Git Specific Functions
" ============================================================================
let s:github_prefixes = ['https://github.com/', 'git@github.com:']
let s:gitlab_prefixes = ['https://gitlab.com/', 'git@gitlab.com:']

function! repoman#utils#GetRepoPath() abort
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

function! repoman#utils#GetRepoHost() abort
    let l:full_path = substitute(system('git ls-remote --get-url'), '[[:cntrl:]]', '', 'ge')

    for prefix in s:gitlab_prefixes
        if match(l:full_path, prefix) == 0
            return 'gitlab'
        endif
    endfor

    return 'github'
endfunction

function! repoman#utils#InGitRepo() abort
    return len(system('git -C . rev-parse')) == 0
endfunction

function! repoman#utils#GetBranchName() abort
    if repoman#utils#InGitRepo()
        let l:branch_name = system('git rev-parse --abbrev-ref HEAD')
        return substitute(l:branch_name, '[[:cntrl:]]', '', 'ge')
    endif

    return ''
endfunction
