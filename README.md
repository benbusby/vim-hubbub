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
- `:vimgmt` -> Opens the list of issues for the current repository
  - You will be prompted for the password used to encrypt the token file here
- `:vimgmtBack` -> When in an issue view, navigates back to the list of issues
- `:vimgmtExit` -> Closes all issue/results buffers

### Manual Build (vimball)
1. Using vim, open `vimball-build.txt`
2. Run `:let g:vimball_home="<full repo path>"`
3. Select all lines (`ggVG`)
4. Run `:MkVimball <name>`
5. Exit from `vimball-build.txt`
6. Open the new vmb file in vim and run `:source %`

This should now install the plugin in the correct directory.

To remove, run `:RmVimball <vmb file>`

