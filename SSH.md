# SSH

## Yubikey

To setup SSH keys for the Yubikey, run this:

Generate a new key in slot 9a and write the public key

```bash
yubico-piv-tool -s 9a -a generate --algorithm=ECCP256 -o public.pem
```

Generate a self-signed certificate for the public key

```bash
yubico-piv-tool -a verify-pin -a selfsign-certificate -s 9a -S "/CN=SSH key/" -i public.pem -o cert.pem
```

Import the certificate into the Yubikey

```bash
yubico-piv-tool -a import-certificate -s 9a -i cert.pem
```

Create hash of public key to your `authorized_keys`

```bash
ssh-keygen -i -m PKCS8 -f public.pem > public_ssh.pub
```
