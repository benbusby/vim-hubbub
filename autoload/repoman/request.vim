" =========================================================================
" File:    autoload/repoman/request.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: A class for constructing and sending curl requests to the
" appropriate endpoint.
" =========================================================================

" A vimscript curl implementation, used for sending requests to the
" appropriate repo hosting service.
"
" Args:
" - ...: an optional "Accept" header value
"
" Returns:
" - (Curl) a new curl object for sending requests
function! repoman#request#Curl(...) abort
    let request = {
        \'type': (a:0 > 0 ? a:1 : 'application/json'),
        \'auth': (repoman#utils#GetRepoHost() ==# 'github'
            \? '-H ''Authorization: token '
            \: '-H ''PRIVATE-TOKEN: ')}

    " Creates and sends a formatted curl request to the specified url
    "
    " Args:
    " - token: the decrypted authentication token for the user
    " - url: the full url request path
    " - ...: an optional body and request method
    "
    " Returns:
    " - (json) the json decoded response from the API
    function! request.Send(token, url, ...) abort
        let l:body = ''
        let l:method = ''

        if a:0 > 0
            let l:body = a:1
            let l:method = a:2
        endif

        let l:request = 'curl -L -s ' .
            \'-A ''vim-repoman'' ' .
            \'-H ''Accept: ' . self.type . ''' ' .
            \self.auth . a:token . ''' '

        if !empty(l:body) 
            let l:request = l:request .
                \'--data ''' . l:body . ''' '
        endif

        if !empty(l:method)
            let l:request = l:request .
                \'-X '. l:method . ' '
        endif

        return system(l:request . ' ''' . a:url . '''')
    endfunction

    " Creates and sends a background curl request to the specified url.
    "
    " Note: Currently unused, but would be implemented if more effort is put
    " into finishing the "Soft Reload" feature.
    "
    " Args:
    " - Same as Send()
    "
    " Returns:
    " - none
    function! request.BackgroundSend(token, url, ...) abort
        return self.Send(
            \a:token, a:url,
            \a:0 > 0 ? a:1 : '',
            \a:0 > 1 ? a:2 : '') . ' &'
    endfunction

    return request
endfunction
