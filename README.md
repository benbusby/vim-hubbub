# Vissues

### Setup
- Vundle: `Plugin 'benbusby/vissues'`

- Set up authentication
  - Create a personal access token with the "repo" box checked
  - Encrypt this token on your machine with the following command:
    - `echo "<paste token here>" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out <output file name>`
      - You'll be prompted for a password to encrypt this token
    - Example: `echo "abcdefghij123456789" | openssl enc -e -aes-256-cbc -a -pbkdf2 -salt -out /home/ben/.vissues-token-gh`
  - Copy your username and token path into your .bashrc, .zshrc, etc
    ```bash
    # For github repos
    export VISSUES_USERNAME_GH="<github username>"
    export VISSUES_TOKEN_GH="<github token location>"

    # For gitlab repos
    export VISSUES_USERNAME_GL="<gitlab username>"
    export VISSUES_TOKEN_GL="<gitlab token location>"
    ```
    - Example:
      ```bash
      export VISSUES_USERNAME_GH="benbusby"
      export VISSUES_TOKEN_GH="/home/benbusby/.vissues-token-gh"
      ```

### Usage
#### Available Commands
- `:VissuesOpen` -> Opens the list of issues for the current repository
  - You will be prompted for the password used to encrypt the token file here
- `:VissuesBack` -> When in an issue view, navigates back to the list of issues
- `:VissuesExit` -> Closes all issue/results buffers
