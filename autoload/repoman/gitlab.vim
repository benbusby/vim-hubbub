let s:gitlab_api = 'https://gitlab.com/api/v4/projects/'
let s:project_id = ''

function! repoman#gitlab#ViewAll(repoman) abort
    if empty(s:project_id)
        let l:encoded_path = substitute(repoman#utils#GetRepoPath(), '/', '%2F', 'ge')
        let s:project_id = json_decode(system(repoman#request#Send(
            \repoman#utils#ReadGitLabToken(a:repoman.token_pw),
            \s:gitlab_api . l:encoded_path, {}, '')))['id']
    endif

    return system(repoman#request#Send(
        \repoman#utils#ReadGitLabToken(a:repoman.token_pw),
        \s:gitlab_api . s:project_id . '/issues?state=opened',
        \{}, ''))
endfunction
