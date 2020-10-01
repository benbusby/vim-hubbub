" ============================================================================
" File:        vimgmt_commands.vim
" Description: Establishes commands that the user can run to access repo issues
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

command! -nargs=0 Vimgmt call vimgmt#Vimgmt()
command! -nargs=0 VimgmtBack call vimgmt#VimgmtBack()
command! -nargs=0 VimgmtExit call vimgmt#VimgmtExit()
