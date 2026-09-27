# SSH

## Yubikey

Background: this guide was created/ used to setup a Yubikey for SSH authentication. This way I can login to my mac or servers in the [Moshi app](https://getmoshi.app/docs) on iOS without adding a fixed key.

To proceed, download `yubico-piv-tool` from [developers.yubico.com/yubico-piv-tool/Releases](https://developers.yubico.com/yubico-piv-tool/Releases/). Also see the [PIV walkthrough](https://developers.yubico.com/PIV/Guides/PIV_Walk-Through.html).

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
