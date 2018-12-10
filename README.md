# aws-ptfe-sandbox

Quick Terraform code to do setup a basic PTFE instance

## Steps

* Setup your AWS credentials in a profile

```
cat ~/.aws/credentials
[acme]
aws_access_key_id = AKI232fdfQG3JL5DPGQ
aws_secret_access_key = 2SijAagsdfgsdfgsazzd2fn4zp/54
export AWS_PROFILE=acme
```

* Put the following files in the `config/` folder:

```
license.rli
```

* Plan

```
terraform plan
```

* Apply

```
terraform apply
```

## Certificate Setup

This setup uses a cert created by `mkcert`:

```
mkcert 'ptfe-selfsigned.example.com'
Using the local CA at "/Users/psouter/Library/Application Support/mkcert" ✨

Created a new certificate valid for the following names 📜
 - "ptfe-selfsigned.example.com"

The certificate is at "./ptfe-selfsigned.example.com.pem" and the key at "./ptfe-selfsigned.example.com-key.pem" ✅
```

This is then uploaded to the box, and the CA added to the PTFE install config:

```
cat "$(mkcert -CAROOT)/rootCA.pem"
-----BEGIN CERTIFICATE-----:
FOO-etc
```

```
"ca_certs": {
        "value": "-----BEGIN CERTIFICATE-----\n
        FOO-etc
        \n-----END CERTIFICATE-----"
    },
```
