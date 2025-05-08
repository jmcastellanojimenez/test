import { TerraformAsset, AssetType, Fn } from 'cdktf';
import { Resource } from '../../../.gen/providers/null/resource';
import { EksStack } from '../../main';
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import * as path from 'path';

export class clusterBoostrap {
    constructor(scope: EksStack, eksCluster: EksCluster, clusterName: string, env: string, region: string, clusterUrl: string, awsAccount: string) {

        const scriptAsset = new TerraformAsset(scope, 'LocalScript', {
            path: path.resolve(__dirname, '../../../../src/modules/bootstrap/files/callAwx.sh'),
            type: AssetType.FILE,
        });

        new Resource(scope, `boostrap-${clusterName}`, {
            provisioners: [{
                type: 'local-exec',
                command: `bash ${Fn.abspath(scriptAsset.path)} \
                     AWX_BASE_URL=ansible-awx.platform-staging.internal.epo.org \ 
                     AWX_JOB_TEMPLATE_ID=779 \
                     AWX_WAIT_TIMEOUT_TRIES=100 \
                     --variables cluster_name=${clusterName} \
                     env=${env} \
                     cloud=aws \
                     region=${region} \
                     cluster_url=${clusterUrl} \
                     aws_account=${awsAccount}`,
            }],
            dependsOn: [eksCluster]
        });
    }
}
