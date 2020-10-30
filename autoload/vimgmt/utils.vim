let s:end_str = '```'
let s:syntax_types = [
            \'c', 'cpp', 'python', 'javascript', 'vim', 'ruby', 'bash', 'sh'
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

function! vimgmt#utils#LoadSyntaxColoring() abort
    for type in s:syntax_types
        call TextEnableCodeSnip(type, '```' . type, '```', 'SpecialComment')
    endfor
endfunction

