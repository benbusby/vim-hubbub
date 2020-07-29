" ============================================================================
" File:        vissues_commands.vim
" Description: Establishes commands that the user can run to access repo issues
" Author:      Ben Busby <contact@benbusby.com>
" License:     MIT
" Website:     https://benbusby.com/vissues/
" Version:     1.0
" ============================================================================

command! -nargs=0 VissuesOpen call vissues#VissuesOpen()
command! -nargs=0 VissuesBack call vissues#VissuesBack()
command! -nargs=0 VissuesExit call vissues#VissuesExit()
