" =========================================================================
" File:    autoload/repoman/crypto.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: A set of functions for encrypting and decrypting text.
" =========================================================================
let s:encrypt_cmd = 'openssl enc -aes-256-cbc %s -out '
let s:decrypt_cmd = 'openssl aes-256-cbc -d %s -in '
let s:pw_str = ' -pass pass:'

function! repoman#crypto#Encrypt(contents, file, password) abort
    call system('echo ''' . a:contents . ''' | ' .
        \GetCommand(s:encrypt_cmd) . a:file . s:pw_str . a:password)
endfunction

function! repoman#crypto#Decrypt(file, password) abort
    return system(GetCommand(s:decrypt_cmd) . a:file . s:pw_str . a:password)
endfunction

function! GetCommand(command) abort
    let l:openssl_old = exists('g:repoman_openssl_old') && g:repoman_openssl_old
    return printf(a:command, l:openssl_old ? '' : '-salt -pbkdf2')
endfunction
