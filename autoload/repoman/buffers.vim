" =========================================================================
" File:    autoload/repoman/buffers.vim
" Author:  Ben Busby <https://benbusby.com>
" License: MIT
" Website: https://github.com/benbusby/vim-repoman
" Description: Methods/utilities and a constructor for creating/modifying
" specific buffers for every view.
" =========================================================================
scriptencoding utf-8

let s:constants = function('repoman#constants#Constants')()
let s:r_keys = response_keys[repoman#utils#GetRepoHost()]
let s:ui = repoman#decorations#Decorations().ui
let s:strings = lang_dict[(exists('g:repoman_language') ? g:repoman_language : 'en')]

" =========================================================================
" Buffer Utilities
" =========================================================================

" Opens a new buffer with the specified buffer name.
"
" Args:
" - buf_name: the buffer name (supplied by constants.buffers),
" - header_mode: a -1/0/1 flag to modify the buffer header
"   - (-1) Hide the top header
"   - (0)  Show the top header, without page indicator
"   - (1)  Show the top header, with page indicator
" - state: the current state of the plugin
"
" Returns:
" - (int) the current line number
function! OpenBuffer(buf_name, header_mode, state) abort
    " Close buffer first if attempting to reopen
    if bufexists(bufnr(a:buf_name)) > 0
        execute 'bw! ' . fnameescape(a:buf_name)
    endif

    " Open issue buffer in new buffer if split is disabled
    " Note that we do not want to open a new buffer for non-primary buffers
    " (i.e. new comments, issue mods, etc).
    let l:skip_split = exists('g:repoman_split_issue') && !g:repoman_split_issue
    if (index(s:constants.primary_bufs, a:buf_name) >= 0 && l:skip_split) ||
            \a:buf_name == s:constants.buffers.review
        enew
    else
        if line('$') ==? 1 && getline(1) ==? ''
            enew  " Use whole window for results
        elseif winwidth(0) > winheight(0) * 2.5
            vnew  " Window is wide enough for vertical split
        else
            if a:buf_name == s:constants.buffers.issue
                enew  " Use full buffer for issue view
            else
                new   " Window is too narrow, use horizontal split
            endif
        endif
    endif

    silent! execute 'file ' . fnameescape(a:buf_name)
    setlocal bufhidden=hide noswapfile wrap

    " Set up jump guide for skipping through content
    let b:jump_guide = []

    set modifiable

    return a:header_mode >= 0 ?
        \SetHeader(a:header_mode, a:state) : 1
endfunction

" Sets a header section for a buffer. Consists of the plugin
" name, the repo name (if available), and a page indicator (if
" relevant).
"
" Args:
" - header_mode: a -1/0/1 flag to indicate paginated results
"   - (-1) Hide the top header
"   - (0) Show the top header, without page indicator
"   - (1) Show the top header, with page indicator
" - state: the current state of the plugin
"
" Returns:
" - (int) the current line number
function! SetHeader(header_mode, state) abort
    let l:line_idx = 1
    for line in readfile(g:repoman_dir . '/assets/header.txt')
        let l:page_id = a:header_mode ? ' (page ' . a:state.page . ')' : ''
        if l:line_idx == 1
            if empty(a:state.repo)
                let l:line_idx = WriteLine(line[:-3] . l:page_id)
            else
                let l:line_idx = WriteLine(line . ' ' . a:state.repo . l:page_id)
            endif
        else
            let l:line_idx = WriteLine(line)
        endif
    endfor

    return l:line_idx
endfunction

" Removes alphabetical characters from time string.
"
" Args:
" - time_str: a datetime string
"
" Returns:
" - (str) an easily readable time str (ex: 2020-10-07 15:10:03)
function! FormatTime(time_str) abort
    return substitute(a:time_str, '[a-zA-Z]', ' ', 'g')
endfunction

" Generates a string from a set of reactions.
"
" Args:
" - item: a json object (comment, issue, etc)
"
" Returns:
" - (str) a string representation of the item's current reactions
function! GenerateReactionsStr(item) abort
    if !has_key(a:item, 'reactions')
        return s:strings.no_reactions
    endif

    let l:reactions = a:item['reactions']
    let l:reaction_str = ''

    for key in sort(keys(s:constants.reactions))
        if has_key(l:reactions, key) && l:reactions[key] > 0
            let l:reaction_str = l:reaction_str .
                \s:constants.reactions[key] . l:reactions[key] . ' '
        endif
    endfor

    return (len(l:reaction_str) > 0 ? l:reaction_str : s:strings.no_reactions)
endfunction


" Filters out bad characters, brings the cursor to the top of the
" buffer, and sets the buffer as not modifiable
"
" Args:
" - none
"
" Returns:
" - none
function! FinishOutput() abort
    setlocal nomodifiable
    set cmdheight=1 hidden bt=nofile splitright
    call repoman#utils#LoadSyntaxColoring(s:strings)

    " Add HJKL shortcuts if in the buffer supports it
    if exists('b:jump_guide') && len(b:jump_guide) > 0
        nnoremap <buffer> <silent> J :call repoman#RepoManJump(1)<CR>
        nnoremap <buffer> <silent> K :call repoman#RepoManJump(-1)<CR>
        nnoremap <script> <silent> L :call repoman#RepoManPage(1)<CR>
        nnoremap <script> <silent> H :call repoman#RepoManPage(-1)<CR>
    endif
endfunction

" Writes a line to the current buffer
"
" Args:
" - line: the content to write to the buffer
"
" Returns:
" - (int) the updated cursor position
function! WriteLine(line) abort
    if empty(getline(1))
        " Write over line 1 if empty
        call setline(1, substitute(a:line, '', '', 'ge'))
        return 2
    endif

    " Write to the next line
    let l:pos = line('$') + 1
    call setline(l:pos, substitute(a:line, '', '', 'ge'))
    return l:pos
endfunction

" Parses labels from an array into a comma separated list, as well as sets
" highlighting rules for each label (if a color is returned in the
" response).
"
" Args:
" - labels: a json array of the labels for the issue/pr/etc
"
" Returns:
" - (str) a comma separated list of labels, with label color highlighting (if
" available)
function! ParseLabels(labels) abort
    let l:label_list = ''

    for label in a:labels
        let l:label_name = '|' . label['name'] . '|'

        " Use colors for labels if provided by the response
        if has_key(label, 'color')
            let l:label_color = '#' . label['color']

            exe 'hi ' . substitute(label['name'], '[^a-zA-Z]', '', 'g') . ' gui=bold guifg=' . l:label_color
            exe 'syn match ' . substitute(label['name'], '[^a-zA-Z]', '', 'g') . ' /' . l:label_name . '/'
        endif

        " Append a comma if there is more than one tag
        if l:label_list =~? '[^\s]'
            let l:label_list = l:label_list . ', '
        endif

        let l:label_list = l:label_list . l:label_name
    endfor

    return l:label_list
endfunction

" Insert segments of issue/request body, inserting line breaks as
" needed.
"
" Args:
" - body: the full body text of the item, with linebreaks
"
" Returns:
" - (int) the new cursor position
function! InsertBodyText(body) abort
    let l:chunk_num = 0
    for chunk in split(a:body, '\n')
        let chunk = substitute(chunk, '\"', '', 'ge')
        call WriteLine(chunk)
        let l:chunk_num += 1
    endfor

    return l:chunk_num
endfunction

" Inserts comments into the buffer
"
" Args:
" - comment: a json object representing an issue/pr comment
"
" Returns:
" - none
function! InsertComment(comment) abort
    let commenter = a:comment[s:r_keys.user][s:r_keys.login]
    if has_key(a:comment, 'author_association') && a:comment['author_association'] !=? 'none'
        let commenter = '(' . tolower(a:comment['author_association']) . ') ' . commenter
    endif

    call WriteLine('')

    " If this is a review comment, it needs different formatting/coloring
    if has_key(a:comment, 'pull_request_review_id')
        set syntax=diff
        call InsertReviewComments(a:comment)
    else
        call WriteLine(s:ui.comment_header_start)
        let l:created = FormatTime(a:comment[s:r_keys.created_at])
        let l:updated = FormatTime(a:comment[s:r_keys.updated_at])
        let l:time = FormatTime(l:created) .
            \(l:created !=# l:updated ? '- edited: ' . l:updated : '')
        let l:line_idx = WriteLine('  ' . l:time)
        let l:start_idx = l:line_idx
        call WriteLine('  ' . commenter . ': ')
        call WriteLine(s:ui.comment_header_end)

        " Split comment body on line breaks for proper formatting
        for comment_line in split(a:comment[s:r_keys.body], '\n')
            let l:line_idx = WriteLine(s:ui.comment . comment_line)
        endfor

        let l:reactions_str = GenerateReactionsStr(a:comment)
        if !empty(l:reactions_str)
            call WriteLine(s:ui.comment . '')
            let l:line_idx = WriteLine(s:ui.comment . '[ ' . l:reactions_str . ']')
        endif

        call add(b:jump_guide, l:line_idx)
        while l:start_idx <= l:line_idx
            let b:comment_lookup[string(l:start_idx)] = {
                \'id': a:comment[s:r_keys.id],
                \'body': a:comment[s:r_keys.body],
                \'type': 'issues'}
            let l:start_idx += 1
        endwhile
    endif

    "nnoremap <buffer> <silent> <C-d> :call DeleteComment(
        "\b:comment_lookup[getcurpos()[1]])<CR>
    "nnoremap <buffer> <silent> <C-e> :call EditCommentBuffer(
        "\b:comment_lookup[getcurpos()[1]])<CR>
endfunction

" Inserts a set of comments for a Pull Request review
"
" Args:
" - comment: a json object representing a set of review comments
"
" Returns:
" - none
function! InsertReviewComments(comment) abort
    " The 'position' element indicates if this comment is still relevant
    " in the current state of the pull request
    if !a:comment['position']
        if exists('g:repoman_show_outdated') && g:repoman_show_outdated
            call WriteLine(s:strings.outdated)
        else
            call WriteLine(s:strings.outdated . ' ' . s:strings.hidden)
            return
        endif
    endif

    " Write out the file name and 'diff hunk' (the snippet of the
    " diff that is relevant for the comment)
    call WriteLine('[' . a:comment['path'] . ']')
    for diff_line in split(a:comment['diff_hunk'], '\n')
        call WriteLine(diff_line)
    endfor

    let l:level = 1

    " Each individual review comment can have its own subdiscussion, which
    " is tracked in the 'review_comments' array
    if !has_key(a:comment, 'review_comments')
        let l:self = deepcopy(a:comment)
        let l:self[s:r_keys.login] = l:self.user.login
        let a:comment['review_comments'] = [l:self]
    endif
    for review_comment in a:comment['review_comments']
        let l:comment_decor = s:ui.review_comment
        if l:level ==# 1
            call WriteLine(s:ui.new_review_comment)
        else
            call WriteLine(s:ui.review_reply)
            let l:comment_decor = '    ' . l:comment_decor
        endif

        let commenter = review_comment[s:r_keys.login]
        if has_key(review_comment, 'author_association') && review_comment['author_association'] !=? 'none'
            let commenter = '(' . tolower(review_comment['author_association']) . ') ' . commenter
        endif
        let l:line_idx = WriteLine(l:comment_decor . FormatTime(review_comment[s:r_keys.created_at]))
        let l:start_idx = l:line_idx

        call WriteLine(l:comment_decor . commenter . ': ')
        for body_line in split(review_comment['body'], '\n')
            " If there's a suggestion, replace w/ relevant syntax highlighting
            " for the file
            if body_line =~# 'suggestion'
                call WriteLine(l:comment_decor . s:strings.suggestion)
                let extension = fnamemodify(a:comment['path'], ':e')
                let body_line = substitute(body_line, 'suggestion', extension, '')
            endif
            let l:line_idx = WriteLine(l:comment_decor . body_line)
        endfor

        let l:reactions_str = GenerateReactionsStr(review_comment)
        if !empty(l:reactions_str)
            call WriteLine(l:comment_decor)
            let l:line_idx = WriteLine(l:comment_decor . l:reactions_str)
        endif

        call add(b:jump_guide, l:line_idx)
        while l:start_idx <= l:line_idx
            let b:comment_lookup[string(l:start_idx)] = {
                \'id': review_comment[s:r_keys.id],
                \'body': review_comment['body'],
                \'type': 'pulls'}
            let l:start_idx += 1
        endwhile

        if l:level > 1 && l:level != len(a:comment['review_comments'])
            call WriteLine(s:ui.end_first_reply)
        elseif l:level > 1 && l:level == len(a:comment['review_comments'])
            call WriteLine(s:ui.end_review_reply)
        else
            if l:level == len(a:comment['review_comments'])
                call WriteLine(s:ui.end_review_comment)
            else
                call WriteLine(s:ui.end_first_comment)
            endif
        endif
        let l:level += 1
    endfor
endfunction

" =========================================================================
" Buffers Class
" =========================================================================

" The "Buffers" class constructs various buffers that are relevant to the data
" that is handled in repoman.
"
" Args:
" - repoman: the current state of the repoman plugin.
"
" Returns:
" - (Buffers) a Buffers object for easily creating new buffers
function! repoman#buffers#Buffers(repoman) abort
    let state = a:repoman

    " =====================================================================
    " Repositories
    " =====================================================================

    " Creates a buffer representing the authenticated user's list of available
    " repos. By default, repoman pulls repos from GitHub, but can be
    " configured to use GitLab (see
    " https://github.com/benbusby/vim-repoman#configuration)
    "
    " Args:
    " - repos: a json array of repos
    "
    " Returns:
    " - none
    function! state.CreateRepoListBuffer(repos) abort
        let l:line_idx = OpenBuffer(s:constants.buffers.issue_list, 1, self)
        let s:results_line = l:line_idx
        let b:repo_lookup = {}

        " Write repo details to buffer
        for item in a:repos
            let l:start_idx = WriteLine(item['full_name'] . (item['private'] ? ' (Private)' : ''))
            call add(b:jump_guide, l:start_idx)

            call WriteLine(s:ui.spacer_small)
            call WriteLine(item['description'])
            call WriteLine(s:strings.updated . FormatTime(item[s:r_keys.updated_at]))
            call WriteLine(s:strings.issues . item['open_issues_count'])
            call WriteLine(s:constants.symbols.star . item['stargazers_count'])
            call WriteLine(s:ui.spacer_small)

            let l:line_idx = WriteLine('')
            call WriteLine(s:ui.spacer)
            call WriteLine('')

            while l:start_idx <= l:line_idx
                let b:repo_lookup[l:start_idx] = {
                    \'path': item['full_name']
                \}
                let l:start_idx += 1
            endwhile
        endfor

        " Set up the ability to hit Enter on any repo under the cursor
        " position to open an issues list buffer for that repo
        call cursor(s:results_line, 1)
        nnoremap <buffer> <silent> <CR> :call 
            \repoman#buffers#Buffers(
                \{'page': 1,
                \'repo': b:repo_lookup[getcurpos()[1]]['path']
            \}).CreateIssueListBuffer(
                \IssueListQuery(b:repo_lookup[getcurpos()[1]]['path'])
            \)<cr>

        call FinishOutput()
    endfunction

    " =====================================================================
    " Issues / Pull Requests
    " =====================================================================

    " Creates a buffer for the list of issues or PRs.
    "
    " Args:
    " - results: a json array of issues/pull requests
    "
    " Returns:
    " - none
    function! state.CreateIssueListBuffer(results) abort
        let l:line_idx = OpenBuffer(s:constants.buffers.issue_list, 1, self)
        let s:results_line = l:line_idx
        let b:issue_lookup = {}

        " Write issue details to buffer
        for item in a:results
            " Set title and indicator for whether or not the item is a Pull
            " Request
            let l:item_name = '[' . (has_key(item, 'pull_request')
                \? s:strings.pr : s:strings.issue) . '] ' .
                \'#' . item[s:r_keys.number] . ': ' . item[s:r_keys.title]
            let l:start_idx = WriteLine(l:item_name)
            call add(b:jump_guide, l:start_idx)

            " Draw boundary between title and body
            let l:line_idx = WriteLine(s:ui.spacer_small)

            let l:label_list = ParseLabels(item[s:r_keys.labels])
            call WriteLine(s:strings.comments . item[s:r_keys.comments])
            call WriteLine(s:strings.labels . l:label_list)
            call WriteLine(s:strings.updated . FormatTime(item[s:r_keys.updated_at]))

            " Mark line number where the issue interaction should stop
            let l:line_idx = WriteLine('')
            call WriteLine(s:ui.spacer)
            call WriteLine('')

            " Store issue number and title to use for viewing issue details later
            while l:start_idx <= l:line_idx
                let b:issue_lookup[l:start_idx] = {
                    \'number': item[s:r_keys.number],
                    \'title': item[s:r_keys.title],
                    \'pr': has_key(item, 'pull_request')
                \}
                let l:start_idx += 1
            endwhile
        endfor

        " Set up the ability to hit Enter on any issue section to open an issue
        " buffer
        call cursor(s:results_line, 1)
        nnoremap <buffer> <silent> <CR> :call ViewIssue(
            \b:issue_lookup[getcurpos()[1]]['number'],
            \b:issue_lookup[getcurpos()[1]]['pr'])<cr>

        call FinishOutput()
    endfunction

    " Create issue/(pull|merge) request buffer
    "
    " Args:
    " - contents: a json object representing the issue/pr/etc
    "
    " Returns:
    " - none
    function! state.CreateIssueBuffer(contents) abort
        let l:line_idx = OpenBuffer(s:constants.buffers.issue, 0, self)
        let s:results_line = l:line_idx

        " Write issue and comments to buffer
        let l:type = '[' . (self.pr ? s:strings.pr : s:strings.issue) . '] '
        call WriteLine(l:type . '#' . a:contents[s:r_keys.number] . ': ' . a:contents[s:r_keys.title])
        let l:line_idx = WriteLine(s:ui.spacer_small)

        " Split body on line breaks for proper formatting
        let l:line_idx += InsertBodyText(a:contents[s:r_keys.desc])

        call WriteLine(s:ui.spacer_small)
        call WriteLine(s:strings.created . FormatTime(a:contents[s:r_keys.created_at]))
        call WriteLine(s:strings.updated . FormatTime(a:contents[s:r_keys.updated_at]))
        call WriteLine(s:strings.author . a:contents[s:r_keys.user][s:r_keys.login])
        call WriteLine(s:strings.labels . ParseLabels(a:contents[s:r_keys.labels]))
        call WriteLine(s:ui.spacer_small)

        " Add reactions to issue (important)
        let l:reactions_str = GenerateReactionsStr(a:contents)
        if !empty(l:reactions_str)
            call WriteLine(l:reactions_str)
        endif

        call WriteLine(s:ui.spacer_small)
        call WriteLine('')

        let l:line_idx = WriteLine(s:strings.comments_alt . '(' . len(a:contents[s:r_keys.comments]) . ')')

        let b:comment_lookup = {}
        for comment in a:contents[s:r_keys.comments]
            call InsertComment(comment)
        endfor

        " Store issue number for interacting with the issue (commenting, closing,
        " etc)
        let self.current_issue = a:contents[s:r_keys.number]

        nnoremap <buffer> <silent> gi :RepoManBack<CR>

        call FinishOutput()
    endfunction

    " Create a buffer for a new item (issue/pr/mr/etc)
    "
    " Args:
    " - type: a str indicator of the type of item to create
    " - ...: an optional default branch indicator (when creating a new PR)
    "
    " Returns:
    " - none
    function! state.NewItemBuffer(type, ...) abort
        set splitbelow
        let l:descriptor = s:strings.issue

        if a:type ==? 'issue'
            call OpenBuffer(s:constants.buffers.new_issue, -1, self)
        else
            call OpenBuffer(s:constants.buffers.new_req, -1, self)
            let l:descriptor = s:strings.pr
            call WriteLine(s:strings.head . ': ' . repoman#utils#GetBranchName())
            call WriteLine(s:strings.base . ': ' . a:1)
            call WriteLine('')
        endif

        call WriteLine(l:descriptor . ' ' . s:strings.title)
        call WriteLine(repeat('-', 20))
        call WriteLine(l:descriptor . ' ' . s:strings.desc)
        call FinishOutput()

        " Re-enable modifiable so that we can write something
        set modifiable
    endfunction

    " Edit a buffer related to an item (issue or pull request)
    "
    " Args:
    " - type: a str indicator of the type of item to edit
    " - details: the issue/pr details for editing
    "
    " Returns:
    " - none
    function! state.EditItemBuffer(details) abort
        set splitbelow
        call OpenBuffer(s:constants.buffers.edit, -1, self)

        call WriteLine(a:details[s:r_keys.title])
        call WriteLine(repeat('-', 20))
        for line in split(a:details[s:r_keys.body], '\n')
            call WriteLine(line)
        endfor
        call FinishOutput()

        let b:edit_values = deepcopy(a:details)
        let b:edit_values.edit = 'issue'

        set modifiable
    endfunction

    " Create a buffer for the current PR diff
    "
    " The b:review_lookup table is populated according to the
    " necessary review components seen here:
    " https://docs.github.com/en/rest/reference/pulls#create-a-review-for-a-pull-request
    "
    " Note that multiline comments and single line comments require completely
    " different parameters for telling GitHub where the comment should appear.
    " For single-line comments, the 'position' value is required, which is
    " determined by the number of lines below the first @@ header for each
    " file in the diff. Multiline comments require the 'start_[line|side]' and
    " '[line|side]' parameters, which use the actual file line number.
    "
    " The two can't be mixed, as the GitHub API disallows setting the start
    " and end line number to the same line to create a single line comment. 
    " (Which imo would be a lot simpler, but ¯\_(ツ)_/¯)
    "
    " Args:
    " - diff: the pr diff contents
    "
    " Returns:
    " - none
    function! state.CreateReviewBuffer(diff) abort
        call OpenBuffer(s:constants.buffers.review, -1, self)
        let b:review_lookup = {}
        let b:review_comment_lookup = {}
        let b:review_comments = {}

        let l:current_file = ''
        let l:position = 0

        let l:start_left = 0
        let l:start_right = 0
        let l:curr_left = 0
        let l:curr_right = 0

        for chunk in split(a:diff, '\n')
            let l:line_idx = WriteLine(chunk)
            if stridx(chunk, 'diff --git a/') == 0
                let l:position = -1
                let l:curr_left = -1
                let l:curr_right = -1
                let l:current_file = split(
                    \substitute(chunk, 'diff --git a/', '', ''))[0]
            endif

            if l:position >= 0
                let l:position += 1
            endif

            " The first '@@' header should begin counting lines for
            " commenting, but future headers should be ignored
            if stridx(chunk, '@@') == 0 && l:position < 0
                let l:position = 0
            endif

            let l:left = 1
            let l:right = 1
            if l:curr_left >= 0 || l:curr_right >= 0
                " Increment current line depending on the context
                let l:left = 1
                let l:right = 1
                if chunk[0] ==# '-'
                    let l:curr_left += 1
                    let l:right = -1
                elseif chunk[0] ==# '+'
                    let l:curr_right += 1
                    let l:left = -1
                else
                    let l:curr_left += 1
                    let l:curr_right += 1
                endif
            endif

            if stridx(chunk, '@@') == 0
                let l:curr_left = 0
                let l:curr_right = 0
                let l:header = split(substitute(split(chunk, '@@')[0], ' ', '', 'ge'), ',')
                let l:start_left = l:header[0][1:] - 1
                let l:start_right = l:header[1][stridx(l:header[1], '+') + 1:] - 1
            endif

            let b:review_lookup[l:line_idx] = {
                \'file': l:current_file,
                \'line_nr_left': (l:curr_left + l:start_left) * l:left,
                \'line_nr_right': (l:curr_right + l:start_right) * l:right,
                \'position': l:position
            \}
        endfor

        set syntax=diff
        call FinishOutput()
        nnoremap <buffer> <silent> <CR> :echo string(b:review_lookup[getcurpos()[1]])<cr>
    endfunction

    " Removes a comment from the review buffer, updating all lookup dicts
    " pertaining to the removed comment
    "
    " Args:
    " - comment: the comment data to be removed
    "
    " Returns:
    " - none
    function! state.RemoveReviewBufferComment(comment) abort
        set modifiable
        call remove(b:review_comments, a:comment.id)

        " Initialize tracking values for which lines need modifications
        let l:line_nr = 1
        let l:num_del = 0
        let l:line_del = 0

        " Iterate through the lines in the buffer, marking the necessary
        " comment lines for deletion and shifting the lookup table accordingly
        while l:line_nr <= line('$')
            if has_key(b:review_comment_lookup, l:line_nr) &&
                \b:review_comment_lookup[l:line_nr] == a:comment.id
                if !l:line_del
                    let l:line_del = l:line_nr
                endif
                let l:num_del += 1
                call remove(b:review_comment_lookup, l:line_nr)
            elseif has_key(b:review_lookup, l:line_nr)
                let b:review_lookup[l:line_nr - l:num_del] = b:review_lookup[l:line_nr]
            endif

            let l:line_nr += 1
        endwhile

        " Remove the comment lines from the buffer, accounting for shifting of
        " the buffer (ex/ removing lines 23-25 requires calling '23d' 3 times)
        let l:i = 0
        while l:i < l:num_del
            execute l:line_del . 'd'
            let l:i += 1
        endwhile
        set nomodifiable
    endfunction

    " Add a comment to the review buffer
    "
    " Args:
    " - comment: the comment contents to add to the buffer
    " - review_data: the relevant line number and file for the comment
    " - position: the cursor position to insert the comment. If 0/null,
    "   the comment will be inserted where the cursor was last positioned
    "   in the buffer
    "
    " Returns:
    " - none
    function! state.AddReviewBufferComment(comment, review_data) abort
        set modifiable

        " Store comment for submission later
        let l:comment_id = len(b:review_comments)
        let b:review_comments[l:comment_id] = {
            \'id': l:comment_id,
            \'path': b:review_lookup[a:review_data.cursor]['file'],
            \'position': b:review_lookup[a:review_data.cursor]['position'],
            \'cursor_start': a:review_data.cursor_start,
            \'cursor': a:review_data.cursor,
            \'body': repoman#utils#SanitizeText(join(a:comment, '<br>'), 1)
        \}

        call extend(b:review_comments[l:comment_id], repoman#utils#GetDiffPosition(
            \b:review_lookup[a:review_data.cursor_start],
            \b:review_lookup[a:review_data.cursor]))

        " Reverse and shift the review buffer contents and insert the new
        " comment contents below the cursor position
        let l:line_nr = line('$')
        let l:comment_lines = len(a:comment) - 1
        while l:line_nr > 0
            if l:line_nr > a:review_data.cursor
                let b:review_lookup[l:line_nr + len(a:comment)] = b:review_lookup[l:line_nr]
                call setline(l:line_nr + len(a:comment), getline(l:line_nr))
            endif

            if l:line_nr > a:review_data.cursor &&
                \l:line_nr <= a:review_data.cursor + len(a:comment)
                if l:comment_lines >= 0
                    call setline(
                        \l:line_nr,
                        \s:ui.buffer_comment . a:comment[l:comment_lines]
                    \)
                    call remove(b:review_lookup, l:line_nr)
                    let b:review_comment_lookup[l:line_nr] = l:comment_id
                    let l:comment_lines -= 1
                endif
            endif

            let l:line_nr -= 1

            " Check to see if we're done shifting the contents
            if l:line_nr < a:review_data.cursor
                break
            endif
        endwhile
        set nomodifiable
    endfunction

    " =====================================================================
    " Comments
    " =====================================================================

    " Create a buffer for a comment
    "
    " Args:
    " - none
    "
    " Returns:
    " - none
    function! state.CreateCommentBuffer(start_line, line) abort
        set splitbelow
        let l:curpos = getcurpos()[1]
        let l:review_lookup = exists('b:review_lookup') ? deepcopy(b:review_lookup) : {}

        call OpenBuffer(s:constants.buffers.comment, -1, self)
        "call WriteLine(s:strings.comment_help)
        call FinishOutput()

        " Set review data, if applicable
        if len(l:review_lookup)
            let b:review_data = l:review_lookup[l:curpos]
            let b:review_data.cursor_start = a:start_line
            let b:review_data.cursor = a:line
        endif

        " Re-enable modifiable so that we can write something
        set modifiable
        nnoremap <buffer> <C-p> :call repoman#RepoManPost()<CR>
    endfunction

    function! state.CreateReplyBuffer(parent_id, line) abort
        call self.CreateCommentBuffer(a:line, a:line)
        let b:parent_id = a:parent_id
    endfunction

    " Create a buffer for editing the comment
    "
    " Args:
    " - comment: a json object representing the current comment
    "
    " Returns:
    " - none
    function! state.EditCommentBuffer(comment) abort
        set splitbelow
        let l:curpos = getcurpos()[1]
        if exists('b:review_comment_lookup')
            let l:comment_id = b:review_comment_lookup[l:curpos]
            let l:cursor_start = b:review_comments[l:comment_id]['cursor_start']
            let l:cursor = b:review_comments[l:comment_id]['cursor']
        endif
        let l:review_lookup = exists('b:review_lookup') ? deepcopy(b:review_lookup) : {}

        call OpenBuffer(s:constants.buffers.edit, -1, self)

        let l:body = repoman#utils#SanitizeText(a:comment.body)
        let b:body = l:body
        for chunk in split(substitute(l:body, '<br>' , '\n', 'ge'), '\\n')
            call WriteLine(chunk)
        endfor
        call FinishOutput()

        " Set review data, if applicable
        if len(l:review_lookup)
            let b:review_data = l:review_lookup[l:cursor]
            let b:review_data.cursor_start = l:cursor_start
            let b:review_data.cursor = l:cursor
        endif

        let b:edit_values = deepcopy(a:comment)
        let b:edit_values.edit = 'comment'

        set modifiable
        nnoremap <buffer> <C-p> :call repoman#RepoManPost()<CR>
    endfunction

    function! state.CreateSuggestionBuffer(code, start_line, line) abort
        call self.CreateCommentBuffer(a:start_line, a:line)
        call WriteLine('```suggestion')
        for line in a:code
            call WriteLine(line)
        endfor
        call WriteLine('```')
    endfunction

    " =====================================================================
    " Labels
    " =====================================================================

    " Create a buffer to pick labels for an issue/pr/etc
    "
    " Args:
    " - contents: a json array of the available labels, filtered beforehand to
    "   add the "active" field for active labels
    "
    " Returns:
    " - none
    function! state.CreateLabelsBuffer(contents) abort
        set splitbelow
        call OpenBuffer(s:constants.buffers.labels, -1, self)

        let b:jump_guide = [1]
        for label in a:contents
            let l:toggle = '[ ] '
            if has_key(label, 'active')
                let l:toggle = '[x] '
            endif
            let l:label_idx = WriteLine(l:toggle . label['name'])
            if l:label_idx % 2
                call add(b:jump_guide, l:label_idx)
            endif
            call WriteLine('    ' . label['description'])
        endfor

        nnoremap <buffer> <silent> <CR> :call ToggleLabel()<cr>

        call FinishOutput()
    endfunction


    " Toggle labels as active/inactive for the current issue/pr/etc
    "
    " Args:
    " - none
    "
    " Returns:
    " - none
    function! ToggleLabel() abort
        set modifiable

        let l:line = getline(getcurpos()[1])
        if stridx(l:line, '[x]') == 0
            let l:line = substitute(l:line, '\[x\]', '\[ \]', '')
        else
            let l:line = substitute(l:line, '\[ \]', '\[x\]', '')
        endif

        call setline(getcurpos()[1], l:line)
        set nomodifiable
    endfunction

    return state
endfunction

