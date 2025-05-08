ifdef CLUSTER
all:
	echo "CLUSTER is defined: $(CLUSTER)"
else
all:
	echo "CLUSTER is not defined"
endif


help:
	@echo "help \t\t-- print this help"
	@echo "aws_login \t\t-- Login to the AWS profile set in the AWS_PROFILE"
	@echo "deps \t\t-- install dependencies: cdktf get and npm install"
	@echo "encrypt \t\t-- encrypt password field from config/development.json file"
	@echo "synth \t\t-- run cdktf synth: Synthesize terraform code"
	@echo "diff \t\t-- run cdktf diff showing infrastructure changes"
	@echo "deploy \t\t-- deploy infrastructure changes"
	@echo "clean \t\t-- clean all created files"

aws_login:
	aws sso login --profile $(AWS_PROFILE)

install:
	npm install

get:
	npm run get

deps: install get

encrypt:
	sops --encrypt --encrypted-regex '.*[p|P]assword.*|.*[s|S]ecret.*' --output-type json --output config/$(CLUSTER).enc.json config/$(CLUSTER).json

decrypt:
	sops --decrypt --output config/$(CLUSTER).json config/$(CLUSTER).enc.json

#synth: decrypt .EXPORT_ALL_VARIABLES 
synth: .EXPORT_ALL_VARIABLES 
	npm run synth
#	@rm config/$(CLUSTER).json

#diff: decrypt .EXPORT_ALL_VARIABLES
diff: .EXPORT_ALL_VARIABLES
	npm run diff
#	@rm config/$(CLUSTER).json

#deploy: decrypt .EXPORT_ALL_VARIABLES
deploy: .EXPORT_ALL_VARIABLES
	npm run deploy
#	@rm config/$(CLUSTER).json

clean:
	rm -rf .gen cdktf.out node_modules dist
#	@rm config/$(CLUSTER).json

.PHONY: help .EXPORT_ALL_VARIABLES