import { EksStack } from "../../main";
import { DataAwsVpc } from "../../../.gen/providers/aws/data-aws-vpc";
import { DataAwsSubnets } from "../../../.gen/providers/aws/data-aws-subnets";

export class GetVpcInfo {
    private readonly subnetsInfo: DataAwsSubnets;

    constructor(scope: EksStack, vpcId: string) {
        const vpcInfo = new DataAwsVpc(scope, `vpc-${vpcId}`, {
            id: vpcId,
        });

        this.subnetsInfo = new DataAwsSubnets(scope, `subnets-${vpcId}`, {
            filter: [
                {
                    name: "vpc-id",
                    values: [vpcInfo.id],
                },
                {
                    name: "tag:Name",
                    values: ["*priv*"],
                },
            ],
        });
    }

    public getSubnetIds(): string[] {
        return this.subnetsInfo.ids;
    }
}
