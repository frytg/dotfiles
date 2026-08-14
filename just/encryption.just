# list PGP keys and their fingerprints
[group('ENCRYPTION')]
list-pgp:
	gpg --list-keys

alias list-gpg := list-pgp
alias lpgp := list-pgp
alias lgpg := list-pgp

## ---------------------------------
## ENCRYPTION shortcuts

# add/ remove keys (if .sops.yaml setup was changed)
[group('ENCRYPTION')]
update-keys:
	just _update-key .pi/.env.sops.yaml

_update-key file:
	sops updatekeys {{ file }}

# rotate keys (refreshed internal encryption keys)
[group('ENCRYPTION')]
rotate-keys:
	just _rotate-key .pi/.env.sops.yaml

_rotate-key file:
	sops rotate --in-place {{ file }}

# make changes to a secret file
[group('ENCRYPTION')]
edit-key file:
	EDITOR=nano sops edit {{ file }}
alias ek := edit-key

# decrypt a secret file
[confirm('This will overwrite any previously decrypted files, are you sure? (type `yes` to continue)')]
[group('ENCRYPTION')]
decrypt-key file:
	sops --output $(echo {{ file }} | sed 's/\.sops//g') --decrypt {{ file }}

# decrypt a secret file
[confirm('This will overwrite any previously decrypted files, are you sure? (type `yes` to continue)')]
[group('ENCRYPTION')]
decrypt-env file:
	sops --output-type dotenv --output $(echo {{ file }} | sed 's/\.sops.yaml//g') --decrypt {{ file }}
