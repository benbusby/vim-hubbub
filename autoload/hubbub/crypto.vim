" =========================================================================
" File:    autoload/hubbub/crypto.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A set of functions for encrypting and decrypting text.
" =========================================================================
let s:encrypt_cmd = 'openssl enc -aes-256-cbc %s -md sha256 -out '
let s:decrypt_cmd = 'openssl aes-256-cbc -md sha256 -d %s -in '
let s:pw_str = ' -pass pass:'

function! hubbub#crypto#Encrypt(contents, file, password) abort
    if empty(a:password)
        call system('echo ''' . a:contents . ''' > ' . a:file)
        call system('touch ' . a:file . '.nopass')
    else
        call system('rm -f ' . a:file . '.nopass')
        call system('echo ''' . a:contents . ''' | ' .
            \GetCommand(s:encrypt_cmd) . a:file . s:pw_str . a:password)
    endif
endfunction

function! hubbub#crypto#Decrypt(file, password) abort
    return system(GetCommand(s:decrypt_cmd) . a:file . s:pw_str . a:password)
endfunction

function! GetCommand(command) abort
    let l:openssl_old = exists('g:hubbub_openssl_old') && g:hubbub_openssl_old
    return printf(a:command, l:openssl_old ? '' : '-salt -pbkdf2')
endfunction
