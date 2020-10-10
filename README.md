# vimgmt

### Requirements
- [jq](https://stedolan.github.io/jq/download/)

### Install
- Vundle: `Plugin 'benbusby/vimgmt'`
- vim-plug: `Plug 'benbusby/vimgmt'`
- [DIY](#manual-build-vimball)

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
3. Copy your username and token path into your .bashrc, .zshrc, etc
    ```bash
    # For github repos
    export VIMGMT_USERNAME_GH="<github username>"
    export VIMGMT_TOKEN_GH="<github token location>"

    # For gitlab repos
    export VIMGMT_USERNAME_GL="<gitlab username>"
    export VIMGMT_TOKEN_GL="<gitlab token location>"
    ```
    - Example:
      ```bash
      export VIMGMT_USERNAME_GH="benbusby"
      export VIMGMT_TOKEN_GH="/home/benbusby/.vimgmt-token-gh"

      export VIMGMT_USERNAME_GL="benbusby"
      export VIMGMT_TOKEN_GL="/home/benbusby/.vimgmt-token-gl"
      ```

### Usage
#### Available Commands
- `:Vimgmt` -> Opens the list of issues/pull requests for the current repository
  - You will be prompted for the password used to encrypt the token file here
- `:VimgmtBack` -> When in an issue view, navigates back to the list of issues
- `:VimgmtExit` -> Closes all issue/results buffers

### Manual Build (vimball)
1. Clone the repo
2. Using vim, open `vimball-build.txt`
3. Run `:let g:vimball_home="<full repo path>"`
4. Select all lines (`ggVG`)
5. Run `:MkVimball <name>`
6. Exit from `vimball-build.txt`
7. Open the new vmb file in vim and run `:so %`

This should now install the plugin in the correct directory.

To remove, run `:RmVimball <vimball name>` (example: `:RmVimball vimgmt`)

### FAQ
##### Why is it called "vimgmt"? How is it pronounced?
It's supposed to be (kind of) a portmantaeu of the word "vim" and and the abbreviation for "management", mgmt. It's used for managing a repo within vim, so it made sense. It's pronounced "vim-gee-em-tee" or "vimagement", whichever you prefer.

##### Why does the repo token need to be encrypted? Will vimgmt work if the token is unencrypted?
The alternative would be setting the token value in a file (unencrypted) in a reliable place that vimgmt could always find, meaning that any other program could find the token if you used vimgmt. Encrypting the token, even with a weak password, makes a lot more sense.

Storing the token unencrypted will not work. The token decryption process is a mandatory step that is built into vimgmt.

##### Why did you make this?
I use vim a lot, so I wanted to try out/learn vimscript by making something (marginally) useful.

