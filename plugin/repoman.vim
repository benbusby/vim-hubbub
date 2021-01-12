" ============================================================================
" File:    plugin/repoman.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: A header file of all commands that are available to the user.
" ============================================================================

" Init
command! -nargs=0 RepoManInit call repoman#RepoManInit()

" Navigation
command! -nargs=0 RepoMan     call repoman#RepoMan()
command! -nargs=0 RepoManBack call repoman#RepoManBack()
command! -nargs=1 RepoManPage call repoman#RepoManPage('<args>')

" Interactions
command! -nargs=1 RepoManReact   call repoman#RepoManReact('<args>')
command! -nargs=0 RepoManEdit    call repoman#RepoManEdit()
command! -nargs=0 RepoManPost    call repoman#RepoManPost()
command! -nargs=0 RepoManClose   call repoman#RepoManClose()
command! -nargs=0 RepoManLabel   call repoman#RepoManLabel()
command! -nargs=1 RepoManNew     call repoman#RepoManNew('<args>')
command! -nargs=? RepoManMerge   call repoman#RepoManMerge('<args>')
command! -nargs=1 RepoManReview  call repoman#RepoManReview('<args>')
command! -nargs=0 RepoManSave    call repoman#RepoManSave()
command! -nargs=0 RepoManReply   call repoman#RepoManReply()
command! -nargs=0 RepoManDelete  call repoman#RepoManDelete()

" Range methods
command! -range RepoManSuggest <line1>,<line2>call repoman#RepoManSuggest()
command! -range RepoManComment <line1>,<line2>call repoman#RepoManComment()

" Short versions of commands (same command interaction commands, but without
" the RepoMan prefix)
if exists('g:repoman_short_commands') && g:repoman_short_commands
    command! -nargs=1 React   call repoman#RepoManReact('<args>')
    command! -nargs=0 Edit    call repoman#RepoManEdit()
    command! -nargs=0 Post    call repoman#RepoManPost()
    command! -nargs=0 Close   call repoman#RepoManClose()
    command! -nargs=0 Label   call repoman#RepoManLabel()
    command! -nargs=1 New     call repoman#RepoManNew('<args>')
    command! -nargs=? Merge   call repoman#RepoManMerge('<args>')
    command! -nargs=1 Review  call repoman#RepoManReview('<args>')
    command! -nargs=0 Save    call repoman#RepoManSave()
    command! -nargs=0 Reply   call repoman#RepoManReply()
    command! -nargs=0 Delete  call repoman#RepoManDelete()
    command! -range Suggest <line1>,<line2>call repoman#RepoManSuggest()
    command! -range Comment <line1>,<line2>call repoman#RepoManComment()
endif
