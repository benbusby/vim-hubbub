" ============================================================================
" File:        vimgmt_commands.vim
" Description: Establishes vim commands for managing git repos
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

" Navigation
command! -nargs=0 Vimgmt     call vimgmt#Vimgmt()
command! -nargs=0 VimgmtBack call vimgmt#VimgmtBack()

" Interactions
command! -nargs=0 VimgmtComment call vimgmt#VimgmtComment()
command! -nargs=0 VimgmtPost    call vimgmt#VimgmtPost()
command! -nargs=0 VimgmtClose   call vimgmt#VimgmtClose()
