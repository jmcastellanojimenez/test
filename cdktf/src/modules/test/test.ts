import { EksStack, nodegroupsConfig } from "../../main";

export class testValues {
  constructor(_: EksStack, nodegroupConfig: nodegroupsConfig) {
    if (nodegroupConfig.desireNumberNodes > nodegroupConfig.maxNumberNodes) {
      throw new Error(`Desire number of nodes (${nodegroupConfig.desireNumberNodes}) must be less than or equal to max number of nodes (${nodegroupConfig.maxNumberNodes}).`);
    }
  }
}
