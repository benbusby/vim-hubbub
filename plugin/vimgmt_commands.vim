" ============================================================================
" File:        vimgmt_commands.vim
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://github.com/benbusby/vimgmt/
" Version:     1.0
" ============================================================================

" Navigation
command! -nargs=0 Vimgmt     call vimgmt#Vimgmt()
command! -nargs=0 VimgmtBack call vimgmt#VimgmtBack()

" Interactions
command! -nargs=0 VimgmtComment call vimgmt#VimgmtComment()
command! -nargs=0 VimgmtPost    call vimgmt#VimgmtPost()
command! -nargs=0 VimgmtClose   call vimgmt#VimgmtClose()
command! -nargs=1 VimgmtNew     call vimgmt#VimgmtNew('<args>')
command! -nargs=? VimgmtMerge   call vimgmt#VimgmtMerge('<args>')
