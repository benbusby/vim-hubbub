" ============================================================================
" File:        vimgmt_commands.vim
" Description: Establishes commands that the user can run to access repo issues
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/projects/vimgmt/
" Version:     1.0
" ============================================================================

command! -nargs=0 vimgmt call vimgmt#vimgmt()
command! -nargs=0 vimgmtBack call vimgmt#vimgmtBack()
command! -nargs=0 vimgmtExit call vimgmt#vimgmtExit()
