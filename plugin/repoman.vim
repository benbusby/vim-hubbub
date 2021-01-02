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
command! -nargs=0 RepoManComment call repoman#RepoManComment()
command! -nargs=0 RepoManPost    call repoman#RepoManPost()
command! -nargs=0 RepoManClose   call repoman#RepoManClose()
command! -nargs=0 RepoManLabel   call repoman#RepoManLabel()
command! -nargs=1 RepoManNew     call repoman#RepoManNew('<args>')
command! -nargs=? RepoManMerge   call repoman#RepoManMerge('<args>')
command! -nargs=1 RepoManReview  call repoman#RepoManReview('<args>')
command! -nargs=0 RepoManSave    call repoman#RepoManSave()
command! -nargs=0 RepoManReply   call repoman#RepoManReply()
command! -nargs=0 RepoManDelete  call repoman#RepoManDelete()

" Range
command! -range RepoManSuggest <line1>,<line2>call repoman#RepoManSuggest()
command! -range RepoManComment <line1>,<line2>call repoman#RepoManComment()
