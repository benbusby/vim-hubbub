" =========================================================================
" File:    autoload/repoman/constants.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: Constants used in the repoman plugin.
" =========================================================================
scriptencoding utf-8

let lang_dict = json_decode(join(readfile(g:repoman_dir . '/assets/strings.json')))
let s:strings = lang_dict[(exists('g:repoman_language') ? g:repoman_language : 'en')]

function! repoman#constants#Constants() abort
    let emojis = !exists('g:repoman_noemoji') || !g:repoman_noemoji
    let constants = {
        \'buffers': {
            \'issue':      '/dev/null/issue.repoman.diff',
            \'issue_list': '/dev/null/issue_list.repoman',
            \'comment':    '/dev/null/comment.repoman',
            \'new_issue':  '/dev/null/new_issue.repoman',
            \'new_req':    '/dev/null/new_req.repoman',
            \'labels':     '/dev/null/labels.repoman',
            \'edit':       '/dev/null/edit.repoman'
        \},
        \'reactions': {
            \'+1': emojis ? '👍 x' : '+',
            \'-1': emojis ? '👎 x' : '-',
            \'laugh': emojis ? '😂 x' : 'laugh:',
            \'eyes': emojis ? '👀 x' : 'eyes:',
            \'hooray': emojis ? '🎉 x' : 'hooray:',
            \'confused': emojis ? '😕 x' : 'confused:',
            \'heart': emojis ? '❤️ x' : 'heart:',
            \'rocket': emojis ? '🚀 x' : 'rocket:'
        \},
        \'symbols': {
            \'star': emojis ? '★ ' : s:strings.stars
        \},
        \'merge_methods': ['merge', 'rebase', 'squash']
    \}

    " Track buffers that should be considered "primary", or take precedence
    " over existing buffers in the view
    let constants['primary_bufs'] = [
        \constants.buffers.issue, constants.buffers.issue_list
    \]

    return constants
endfunction
