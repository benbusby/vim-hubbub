" ============================================================================
" File:    autoload/repoman/request.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" ============================================================================
function! repoman#request#Curl(...) abort
    let request = {'type': (a:0 > 0 ? a:1 : 'application/json')}

    function! request.Send(token, url, ...) abort
        let l:body = ''
        let l:method = ''

        if a:0 > 0
            let l:body = a:1
            let l:method = a:2
        endif

        let l:request = 'curl -s ' .
            \'-A ''vim-repoman'' ' .
            \'-H ''Accept: ' . self.type . ''' ' .
            \'-H ''Authorization: token '. a:token . ''' '

        if !empty(l:body) && !empty(l:method)
            let l:request = l:request .
                \'--data ''' . l:body . ''' ' .
                \'-X '. l:method . ' '

            echom l:request . ' ''' . a:url . ''''
        endif

        return l:request . ' ''' . a:url . ''''
    endfunction

    function! request.BackgroundSend(token, url, ...) abort
        return repoman#request#Send(
            \a:token, a:url,
            \a:0 > 0 ? a:1 : '',
            \a:0 > 1 ? a:2 : '') . ' &'
    endfunction

    return request
endfunction