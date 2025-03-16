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
	zsh ./update.sh
alias up := update

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

backup-folders path agekey=".agerecipients.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	ls -1 {{path}} | while read -r folder; do
		just backup "$folder" "{{agekey}}"
	done

# backup a single folder into a tar.gz file and encrypt it using age
[group('ENCRYPTION')]
backup folder agekey=".agerecipients.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	foldername="$(basename {{folder}})"

	ouch compress {{folder}} "$HOME/${foldername}.tar.gz"
	age --encrypt -R "{{agekey}}" --output "$HOME/${foldername}.tar.gz.age" "$HOME/${foldername}.tar.gz"
	rm "$HOME/${foldername}.tar.gz"
	open "$HOME"

# restore a file or folder from age
[group('ENCRYPTION')]
restore file agekey=".agekey.txt":
	#!/usr/bin/env bash
	set -euxo pipefail

	filename=$(basename {{file}})
	filenamewithoutage=$(basename "$filename" .age)
	folder=$(dirname "{{file}}")

	just decrypt "$folder/$filename" "$folder/$filenamewithoutage" "{{agekey}}"
	if [[ "$filenamewithoutage" == *.tar.gz ]]; then
		ouch decompress "$folder/$filenamewithoutage" --dir "$folder"
		ouch list "$folder/$filenamewithoutage" --tree
		rm "$folder/$filenamewithoutage"
		open $folder
	fi

# decrypt a file using age
[group('ENCRYPTION')]
decrypt filename target agekey=".agekey.txt":
	age --decrypt -i "{{agekey}}" --output "{{target}}" "{{filename}}"
