# vim-repoman [![CI](https://github.com/benbusby/vim-repoman/workflows/CI/badge.svg?branch=main)](https://github.com/benbusby/vim-repoman/actions)

repo(sitory) man(ager) - Create and manage GitHub issues, pull requests, code reviews, and more using Vim.

## Table of Contents
- [Dependencies](#dependencies)
- [Install](#install)
- [Setup](#setup)
- [Usage](#usage)

___

### Dependencies
- curl
- openssl
  - *Note: For OpenSSL < 1.1.1 or LibreSSL < 2.9.1, `g:repoman_openssl_old` must be added to your .vimrc*

### Install
- Vundle: `Plugin 'benbusby/vim-repoman'`
- vim-plug: `Plug 'benbusby/vim-repoman'`
- DIY
  1. Clone the repo to your vim plugin directory
    - Ex: `git clone https://github.com/benbusby/vim-repoman.git ~/.vim/bundle/vim-repoman`
  2. Update your runtime path in your .vimrc file
    - Ex: `:set rtp+=~/.vim/bundle/vim-repoman`

### Setup
1. Create a personal access token
  - GitHub
    - Settings > Developer Settings > Personal Access Tokens
    - Generate new token with the "repo" box checked
  - GitLab (In Progress)
    - Settings > Access Tokens
    - Generate new token with the "api", "read_repository" and "write_repository" boxes checked
2. After installing vim-repoman, run `:RepoManInit`
  - You will be prompted for your token(s) and a password to encrypt them

### Configuration
#### (Optional) Global Variables
There are a few additional variables you can include in your `.vimrc` file to tweak vim-repoman to your preference:

- `g:repoman_show_outdated` - Enables/disables showing outdated comments on pull requests
  - `0`: (Default) Disabled
  - `1`: Enabled
- `g:repoman_language` - Sets the language for the plugin UI
  - `en`: (Default) English
  - `es`: Spanish
  - `fr`: French
  - `cn_sm`: Chinese (Simplified)
  - `cn_tr`: Chinese (Traditional)

### Usage
#### Available Commands
- `:RepoMan`
  - Opens the list of issues/pull requests for the current repository
    - Can also be used to refresh the current view
  - Note: You will be prompted for the password used to encrypt the token file here
- `:RepoManBack`
  - When in an issue/page view, this navigates back to the home page
- `:RepoManComment`
  - Opens a new buffer for writing a comment on the current issue/PR/MR
- `:RepoManPost`
  - Posts the contents of the comment buffer to the current issue/PR/MR
- `:RepoManClose`
  - Closes the current issue/PR/etc.
