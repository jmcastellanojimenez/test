import { EksStack } from "../../main";
import { EksAddons } from "../../../.gen/modules/eks_addons";
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup";
import { Resource } from '../../../.gen/providers/null/resource';

export class eksAddonsCreation {
  constructor(scope: EksStack, clusterName: string, eksCluster: EksCluster, eksNodegroup: EksNodegroup, installCilium: boolean, bootstrap: Resource) {

    const addons: { [key: string]: any } = {
      "coredns": {
        most_recent: true,
      },
      "aws-ebs-csi-driver": {},
      "eks-pod-identity-agent": {
        most_recent: true,
      },
    };

    let depends = []
    if (!installCilium) {
      addons["vpc-cni"] = {
        most_recent: true,
      };
      addons["kube-proxy"] = {
        most_recent: true,
      };
      depends = [eksCluster, eksNodegroup]
    } else {
      depends = [eksCluster, eksNodegroup, bootstrap]
    }

    new EksAddons(scope, `eksaddons-${clusterName}`, {
      clusterEndpoint: eksCluster.clusterEndpointOutput,
      clusterName: clusterName,
      clusterVersion: eksCluster.clusterVersionOutput,
      oidcProviderArn: eksCluster.oidcProviderArnOutput,
      eksAddons: addons,
      dependsOn: depends
    });
  }
}
