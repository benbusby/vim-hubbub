# vimgmt

### Setup
- Vundle: `Plugin 'benbusby/vimgmt'`

- Set up authentication
  - Create a personal access token with the "repo" box checked
  - Encrypt this token on your machine with the following command:
    - `echo "<paste token here>" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out <output file name>`
      - You'll be prompted for a password to encrypt this token
    - Example: `echo "abcdefghij123456789" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out /home/ben/.vimgmt-token-gh`
  - Copy your username and token path into your .bashrc, .zshrc, etc
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
      ```

### Usage
#### Available Commands
- `:Vimgmt` -> Opens the list of issues for the current repository
  - You will be prompted for the password used to encrypt the token file here
- `:VimgmtBack` -> When in an issue view, navigates back to the list of issues
- `:VimgmtExit` -> Closes all issue/results buffers

### Manual Build (vimball)
1. Using vim, open `vimball-build.txt`
2. Run `:let g:vimball_home="<full repo path>"`
3. Select all lines (`ggVG`)
4. Run `:MkVimball <name>`
5. Exit from `vimball-build.txt`
6. Open the new vmb file in vim and run `:source %`

This should now install the plugin in the correct directory.

To remove, run `:RmVimball <vmb file>`

### FAQ
##### Why is it called "vimgmt"? How is it pronounced?
It's supposed to be (kind of) a portmantaeu of the words "vim" and "mgmt" (the common abbreviation for "management"). It's used for managing a repo within vim, so it made sense. It's pronounced "vim-gee-em-tee" or "vimagement", whichever you prefer.

##### Why did you make this?
I use vim a lot, so I wanted to try out/learn vimscript by making something (marginally) useful.
