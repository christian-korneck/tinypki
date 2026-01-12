# tiny pki

a simple structure for an internal or lab PKI    
    
(a folder structure and some shell scripts around [`cfssl`](https://github.com/cloudflare/cfssl))    
     
gives you an instant Root CA, Intermediate CA and makes it easy to create and revoke server certs and wildcard certs.

## Installation

### Prereqs

- bash, [cfssl](https://github.com/cloudflare/cfssl), [jq](https://github.com/jqlang/jq), [envsubst](https://man7.org/linux/man-pages/man1/envsubst.1.html), openssl

Fedora/EL:

```bash
dnf install bash coreutils golang-github-cloudflare-cfssl gettext-envsubst jq openssl
```

Ubuntu/Debian:

```
apt install bash coreutils golang-cfssl gettext-base jq openssl
```

### Install & Initialize

```
git clone https://github.com/christian-korneck/tinypki.git
cd tinypki
```

In `pki.conf` set a name for your PKI:

```
PKI_NAME="contoso"
```

(And optionally change other settings).

Now bootstrap the PKI (this generates Root CA and Intermdiate CA keys/certs):

```
./bootstrap.sh
```

Now make the Root CA cert trusted on your clients. It can be found here:

```
root-ca/<PKI_NAME>-root-ca.pem
```

## Usage

### Create a server cert

```
cd server
./mkcert.sh bob.contoso.com
```

You can optionally also specify multiple SANs:

```
./mkcert.sh bob.contoso.com bob-prod.contoso.com bob-dev.contoso.com bob
```

All relevant files (cert, cert with ca cert chain, key, pfx) are created in a subfolder named after the primary name:

```
$ ls server/bob.contoso.com/

# server cert
bob.contoso.com-cert-only.pem

# cert + intermediate ca cert (chain)
bob.contoso.com.pem

# key
bob.contoso.com-key.pem

# pfx (cert + key + intermediate ca cert)
bob.contoso.com.pfx
```

### Revoke a server cert

```
cd server
./revoke.sh ./bob-contoso.com
```

### Wildcard certs

Works like server certs, but have their own dir:

```
# create wildcard cert for *.lab9.contoso.com
cd wildcard
./mkcert.sh lab9.contoso.com
```

## optional: enable CRL

By default, generated certs do not contain a CRL (certificate revocation list) URL.

It can get enabled in `pki.conf`:

```
USE_CRL_URL="true"

CRL_URL="http://crl.contoso.com/contoso-intermediate.crl"
```

Now make sure that the CRL file `crl/<PKI_NAME>-intermediate.crl` gets hosted via HTTP (no TLS) under the URL specified in `pki.conf`.

Having working CRL is a requirement for some use cases on MS Windows.

## FAQ

- Q: Isn't it insecure to have keys with no passphrase in the filesystem?
  - A: Best to store it in a save place. I use an encrypted [Cryptomator](https://github.com/cryptomator/cryptomator) container to store my PKI folder structures.
- Q: Are there other useful scripts?
  - A: Yes,
    - `./force_clean.sh` - resets the PKI (Warning: total data loss!!)
    - `crl/list-revoked.sh` - lists all revoked certs
- Q: Can I edit settings not available in `pki.conf`?
  - A: Yes, you can edit the `<root-ca|intermediate-ca|server|wildcard|crl>/*.json` templates. These are regular `cfssl` json. See cfssl docs.
- Q: Are other cert types (i.e. S/MIME) supported?
  - A: No, this project is for simple web server certs. But you can modify the cfssl json templates to get it to work.
- Q: Why cfssl *and* openssl?
  - A: Everything is done with cfssl, except for PFX and CRL generation (cfssl has limitations here).
- Q: How do I make the root CA cert trusted on clients?
  - A: Refer to your OS/distro docs. We also have convenience install scripts to make the root ca cert trusted on Windows, Linux (Fedora, EL, Debian, Ubuntu), Android Termux and MacOS clients:
      - in `utils/clientinstall`
      - usage:
        ```
        ./install_rootca_<os>.sh /path/to/<PKI_NAME>-root-ca.pem`
        ```
- Q: How do I install server certs for <Apache|Nginx|HAProxy|...>?
  - A: Check the *excellent* [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/) for practical and - most importantly - *up to date* recommendations for many common web servers.
- Q: What's the cipher suite?
  - A:
    - CAs + CRL: secp384r1 / ecdsa-with-SHA384
    - server/wildcard: prime256v1 / ecdsa-with-SHA256

## Folder structure example

This is what an initialized PKI with CRL enabled and two servers (`alice.contoso.com` and `bob.contoso.com`) and one wildcard cert (`*.contoso.com`) looks like:

```
tinypki
├── pki.conf
├── bootstrap.sh
├── force_clean.sh
├── README.md
├── root-ca
│   ├── ca-config.json
│   ├── contoso-root-ca-key.pem
│   ├── contoso-root-ca.pem
│   ├── csr.json
│   └── mkcert.sh
├── intermediate-ca
│   ├── ca-config.json
│   ├── contoso-intermediate-ca-key.pem
│   ├── contoso-intermediate-ca.pem
│   ├── csr.json
│   └── mkcert.sh
├── server
│   ├── alice.contoso.com
│   │   ├── alice.contoso.com-cert-only.pem
│   │   ├── alice.contoso.com-key.pem
│   │   ├── alice.contoso.com.pem
│   │   └── alice.contoso.com.pfx
│   ├── bob.contoso.com
│   │   ├── bob.contoso.com-cert-only.pem
│   │   ├── bob.contoso.com-key.pem
│   │   ├── bob.contoso.com.pem
│   │   └── bob.contoso.com.pfx
│   ├── csr.json
│   ├── mkcert.sh
│   └── revoke.sh
├── wildcard
│   ├── csr.json
│   ├── mkcert.sh
│   ├── revoke.sh
│   └── wildcard.contoso.com
│       ├── wildcard.contoso.com-cert-only.pem
│       ├── wildcard.contoso.com-key.pem
│       ├── wildcard.contoso.com.pem
│       └── wildcard.contoso.com.pfx
├── utils
│   └── clientinstall
│       ├── install_rootca_androidtermux.sh
│       ├── install_rootca_debian-ubuntu.sh
│       ├── install_rootca_fedora-el.sh
│       ├── install_rootca_macos.sh
│       └── install_rootca_windows.cmd
└── crl
    ├── contoso-intermediate.crl
    ├── crlnumber
    ├── crlnumber.old
    ├── generate-crl.sh
    ├── index.txt
    ├── index.txt.attr
    ├── index.txt.old
    ├── list-revoked.sh
    └── revoke.sh

11 directories, 45 files

```
