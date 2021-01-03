" =========================================================================
" File:    autoload/repoman/constants.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: Constants used in the repoman plugin.
" =========================================================================
scriptencoding utf-8

function! repoman#constants#Constants() abort
    let emojis = !exists('g:repoman_emojis') || g:repoman_emojis
    let constants = {
        \'buffers': {
            \'issue':      '/dev/null/issue.repoman.diff',
            \'issue_list': '/dev/null/issue_list.repoman',
            \'comment':    '/dev/null/comment.repoman',
            \'new_issue':  '/dev/null/new_issue.repoman',
            \'new_req':    '/dev/null/new_req.repoman',
            \'labels':     '/dev/null/labels.repoman',
            \'edit':       '/dev/null/edit.repoman',
            \'review':     '/dev/null/review.repoman.diff'
        \},
        \'local_files': {
            \'github': g:repoman_dir . '/.github.repoman',
            \'gitlab': g:repoman_dir . '/.gitlab.repoman',
            \'home':   g:repoman_dir . '/.view_all.repoman',
            \'issue':  g:repoman_dir . '/.view.repoman',
            \'labels': g:repoman_dir . '/.view_labels.repoman',
            \'review': g:repoman_dir . '/.review.repoman'
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
