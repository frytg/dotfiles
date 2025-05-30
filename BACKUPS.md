# Creating backups of files and folders

## Create a key

```bash
just create-age-key ".agebackupkey"
```

Save this key in a safe place (i.e. password manager).

## Backup a folder or file

Use the public key to backup a folder or file.

```bash
just wrap "path/to/folder" ".agebackupkeypub.txt"
```

## Restore an element

Restore using the original key.

```bash
just unwrap "path/to/folder.tar.gz.age" ".agebackupkey.txt"
```

## Backup an entire folder

Backup an entire folder to the remote backup bucket.

E.g. backup the Documents/iCloud folder:

```bash
just backup-folder "icloud" ~/Documents .agebackupkeypub.txt
```

## Backup an item

Backup an item to the remote backup bucket.

```bash
just backup-item "something" "path/to/folder" .agebackupkeypub.txt
```
