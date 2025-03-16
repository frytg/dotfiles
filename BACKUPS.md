# Creating backups of files and folders

## Create a key

```bash
just create-age-key ".agebackupkey"
```

Save this key in a safe place (i.e. password manager).

## Backup a folder

Use the public key to backup a folder.

```bash
just backup "path/to/folder" ".agebackupkeypub.txt"
```

## Restore a folder

Restore using the original key.

```bash
just restore "path/to/folder.tar.gz.age" ".agebackupkey.txt"
```
