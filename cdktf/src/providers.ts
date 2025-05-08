import { AwsProvider } from "../.gen/providers/aws/provider";
import { VaultProvider } from "../.gen/providers/vault/provider";
import { NullProvider } from "../.gen/providers/null/provider";
import { S3Backend } from "cdktf";

import { EksStack } from "./main"

export function setUpProvider(scope: EksStack, region: string, clusterName: string) {
  new AwsProvider(scope, "aws", {
    region: region,
  });

  // S3 Backend - https://www.terraform.io/docs/backends/types/s3.html
  new S3Backend(scope, {
    bucket: "tf-bucket-np-alpha",
    key: `eks-cluster-cdktf/${clusterName}.tfstate`,
    region: region,
    dynamodbTable: "tf-lock-table",
  });
}

export function setUpVaultProvider(scope: EksStack) {
  new VaultProvider(scope, "vault", {
    address: "https://vaultlab.internal.epo.org",
    token: process.env.VAULT_TOKEN,
    skipTlsVerify: true
  })
}

export function setUpNullProvider(scope: EksStack) {
  new NullProvider(scope, "null", {})
}