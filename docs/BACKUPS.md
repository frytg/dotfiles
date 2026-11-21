# Keys and encrypted secrets

`just` recipes in [`just/age.just`](../just/age.just) and [`just/encryption.just`](../just/encryption.just) manage [age](https://github.com/FiloSottile/age) keys and [sops](https://github.com/getsops/sops) secret files configured in [`.sops.yaml`](../.sops.yaml).

## Age keys

Generate a keypair in `./tmp/` (gitignored) and upload the private key to 1Password:

```bash
just create-age-key my-backup-key
```

This writes `tmp/my-backup-key.txt` (private key) and `tmp/my-backup-keypub.txt` (public key), then prompts to create a 1Password document titled `Age key > my-backup-key` (`op` must be authenticated). Run `just create-public-key my-backup-key` to re-derive `tmp/my-backup-keypub.txt` from an existing `tmp/my-backup-key.txt`.

Do not commit `tmp/*.txt` or `.age*.txt` files; [`.gitignore`](../.gitignore) excludes both.

## Sops secrets

- `just edit-key <file>` (`just ek <file>`) — open an encrypted file in `nano` via `sops edit`
- `just decrypt-env <file>` — decrypt a `*.sops.yaml` file to dotenv format (`just run` decrypts [`.pi/.env.personal.sops.yaml`](../.pi/.env.personal.sops.yaml) to `.pi/.env.personal`)
- `just decrypt-key <file>` — decrypt a `*.sops` file to its non-`.sops` sibling path
- `just update-keys` — re-encrypt `.pi/.env.sops.yaml` after changing recipients in [`.sops.yaml`](../.sops.yaml)
- `just rotate-keys` — rotate data keys inside `.pi/.env.sops.yaml`
