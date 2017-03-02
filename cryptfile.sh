#!/bin/bash

readonly VERSION='1.0'

readonly DEFAULT_PASSWORDFILE_PATH="${HOME}/cryptfile.pass"

readonly TEMP_PATH="/dev/shm/cryptfile${RANDOM}"

readonly REQUIRE_EXTENSION=".enc"

VAR_ENCRYPT=0
VAR_DECRYPT=0

VAR_PASSWORD=""
VAR_PASSWORDFILE=""
VAR_DIR=""
VAR_BASE=""
VAR_FILE=""

VAR_INPUTFILE=""
VAR_OUTPUTFILE=""
echo ""

usage() {
	echo ""
	echo "cryptfile [OPTIONS] FILENAME  - Decrypts the file, opens it in nano, encrypts it afterwards"
	echo ""
	echo "Options:"
	echo "Will assume there is a password file with permission 600 in homedir/cryptfile.pass"
	echo "--encrypt                     - Only encrypts FILENAME to FILENAME.enc"
	echo "--decrypt                     - Only decrypts FILENAME if it ends with .enc to FILENAME without .enc"
	echo "--pass-file FILENAME          - Uses the password stores in FILENAME with gpg instead of default path"
	echo "--pass-prompt                 - Prompts for password instead of using a file for it"
}

# Check that we have nano and gpg
command -v nano >/dev/null 2>&1 || { echo >&2 "I require nano but it's not installed. Aborting."; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo >&2 "I require gpg but it's not installed. Aborting."; exit 1; }

# No arguments provided
if [ "$#" -eq 0 ]; then
	usage
	exit 1
fi

# parse command line options
while [[ "$1" != '' ]]
do
	case $1 in
		-pf | --pass-file)
			VAR_PASSWORDFILE=$2
			shift
			;;
		-pp | --pass-prompt)
			VAR_PASSWORDPROMPT=1
			;;
		--encrypt)
			VAR_ENCRYPT=1
			;;
		--decrypt)
			VAR_DECRYPT=1
			;;
		*)
			VAR_FILE=$1
			;;
	esac
	shift
done

check_passwordprompt() {
	if [[ "$VAR_PASSWORDPROMPT" -eq 1 ]]; then
		read -p "Password: " VAR_PASSWORD; echo
	fi
}

check_passwordfile() {
	if [[ -z "$VAR_PASSWORDFILE" ]]; then
		VAR_PASSWORDFILE=$DEFAULT_PASSWORDFILE_PATH
	fi

	if [ ! -f "$VAR_PASSWORDFILE" ]; then
		echo "Password file ${VAR_PASSWORDFILE} could not be found"
		exit 1
	fi

	PERMISSION=`find ${VAR_PASSWORDFILE} -prune -printf '%m\n'`
	
	if [ $PERMISSION != "600" ]; then
		echo "Incorrect permissions on password file. Set them to 600";
		exit 1
	fi

	VAR_PASSWORD=`cat ${VAR_PASSWORDFILE}`

	if [ -z "$VAR_PASSWORD" ]; then
		echo "Couldn't find any valid password in the password file"
		exit 1
	fi
}

check_password() {
	check_passwordprompt

	if [[ -z "$VAR_PASSWORD" ]]; then
		check_passwordfile
	fi

	if [[ -z "$VAR_PASSWORD" ]]; then
		echo "No password provided"
		exit 1
	fi

	# Trim whitespaces
	VAR_PASSWORD=`echo ${VAR_PASSWORD} | xargs`
}

# Check that the user either asks for a prompt, or provides a filename for the password, or 
# has setup the default file with a password
check_password

if [[ ! -f $VAR_FILE ]]; then
	echo "File not found"
	exit 1
fi

# Extract out the directory and the file name
VAR_DIR="$(dirname "${VAR_FILE}")/"
VAR_BASE=$(basename "${VAR_FILE}")

require_extension() {
	LENGTH=${#REQUIRE_EXTENSION}
	EXTENSION=${VAR_FILE: -${LENGTH}}
	if [[ $EXTENSION != $REQUIRE_EXTENSION ]]; then
		echo "Extension .enc missing on the file"
		exit 1
	fi
}

edit_file() {
	require_extension
	echo "Storing tmp file in ${TEMP_PATH}"
	echo $VAR_PASSWORD | gpg --passphrase-fd 0 --output $TEMP_PATH --decrypt $VAR_FILE
	VALPRE=$(<$TEMP_PATH)

	nano $TEMP_PATH
	if [[ $? -ne 0 ]]; then
		echo "Nano exited with an error. File has not been re-encrypted. The tmp file is still available."
		exit 1
	fi

	VALPOST=$(<$TEMP_PATH)

	if [[ $VALPRE == $VALPOST ]]; then
		rm -f $TEMP_PATH
		echo "Nothing changed, hence nothing to do.. Done"
		exit 0
	fi

	VAR_INPUTFILE=$TEMP_PATH
	VAR_OUTPUTFILE=$VAR_FILE
	encrypt_file
	rm -f $TEMP_PATH
	echo "File edited and re-encrypted. Done"
	exit 0
}

encrypt_file() {
	# --batch = do not prompt (overwrite), --yes = answer yes
	echo $VAR_PASSWORD | gpg -q --batch --yes --passphrase-fd 0 --output ${VAR_OUTPUTFILE} --symmetric --cipher-algo AES256 ${VAR_INPUTFILE}
	if [[ $? -ne 0 ]]; then
		echo "Something failed during encryption"
		exit 1
	fi
}

decrypt_file() {
	echo $VAR_PASSWORD | gpg --passphrase-fd 0 --output $VAR_OUTPUTFILE --decrypt $VAR_INPUTFILE
}

if [ "$VAR_ENCRYPT" -eq 0 ] && [ "$VAR_DECRYPT" -eq 0 ]; then
	edit_file
	exit 0
elif [ "$VAR_ENCRYPT" -eq 1 ]; then
	VAR_INPUTFILE=$VAR_FILE
	VAR_OUTPUTFILE="${VAR_FILE}${REQUIRE_EXTENSION}"
	encrypt_file
	echo "Done"
	exit 0
elif [ "$VAR_DECRYPT" -eq 1 ]; then
	require_extension
	VAR_INPUTFILE=$VAR_FILE
	LENGTH=${#REQUIRE_EXTENSION}
	VAR_OUTPUTFILE=${VAR_FILE::-${LENGTH}}
	decrypt_file
	if [[ $? -ne 0 ]]; then
        	echo "A problem occured decrypting the file"
        	exit 1
	fi
	echo "File decrypted. Done."
	exit 0
fi
