default:
	just --list

[group('SYSTEM')]
all:
	just brew
	just update

[group('SYSTEM')]
brew:
	zsh ./brew.sh

[group('SYSTEM')]
install:
	zsh ./install.sh

[group('SYSTEM')]
update:
	git pull
	bun upgrade
	deno upgrade
	gcloud components update --quiet
	rustup update
	brew update
	brew upgrade
	zsh ./brew.sh

	# Node/ nvm
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install 20
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install 22
alias up := update

[group('SYSTEM')]
install-nix:
	# see https://nixos.org/download/
	sh <(curl -L https://nixos.org/nix/install)

# create a new age encryption key into a given filename
[group('ENCRYPTION')]
create-age-key name="key":
	age-keygen -o "{{name}}.txt"
	just create-public-key "{{name}}"
	just age-key-to-1password "{{name}}"

# create a public key from a given age key
[confirm]
[group('ENCRYPTION')]
create-public-key name="key":
	age-keygen -y "{{name}}.txt" > "{{name}}pub.txt"

# create a 1password key from a given age key
[confirm]
[group('ENCRYPTION')]
age-key-to-1password name:
	op document create "./{{name}}.txt" --title "Age key > {{name}}" --tags "age" --file-name "{{name}}.txt"

# backup a single folder into a tar.gz file and encrypt it using age
[group('ENCRYPTION')]
wrap folder AGE_KEY_PUB=".agekeypub.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	foldername="$(basename "{{folder}}")"

	ouch compress "{{folder}}" "$HOME/${foldername}.tar.gz"
	age --encrypt -R "{{AGE_KEY_PUB}}" --output "$HOME/${foldername}.tar.gz.age" "$HOME/${foldername}.tar.gz"
	rm "$HOME/${foldername}.tar.gz"
	# open "$HOME"

# restore a file or folder from age
[group('ENCRYPTION')]
unwrap file AGE_KEY_PUB=".agekey.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	filename=$(basename {{file}})
	filenamewithoutage=$(basename "$filename" .age)
	folder=$(dirname "{{file}}")

	just decrypt "$folder/$filename" "$folder/$filenamewithoutage" "{{AGE_KEY_PUB}}"
	if [[ "$filenamewithoutage" == *.tar.gz ]]; then
		ouch decompress "$folder/$filenamewithoutage" --dir "$folder"
		ouch list "$folder/$filenamewithoutage" --tree
		rm "$folder/$filenamewithoutage"
		# open $folder
	fi

# decrypt a file using age
[group('ENCRYPTION')]
decrypt filename target AGE_KEY_PUB=".agekey.txt":
	age --decrypt -i "{{AGE_KEY_PUB}}" --output "{{target}}" "{{filename}}"

# backup an item to the remote backup bucket
[group('BACKUP')]
backup-item REMOTE_PREFIX ITEM_PATH AGE_KEY_PUB=".agekeypub.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	itemname="$(basename "{{ITEM_PATH}}")"

	just wrap "{{ITEM_PATH}}" "{{AGE_KEY_PUB}}"
	just offload "{{REMOTE_PREFIX}}" "$HOME/${itemname}.tar.gz.age"
	rm "$HOME/${itemname}.tar.gz.age"

# backup the elements of a folder to the remote backup bucket
[group('BACKUP')]
backup-folder REMOTE_PREFIX FOLDER_PATH AGE_KEY_PUB=".agekeypub.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	ls -1 {{FOLDER_PATH}} | while read -r folder; do
		just wrap "{{FOLDER_PATH}}/$folder" "{{AGE_KEY_PUB}}"
		just offload "{{REMOTE_PREFIX}}" "$HOME/${folder}.tar.gz.age"
		rm "$HOME/${folder}.tar.gz.age"
	done

# offload a file to the remote backup bucket
[group('BACKUP')]
offload REMOTE_PREFIX file:
	mc cp "{{file}}" "$Y_BACKUP_MC_ALIAS/$Y_BACKUP_REMOTE_BUCKET/{{REMOTE_PREFIX}}/$(date +%Y-%m-%d)/$(basename "{{file}}")" --storage-class=GLACIER
