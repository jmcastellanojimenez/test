import { EksStack } from "../../main";
import { GenericSecret } from "../../../.gen/providers/vault/generic-secret"
import { DataVaultGenericSecret } from "../../../.gen/providers/vault/data-vault-generic-secret"
import { EksCluster } from "../../../.gen/modules/eks_cluster";

export class generateVaultSecret {
    private secret: GenericSecret;

    constructor(scope: EksStack, eksCluster: EksCluster, secretName: string, secretPath: string, genericSecret: string) {

        this.secret = new GenericSecret(scope, `secret-${secretName}`, {
            dataJson: genericSecret,
            path: secretPath,
            dependsOn: [eksCluster]
        })
    }

    public getSecret(): GenericSecret {
        return this.secret;
    }
}

export class getVaultSecret {
    private secret: DataVaultGenericSecret;

    constructor(scope: EksStack, secretName: string, secretPath: string) {

        this.secret = new DataVaultGenericSecret(scope, `secret-${secretName}`, {
            path: secretPath,
        })
    }

    public getSecret(): DataVaultGenericSecret {
        return this.secret
    }
}