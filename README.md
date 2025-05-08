# Terraform AWS

This repo contains the terraform for the cluster creation and VPC Endpoints.

## HCL

`terraform apply -var-file="sample.tfvars"`

## CDKTF

```
  Synthesize:
    cdktf synth [stack]   Synthesize Terraform resources from stacks to cdktf.out/ (ready for 'terraform apply')

  Diff:
    cdktf diff [stack]    Perform a diff (terraform plan) for the given stack

  Deploy:
    cdktf deploy [stack]  Deploy the given stack

  Destroy:
    cdktf destroy [stack] Destroy the stack
```

## TO-DO

- Right sizing of the nodes
- ~~SSH keys for the nodes~~
- How to document
- ~~TF bucket creation~~
    - ~~AWS_REGION=eu-central-1 ENV=np PROJECT=alpha ./tf-backend-resources.sh~~
- ~~Generate CDKTF Code~~
- ~~Cilium Installation~~
- ~~External DNS Testing~~
    - ~~Route53 connectivity~~
- Bootstraping