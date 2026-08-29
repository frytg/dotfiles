# update mise
[group('DEV-SETUP')]
mise-update:
	mise upgrade  --bump -y --local
	-mise outdated
