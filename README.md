# cryptfile
Encrypts, decrypts and edits encrypted files using GPG.

Primarly used to encrypt sensitive information such as passwords and API keys so it can be commited to source code repositories.

Requirements:
- Bash v4.2+
- Nano
- GPG

Tested on:
- Ubuntu 12+
- Cygwin
- OS X

Installation:
```
chmod +x cryptfile.sh
```

Usage:
```
./cryptfile.sh
-> Will show available commands

./cryptfile.sh FILENAME
-> Will decrypt, edit (nano) and then encrypt upon save

./cryptfile.sh --pass-prompt FILENAME
-> As above, but prompt for a password

./cryptfile.sh --pass-file FILENAMEPASSWORD FILENAMEEDIT
-> As above, use password in FILENAMEPASSWORD file to edit FILENAMEEDIT

./cryptfile.sh --encrypt FILENAME
-> Encrypts FILENAME to FILENAME.enc

./cryptfile.sh --decrypt FILENAME.enc
-> Decrypts FILENAME.enc to FILENAME

```

A password file can be placed in $HOME/cryptfile.pass. If present, that password will be used to encrypt/decrypt any provided files. Then there is no need for --pass-prompt or --pass-file. Password files must have permission 600.


