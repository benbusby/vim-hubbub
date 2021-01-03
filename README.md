![Repoman Banner](assets/img/repoman-banner.png)

[![vint](https://github.com/benbusby/vim-repoman/workflows/vint/badge.svg)](https://github.com/benbusby/vim-repoman/actions?query=workflow%3Avint)
[![vader](https://github.com/benbusby/vim-repoman/workflows/vader/badge.svg)](https://github.com/benbusby/vim-repoman/actions?query=workflow%3Avader)

#### (repo)sitory (man)ager:

Create and manage GitHub/GitLab issues, pull requests, code reviews, and more using Vim.

![Demo Gif](assets/img/home-demo.gif)

## Table of Contents
- [Features](#features)
- [Dependencies](#dependencies)
- [Install](#install)
- [Setup](#setup)
- [Usage](#usage)
- [Configuration](#configuration)

## Features
vim-repoman supports the following features:

#### Issues
Action | GitHub | GitLab
--- | --- | ---
View | :heavy_check_mark: | :heavy_check_mark:
Create | :heavy_check_mark: | :heavy_check_mark:
Comment | :heavy_check_mark: | :heavy_check_mark:
Label | :heavy_check_mark: | :no_entry_sign:
Delete | :heavy_check_mark: | :heavy_check_mark:

#### Comments
Action | GitHub | GitLab
--- | --- | ---
React* | :heavy_check_mark: | :no_entry_sign:
Reply | :heavy_check_mark: | :no_entry_sign:
Edit | :heavy_check_mark: | :no_entry_sign:
Delete | :heavy_check_mark: | :no_entry_sign:

<sup>* 👍, 👎, 👀, etc.</sup>

#### Pull Requests / Merge Requests
Action | GitHub | GitLab
--- | --- | ---
Create | :heavy_check_mark: | :heavy_check_mark:
View | :heavy_check_mark: | :heavy_check_mark:
Review* | :heavy_check_mark: | :no_entry_sign:
Comment | :heavy_check_mark: | :heavy_check_mark:
Merge** | :heavy_check_mark: | :heavy_check_mark:
Delete | :heavy_check_mark: | :heavy_check_mark:

<sup>* PR/MR review supports inserting comments on a line (or multiple lines) of code in review<br>** Includes merge commits, as well as squash and rebase merges.</sup>

#### Other
    
The plugin's interface supports multiple languages ([see Configuration](#configuration)), with a simple process for adding translations.

## Dependencies
- `vim` >= 8.0 / `neovim`
- `curl`
- `openssl`
  - *Note: For OpenSSL < 1.1.1 or LibreSSL < 2.9.1, `let g:repoman_openssl_old = 1` must be added to your `.vimrc`*

## Install
#### Vundle
`Plugin 'benbusby/vim-repoman'`
#### vim-plug
`Plug 'benbusby/vim-repoman'`
#### DIY
  1. Clone the repo to your vim plugin directory
      - Ex: `git clone https://github.com/benbusby/vim-repoman.git ~/.vim/bundle/vim-repoman`
  2. Update your runtime path in your .vimrc file
      - Ex: `:set rtp+=~/.vim/bundle/vim-repoman`

## Setup
1. Create a personal access token
    - GitHub
      - Settings > Developer Settings > Personal Access Tokens
      - Generate new token with the "repo" box checked
    - GitLab (In Progress)
      - Settings > Access Tokens
      - Generate new token with the "api", "read_repository" and "write_repository" boxes checked
2. After installing vim-repoman, run `:RepoManInit`
    - You will be prompted for your token(s) and a password to encrypt them

## Usage
#### Vim Commands
Vim Command | Action | Notes
--- | --- | --- |
`:RepoManInit` | Initializes the plugin | 
`:RepoMan` | **If in a git repo:**<br>Opens a list of issues/PRs if in a git repo.<br>**If not in a git repo:**<br>Opens a list of repositories for the user | *Will prompt for token password*
`:RepoManComment` | Open a comment buffer for the current issue |
`:RepoManLabel` | View/update labels for the current issue |
`:RepoManPost` | Posts an update to the issue | *Works for <br>`:RepoManComment` and <br>`:RepoManLabel` buffers*
`:RepoManNew <type>` | Create a new issue or PR | *`type` can be "issue" or "pr"*
`:RepoManClose` | Closes the current issue | 

#### Keyboard Shortcuts
Keyboard Shortcut | Action | Notes
--- | --- | --- |
`<Enter>` | Open the selected repository or issue | *Current repo/issue is determined by cursor line position*
`<Backspace>` or `gi` | Navigates back to the issue/repo list | 
`J` and `K` | Jumps between issues/repositories in the list | `J`: next item<br>`K`: prev item
`H` and `L` | Navigates between pages of issues/repositories |`H`: prev page<br>`L`: next page 

## Configuration
#### (Optional) Global Variables
There are a few additional variables you can include in your `.vimrc` file to tweak vim-repoman to your preference:

- `g:repoman_show_outdated` - Show/hide outdated diffs and comments on pull requests
  - `0`: (Default) Disabled
  - `1`: Enabled
- `g:repoman_language` - Set the language for the plugin UI
  - `en`: (Default) English
  - `es`: Spanish
  - `fr`: French
  - `cn_sm`: Chinese (Simplified)
  - `cn_tr`: Chinese (Traditional)
- `g:repoman_default_host` - Set the default host to prefer if outside of a git repo
  - `'github'`: Use GitHub as primary
  - `'gitlab'`: Use GitLab as primary
  - *Note: This only needs to be set if you set both GitHub and GitLab tokens*
- `g:repoman_openssl_old` - Rely on commands that work with older versions of OpenSSL / LibreSSL
  - `0`: (Default) Disabled
  - `1`: Enabled
- `g:repoman_footer` - Include/exclude the vim-repoman footer from comments/issues
  - `0`: Exclude
  - `1`: (Default) Include
- `g:repoman_emojis` - Show/hide emoji reactions on issues and comments
  - `0`: Hide (use ascii alternatives)
  - `1`: (Default) Show emojis
  
Example `.vimrc` settings:
```vim
" Defaults
let g:repoman_language = 'en'
let g:repoman_show_outdated = 0
let g:repoman_openssl_old = 0
```

```vim
" French, show outdated, use GitLab by default
let g:repoman_show_outdated = 1
let g:repoman_language = 'fr'
let g:repoman_default_host = 'gitlab'
```

```vim
" Spanish, use older OpenSSL, hide footer 😢
let g:repoman_language = 'es'
let g:repoman_openssl_old = 1
let g:repoman_footer = 0
```
