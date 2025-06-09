import { Fn } from "cdktf";
import { EksStack } from "../../main";
import { nodegroupsConfig } from "../../main"
import { KeyPair } from "../../../.gen/providers/aws/key-pair"
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup"
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { getVaultSecret } from "../vault/vault"

export class eksNodegroupCreation {
    private nodeGroup!: EksNodegroup;

    public instanceTypeMap: Record<string, string> = {
        NANO: "t3.nano",
        NANO_G: "t4g.nano",
        XS: "t3.micro",
        S: "t3.medium",
        M: "m6a.xlarge",
        L: "m6a.2xlarge",
        XL: "m6a.4xlarge",
        XXL: "m6a.12xlarge",
    };

    constructor(scope: EksStack, clusterName: string, clusterVersion: string, projectName: string, subnetIds: string[], nodegroups: nodegroupsConfig[], eksCluster: EksCluster, installCilium: boolean) {

        const secret = new getVaultSecret(scope, "idrsa", "secret/np-alpha-eks-02/kube-system/ssh")      
        const publicKey = Fn.lookup(secret.getSecret().data, "id_rsa.pub", "");

        const keyPair = new KeyPair(scope, "ssh-keypair", {
            keyName: "my-eks-keypair",
            publicKey: publicKey,
          });

        for (let i = 0; i < nodegroups.length; i++) {
            const nodegroup = nodegroups[i];

            const instanceType = this.instanceTypeMap[nodegroup.nodeSize] ?? "t3.micro";

            const preBootstrapUserData = `#!/bin/bash
            set -ex
            cat <<-EOF > /etc/profile.d/bootstrap.sh
            export CONTAINER_RUNTIME="containerd"
            export USE_MAX_PODS=false
            export KUBELET_EXTRA_ARGS="--max-pods=110"
            EOF
            # Source extra environment variables in bootstrap script
            sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
            `;

            const taints: { [key: string]: any } = {}

            if (installCilium) {
                taints["cilium"] = {
                    key: "node.cilium.io/agent-not-ready",
                    value: "true",
                    effect: "NO_EXECUTE",
                };
              }

            this.nodeGroup = new EksNodegroup(scope, `nodegroup-${projectName}-${i}`, {
                clusterName: clusterName,
                clusterVersion: clusterVersion,
                subnetIds: subnetIds,
                name: nodegroup.nodeName,
                minSize: 1,
                maxSize: nodegroup.maxNumberNodes,
                desiredSize: nodegroup.desireNumberNodes,
                instanceTypes: [instanceType],
                clusterServiceCidr: "172.20.0.0/16",
                preBootstrapUserData: preBootstrapUserData,
                useCustomLaunchTemplate: false,
                taints: taints,
                remoteAccess: {
                    ec2_ssh_key: keyPair.keyName,
                    //source_security_group_ids: [sshSecurityGroup.id],
                },
                dependsOn: [eksCluster, keyPair]
            });
        }
    }
    public getNodeGroup(): EksNodegroup {
        return this.nodeGroup;
    }
}