" ============================================================================
" Syntax
" ============================================================================
let s:end_str = '```'
let s:syntax_types = [
            \'c', 'cpp', 'python', 'javascript', 'vim', 'ruby', 'sh'
            \]

" From https://vim.fandom.com/wiki/Different_syntax_highlighting_within_regions_of_a_file
function! TextEnableCodeSnip(filetype, start, end, textSnipHl) abort
    let ft=toupper(a:filetype)
    let group='textGroup'.ft
    if exists('b:current_syntax')
        let s:current_syntax=b:current_syntax
        " Remove current syntax definition, as some syntax files (e.g. cpp.vim)
        " do nothing if b:current_syntax is defined.
        unlet b:current_syntax
    endif
    execute 'syntax include @'.group.' syntax/'.a:filetype.'.vim'
    try
        execute 'syntax include @'.group.' after/syntax/'.a:filetype.'.vim'
    catch
    endtry
    if exists('s:current_syntax')
        let b:current_syntax=s:current_syntax
    else
        unlet b:current_syntax
    endif
    execute 'syntax region textSnip'.ft.'
                \ matchgroup='.a:textSnipHl.'
                \ keepend
                \ start="'.a:start.'" end="'.a:end.'"
                \ contains=@'.group
endfunction

function! repoman#utils#LoadSyntaxColoring() abort
    for type in s:syntax_types
        call TextEnableCodeSnip(type, '```' . type, '```', 'SpecialComment')
    endfor
endfunction

" ============================================================================
" Local File Read/Write
" ============================================================================
let s:encrypt_cmd = 'openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out '
let s:decrypt_cmd = 'openssl aes-256-cbc -d -a -pbkdf2 -in '
let s:local_files = {
    \'home':   g:repoman_dir . '/.view_all.repoman',
    \'issue':  g:repoman_dir . '/.view.repoman',
    \'labels': g:repoman_dir . '/.view_labels.repoman'
    \}

function! repoman#utils#ReadFile(name, password) abort
    return json_decode(system(
        \s:decrypt_cmd . s:local_files[a:name] . ' -k ' . a:password))
endfunction

function! repoman#utils#WriteFile(contents, name, password) abort
    call system('echo "' . a:contents . '" | ' .
        \s:encrypt_cmd . s:local_files[a:name] . ' -k ' . a:password)
endfunction

function! repoman#utils#AddLocalComment(comment, number, password) abort
    " Update comments count for current issue
    let l:home_json = json_decode(system(
        \s:decrypt_cmd . s:local_files['home'] . ' -k ' . a:password))
    for issue in l:home_json
        if issue['number'] == a:number
            let issue['comments'] += 1
            break
        endif
    endfor
    call repoman#utils#WriteFile(
        \substitute(json_encode(l:home_json), '"', '\\"', 'ge'), 'home', a:password)

    " Update comments array with new comment
    let l:issue_json = json_decode(system(
        \s:decrypt_cmd . s:local_files['issue'] . ' -k ' . a:password))
    call add(l:issue_json['comments'], a:comment)
    call repoman#utils#WriteFile(
        \substitute(json_encode(l:issue_json), '"', '\\"', 'ge'),
        \'issue', a:password)
endfunction
