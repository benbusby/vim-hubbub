" ============================================================================
" File:    plugin/hubbub.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-hubbub
" Description: A header file of all commands that are available to the user.
" ============================================================================

" Init
command! -nargs=0 HubbubInit call hubbub#HubbubInit()

" Navigation
command! -nargs=0 Hubbub     call hubbub#Hubbub()
command! -nargs=0 HubbubBack call hubbub#HubbubBack()
command! -nargs=1 HubbubPage call hubbub#HubbubPage('<args>')

" Interactions
command! -nargs=1 HubbubReact   call hubbub#HubbubReact('<args>')
command! -nargs=0 HubbubEdit    call hubbub#HubbubEdit()
command! -nargs=0 HubbubPost    call hubbub#HubbubPost()
command! -nargs=0 HubbubClose   call hubbub#HubbubClose()
command! -nargs=0 HubbubLabel   call hubbub#HubbubLabel()
command! -nargs=1 HubbubNew     call hubbub#HubbubNew('<args>')
command! -nargs=? HubbubMerge   call hubbub#HubbubMerge('<args>')
command! -nargs=1 HubbubReview  call hubbub#HubbubReview('<args>')
command! -nargs=0 HubbubSave    call hubbub#HubbubSave()
command! -nargs=0 HubbubReply   call hubbub#HubbubReply()
command! -nargs=0 HubbubDelete  call hubbub#HubbubDelete()

" Range methods
command! -range HubbubSuggest <line1>,<line2>call hubbub#HubbubSuggest()
command! -range HubbubComment <line1>,<line2>call hubbub#HubbubComment()

" Short versions of commands (same command interaction commands, but without
" the Hubbub prefix)
if exists('g:hubbub_short_commands') && g:hubbub_short_commands
    command! -nargs=1 React   call hubbub#HubbubReact('<args>')
    command! -nargs=0 Edit    call hubbub#HubbubEdit()
    command! -nargs=0 Post    call hubbub#HubbubPost()
    command! -nargs=0 Close   call hubbub#HubbubClose()
    command! -nargs=0 Label   call hubbub#HubbubLabel()
    command! -nargs=1 New     call hubbub#HubbubNew('<args>')
    command! -nargs=? Merge   call hubbub#HubbubMerge('<args>')
    command! -nargs=1 Review  call hubbub#HubbubReview('<args>')
    command! -nargs=0 Save    call hubbub#HubbubSave()
    command! -nargs=0 Reply   call hubbub#HubbubReply()
    command! -nargs=0 Delete  call hubbub#HubbubDelete()
    command! -range Suggest <line1>,<line2>call hubbub#HubbubSuggest()
    command! -range Comment <line1>,<line2>call hubbub#HubbubComment()
endif
