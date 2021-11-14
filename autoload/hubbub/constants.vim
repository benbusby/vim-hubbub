" =========================================================================
" File:    autoload/hubbub/constants.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: Constants used in the hubbub plugin.
" =========================================================================
scriptencoding utf-8

function! hubbub#constants#Constants() abort
    let emojis = !exists('g:hubbub_emojis') || g:hubbub_emojis
    let constants = {
        \'buffers': {
            \'issue':      '/dev/null/issue.hubbub.diff',
            \'issue_list': '/dev/null/issue_list.hubbub',
            \'comment':    '/dev/null/comment.hubbub',
            \'new_issue':  '/dev/null/new_issue.hubbub',
            \'new_req':    '/dev/null/new_req.hubbub',
            \'labels':     '/dev/null/labels.hubbub',
            \'edit':       '/dev/null/edit.hubbub',
            \'review':     '/dev/null/review.hubbub.diff'
        \},
        \'local_files': {
            \'github': g:hubbub_dir . '/.github.hubbub',
            \'gitlab': g:hubbub_dir . '/.gitlab.hubbub',
            \'home':   g:hubbub_dir . '/.view_all.hubbub',
            \'issue':  g:hubbub_dir . '/.view.hubbub',
            \'labels': g:hubbub_dir . '/.view_labels.hubbub',
            \'review': g:hubbub_dir . '/.review.hubbub'
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
            \'star': '★ '
        \},
        \'merge_methods': ['merge', 'rebase', 'squash'],
        \'multiline_keys': [
            \'start_line',
            \'line',
            \'start_side',
            \'side',
            \'body',
            \'path'
        \],
        \'singleline_keys': [
            \'position',
            \'body',
            \'path'
        \]
    \}

    " Track buffers that should be considered "primary", or take precedence
    " over existing buffers in the view
    let constants['primary_bufs'] = [
        \constants.buffers.issue, constants.buffers.issue_list
    \]

    return constants
endfunction
