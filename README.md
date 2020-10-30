# vimgmt [![CI](https://github.com/benbusby/vimgmt/workflows/CI/badge.svg?branch=main)](https://github.com/benbusby/vimgmt/actions)

## Table of Contents
- [Requirements](#requirements)
- [Install](#install)
- [Setup](#setup)
- [Usage](#usage)
- [FAQ](#faq)

___

### Requirements
- [jq](https://stedolan.github.io/jq/download/)
- curl

### Install
- Vundle: `Plugin 'benbusby/vimgmt'`
- vim-plug: `Plug 'benbusby/vimgmt'`
- DIY
  1. Clone the repo to your vim plugin directory
    - Ex: `git clone https://github.com/benbusby/vimgmt.git ~/.vim/bundle/vimgmt`
  2. Update your runtime path in your .vimrc file
    - Ex: `:set rtp+=~/.vim/bundle/vimgmt`

### Setup
1. Create a personal access token
  - GitHub
    - Settings > Developer Settings > Personal Access Tokens
    - Generate new token with the "repo" box checked
  - GitLab
    - Settings > Access Tokens
    - Generate new token with the "api", "read_repository" and "write_repository" boxes checked
2. Encrypt this token on your machine with the following command:
  - `echo "<paste token here>" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out <output file name>`
    - You'll be prompted for a password to encrypt this token
  - Example: `echo "abcdefghij123456789" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out /home/ben/.vimgmt-token-gh`
3. Copy your token path into your .bashrc, .zshrc, etc
    ```bash
    # For github repos
    export VIMGMT_TOKEN_GH="<github token location>"

    # For gitlab repos
    export VIMGMT_TOKEN_GL="<gitlab token location>"
    ```
    - Example:
      ```bash
      export VIMGMT_TOKEN_GH="/home/benbusby/.vimgmt-token-gh"
      export VIMGMT_TOKEN_GL="/home/benbusby/.vimgmt-token-gl"
      ```

### Configuration
#### Global Variables
##### Required
Todo? Could replace bashrc changes for global vimrc variables instead.

##### Optional
There are a few additional variables you can include in your `.vimrc` file to tweak Vimgmt to your preference:

- `g:vimgmt_show_outdated` - Enables/disables showing outdated comments on pull requests
  - `0`: (Default) Disabled
  - `1`: Enabled
- `g:vimgmt_language` - Sets the language for Vimgmt
  - `en`: (Default) English
  - `es`: Spanish
- `g:vimgmt_include_footer` - Enables/disables the "Posted with Vimgmt" footer for comments/issues
  - `0`: (Default) Disabled
  - `1`: Enabled
- `g:vimgmt_token` - Stores the value of your GitHub API token (not recommended!)
  - Ex: `let g:vimgmt_token="abcdefg1234567"`
  - Be advised that storing your token in plaintext as a global variable in your `.vimrc` file means that any other Vim plugin can read your token

### Usage
#### Available Commands
- `:Vimgmt`
  - Opens the list of issues/pull requests for the current repository
    - Can also be used to refresh the current view
  - Note: You will be prompted for the password used to encrypt the token file here
- `:VimgmtBack`
  - When in an issue/page view, this navigates back to the home page
- `:VimgmtComment`
  - Opens a new buffer for writing a comment on the current issue/PR/MR
- `:VimgmtPost`
  - Posts the contents of the comment buffer to the current issue/PR/MR
- `:VimgmtClose`
  - Closes the current issue/PR/etc.

### FAQ
##### Why is it called "vimgmt"? How is it pronounced?
It's supposed to be (kind of) a portmantaeu of the word "vim" and and the abbreviation for "management", mgmt. It's used for managing a repo within vim, so it made sense. It's pronounced "vim-gee-em-tee" or "vimagement", whichever you prefer.
