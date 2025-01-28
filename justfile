default:
	just --list

all:
	just brew
	just update

brew:
	zsh ./brew.sh

install:
	zsh ./install.sh

update:
	zsh ./update.sh
