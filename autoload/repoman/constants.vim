function! repoman#constants#Constants() abort
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
            \'+1': '👍 ',
            \'-1': '👎 ',
            \'laugh': '😂 ',
            \'eyes': '👀 ',
            \'hooray': '🎉 ',
            \'confused': '😕 ',
            \'heart': '❤️ ',
            \'rocket': '🚀 '
        \}
    \}

    return constants
endfunction
