# hubbub.vim

[![vint](https://github.com/benbusby/vim-hubbub/workflows/vint/badge.svg)](https://github.com/benbusby/vim-hubbub/actions?query=workflow%3Avint)
[![vader](https://github.com/benbusby/vim-hubbub/workflows/vader/badge.svg)](https://github.com/benbusby/vim-hubbub/actions?query=workflow%3Avader)

Create and modify GitHub issues, pull requests, comments, code reviews, and much more while using Vim.

## Table of Contents
- [Features](#features)
- [Dependencies](#dependencies)
- [Install](#install)
- [Setup](#setup)
- [Usage](#usage)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [Miscellaneous](#miscellaneous)
- [Screenshots](#screenshots)

## Features
Hubbub supports a wide variety of features and GitHub API interactions, including:

- Viewing/creating/editing/closing issues and pull requests
- Commenting on and reacting to issues and pull requests
- Reacting to issues and comments
- Labeling issues and PRs
- Creating and submitting PR reviews
    - Includes multi-line comment and suggestion support, as well as replying to existing review comments
- An intuitive multi-buffer layout
- Quick setup process
- Code block syntax highlighting
- Integration with your Vim theme
- Support for alternative interface languages
    - See [the hubbub wiki config page](https://github.com/benbusby/vim-hubbub/wiki/Configuration#appearanceui) for details
    - Straightforward process for [contributing new translations](#interface-translations)
- Simple keybindings for quickly navigating issues/repos/etc
- And more -- please refer to [the hubbub wiki](https://github.com/benbusby/vim-hubbub/wiki) for a comprehensive list of features and guides for using the plugin.

## Dependencies
- `vim` >= 8.0 / `neovim`
- `curl`
- `openssl`
  - For OpenSSL < 1.1.1 or LibreSSL < 2.9.1, `let g:hubbub_openssl_old = 1` needs to be included in your `.vimrc`
  - Not required if a password is not used to encrypt your personal access token

## Install
#### Vundle
`Plugin 'benbusby/vim-hubbub'`
#### vim-plug
`Plug 'benbusby/vim-hubbub'`
#### DIY
  1. Clone the repo to your vim plugin directory
      - Ex: `git clone https://github.com/benbusby/vim-hubbub.git ~/.vim/bundle/vim-hubbub`
  2. Ensure the plugin's path is included in your Vim runtime path
      - Ex: `:set rtp+=~/.vim/bundle/vim-hubbub`

## Setup
1. Create a GitHub personal access token
    - Settings > Developer Settings > Personal Access Tokens
    - Generate new token with the "repo" box checked
2. After installing vim-hubbub, run `:HubbubInit`
    - You will be prompted for your token(s) and a password to encrypt them
    - Note: A password is recommended, but not required

## Usage

For information and comprehensive guides on how to use the plugin, please refer to [the hubbub wiki](https://github.com/benbusby/vim-hubbub/wiki)

See also [configuration](https://github.com/benbusby/vim-hubbub/wiki/Configuration) and [keybindings](https://github.com/benbusby/vim-hubbub/wiki/Keybindings) in the wiki.

For the hubbub docs, please refer to `:h hubbub`

## Configuration

A full list of the available (optional) global variables for hubbub are located [here](https://github.com/benbusby/vim-hubbub/wiki/Configuration)

<hr>
  
Example `.vimrc` settings:
```vim
" Defaults
let g:hubbub_language = 'en'
let g:hubbub_show_outdated = 0
let g:hubbub_openssl_old = 0
```

```vim
" French, show outdated, use short command alternatives
let g:hubbub_language = 'fr'
let g:hubbub_show_outdated = 1
let g:hubbub_short_commands = 1
```

```vim
" Spanish, use older OpenSSL, show footer
let g:hubbub_language = 'es'
let g:hubbub_openssl_old = 1
let g:hubbub_footer = 1
```

## Contributing

Any type of contribution is welcome and appreciated, whether its just using the plugin and validating that the available features work as expected, implementing features or bug fixes, or expanding on the vader tests.

The project has the following general structure:

```
├── assets/
│   ├── header.txt          # The "header" that appears on nearly every page in the UI 
│   ├── img/
│   ├── response_keys.json  # A combined json mapping of GitHub and GitLab response keys
│   └── strings.json        # Translations/UI strings
├── autoload/
│   ├── hubbub/            # Utilities and helper classes (API, crypto, buffers, etc)
│   └── hubbub.vim         # User command implementations and hooks into API/buffer calls
├── doc/
│   └── hubbub.txt         # Hubbub documentation
├── LICENSE
├── plugin/
│   └── hubbub.vim         # A "header file" of all user accessible plugin commands
├── README.md
└── test/
    └── hubbub.vader       # Plugin tests
```

#### GitLab Support
If you're interested in contributing to GitLab support, the main file you'll want to edit is `autoload/hubbub/gitlab.vim`. It will likely involve a decent amount of work to match feature functionality between GitHub and GitLab, but I'm happy with even small, incremental PRs.

To set up a hubbub token on GitLab:
    - Settings > Access Tokens
    - Generate new token with the "api", "read_repository" and "write_repository" boxes checked

#### Interface Translations
If you would like to improve the UI translation support, please edit [assets/strings.json](assets/strings.json) accordingly and create a new PR with your changes.

Note that the existing languages have certain sections formatted to align cleanly in the repo and issue list views. Please try to conform to this alignment when adding/editing existing translations.

## Miscellaneous

The plugin is currently in a usable state, but is still a work in progress. If you experience any unexpected behavior, please open an issue.

At the moment, there are quite a few GitHub features that are either only partially implemented or are entirely absent from the plugin. If you're a GitHub "power user", then this plugin is likely not ready for you, as it is currently lacking features like:

- Using issue/PR templates for new issues/PRs
- Adding/removing assignees for issues/PRs
- Milestones
- Filtering issues by any criteria
- Merging PRs with a custom commit message
- Probably quite a few others

The project started as a fun way for me to learn Vimscript, and was initially built for replying to comments on GitHub. It eventually snowballed into its current form, which I find to be somewhat useful as a quick and easy way to manage issues, reply to comments, review (small) PRs, etc.

## Screenshots

#### Issue View
![Example Issue View](https://raw.githubusercontent.com/wiki/benbusby/vim-hubbub/images/ss_issue.png)


#### PR View
![Example PR View](https://raw.githubusercontent.com/wiki/benbusby/vim-hubbub/images/ss_pr.png)


#### Demo GIF
![Demo Gif](https://raw.githubusercontent.com/wiki/benbusby/vim-hubbub/images/hubbub.gif)
