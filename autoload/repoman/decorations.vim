" ============================================================================
" File:    autoload/repoman/decorations.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: UI spacers/colors/etc
" ============================================================================
scriptencoding utf-8

function! GetColor(type) abort
    let l:color_fg = '"ctermfg="'
    if has('termguicolors')
        let l:color_fg = '"guifg="'
    endif

    let l:color = filter(
        \split(execute(':hi ' . a:type)),
        \'v:val =~? ' . l:color_fg)

    if len(l:color) > 0
        return l:color[0]
    endif

    return 'none'
endfunction

function! repoman#decorations#Decorations() abort
    let decorations = {
        \'fg_prop': has('termguicolors') ? 'guifg=' : 'ctermfg=',
        \'ui': {
            \'spacer': repeat('°°', min([27, winwidth(0)])),
            \'spacer_small': repeat('─', min([33, winwidth(0)])),
            \'comment_header_start': '╔' . repeat('═', min([52, winwidth(0)]) - 1) . '╗',
            \'comment_header_end': '╚' . repeat('═', min([52, winwidth(0)]) - 1) . '╝',
            \'comment': '    ',
            \'new_review_comment': '├' . repeat('─', min([51, winwidth(0)])),
            \'review_comment': '│···· ',
            \'review_reply': '    ├' . repeat('─', min([47, winwidth(0)])),
            \'end_review_comment': '└' . repeat('─', min([51, winwidth(0)])),
            \'end_first_comment': '└───┬' . repeat('─', min([47, winwidth(0)])),
            \'end_review_reply': '    └' . repeat('─', min([47, winwidth(0)])),
            \'end_first_reply': '    ├' . repeat('─', min([47, winwidth(0)])),
            \'buffer_comment': '▓▓▓▓▓ '
        \},
        \'colors': {
            \'ui': GetColor('Comment'),
            \'issue': GetColor('Number'),
            \'pr': GetColor('Constant'),
            \'star': GetColor('Type')
        \}
    \}

    return decorations
endfunction
