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
