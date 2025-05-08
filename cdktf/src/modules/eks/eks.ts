import { EksStack } from "../../main";
import { EksCluster } from "../../../.gen/modules/eks_cluster";

export class eksCreation {
  private cluster: EksCluster;

  constructor(scope: EksStack, clusterName: string, clusterVersion: string, project: string, env: string, vpcId: string, subnetIds: string[]) {
    this.cluster = new EksCluster(scope, clusterName, {
      authenticationMode: "API_AND_CONFIG_MAP",
      clusterName: clusterName,
      clusterVersion: clusterVersion,
      clusterEndpointPrivateAccess: true,
      clusterEndpointPublicAccess: true,
      enableClusterCreatorAdminPermissions: true,
      vpcId: vpcId,
      subnetIds: subnetIds,
      tags: {
        environment: env,
        project: project,
      }
    });
  }

  public getCluster(): EksCluster {
    return this.cluster;
  }
}
