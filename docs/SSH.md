# SSH

For service-account SSH keys loaded from 1Password into `ssh-agent`, see [`docs/1PASSWORD_SSH.md`](./1PASSWORD_SSH.md). [`bin/link.sh`](../bin/link.sh) symlinks [`.ssh-authorized_keys`](../.ssh-authorized_keys) to `~/.ssh/authorized_keys` with mode `600`.

## YubiKey PIV

Set up a YubiKey PIV key in slot `9a` for SSH authentication (useful when logging in to a Mac or server from [Moshi](https://getmoshi.app/docs) on iOS without adding a fixed disk key).

Download `yubico-piv-tool` from [Yubico Releases](https://developers.yubico.com/yubico-piv-tool/Releases/) (see also the [PIV walkthrough](https://developers.yubico.com/PIV/Guides/PIV_Walk-Through.html)).

1. Generate a new key in slot `9a` and write the public key:

   ```bash
   yubico-piv-tool -s 9a -a generate --algorithm=ECCP256 -o public.pem
   ```

2. Generate a self-signed certificate for the public key:

   ```bash
   yubico-piv-tool -a verify-pin -a selfsign-certificate -s 9a -S "/CN=SSH key/" -i public.pem -o cert.pem
   ```

3. Import the certificate onto the YubiKey:

   ```bash
   yubico-piv-tool -a import-certificate -s 9a -i cert.pem
   ```

4. Convert the public key for `authorized_keys`:

   ```bash
   ssh-keygen -i -m PKCS8 -f public.pem > public_ssh.pub
   ```
