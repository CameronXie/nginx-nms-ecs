cfn_dir:=stack/cfn
docker_stack_dir:=stack/docker
project_name:=nginx-nms-ecs

# stacks
vpc_stack_name:=$(project_name)-vpc
cp_repo_stack_name:=$(project_name)-cp-repository
cp_platform_stack_name:=$(project_name)-cp-platform
dp_repo_stack_name:=$(project_name)-dp-repository
dp_platform_stack_name:=$(project_name)-dp-platform
bastion_stack_name:=$(project_name)-bastion

# parameters
clickhouse_repo_name:=$(project_name)-clickhouse
nms_repo_name:=$(project_name)-nms
data_plane_repo_name:=$(project_name)-dp
vpc_id_param_name:=/$(project_name)/vpc-id
public_subnet_ids_param_name:=/$(project_name)/public-subnet-ids
private_subnet_ids_param_name:=/$(project_name)/private-subnet-ids
nms_lb_dns_param_name:=/$(project_name)/nms-lb-dns
clickhouse_user_arn_param_name:=/$(project_name)/clickhouse-user-arn
nms_admin_arn_param_name:=/$(project_name)/nms-admin-arn
nms_license_arn_param_name:=/$(project_name)/nms-license-arn

# images
account_id=$(shell aws sts get-caller-identity --query "Account" --output text)
ecr=$(account_id).dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
clickhouse_image_tag=$(ecr)/$(clickhouse_repo_name):1
nms_image_tag=$(ecr)/$(nms_repo_name):1
data_plane_image_tag=$(ecr)/$(data_plane_repo_name):1

# Docker
.PHONY: up
up: create-dev-env
	@docker compose up --build -d

.PHONY: down
down:
	@docker compose down -v

.PHONY: create-dev-env
create-dev-env:
	@test -e .env || cp .env.example .env

# CI/CD
## AWS ECS
.PHONY: deploy
deploy: deploy-vpc deploy-cp deploy-dp deploy-bastion

.PHONY: deploy-vpc
deploy-vpc:
	@rain deploy $(cfn_dir)/vpc.yaml $(vpc_stack_name) -y \
		--params VpcIdParamName=$(vpc_id_param_name),\
	PublicSubnetIdParamName=$(public_subnet_ids_param_name),\
	PrivateSubnetIdParamName=$(private_subnet_ids_param_name)

.PHONY: deploy-cp
deploy-cp:
	@rain deploy $(cfn_dir)/control-plane/repository.yaml $(cp_repo_stack_name) -y \
		--params ClickHouseRepositoryName=$(clickhouse_repo_name),\
	NMSRepositoryName=$(nms_repo_name),\
	ClickHouseUserArnParamName=$(clickhouse_user_arn_param_name),\
	NMSAdminArnParamName=$(nms_admin_arn_param_name),\
	NMSLicenseArnParamName=$(nms_license_arn_param_name)
	@$(MAKE) upload-license
	@$(MAKE) login-ecr
	@$(MAKE) -j 2 publish-clickhouse-image publish-nms-image
	@rain deploy $(cfn_dir)/control-plane/platform.yaml $(cp_platform_stack_name) -y \
		--params VpcId=$(vpc_id_param_name),\
	PrivateSubnetIds=$(private_subnet_ids_param_name),\
	NMSLoadBalancerDNSNameParamName=$(nms_lb_dns_param_name),\
	ClickHouseUserArn=$(clickhouse_user_arn_param_name),\
	NMSAdminArn=$(nms_admin_arn_param_name),\
	NMSLicenseArn=$(nms_license_arn_param_name),\
	ClickHouseImage=$(clickhouse_image_tag),\
	NMSImage=$(nms_image_tag)

.PHONY: deploy-dp
deploy-dp:
	@rain deploy $(cfn_dir)/data-plane/repository.yaml $(dp_repo_stack_name) -y \
		--params RepositoryName=$(data_plane_repo_name)
	@$(MAKE) login-ecr
	@$(MAKE) publish-dp-image
	@rain deploy $(cfn_dir)/data-plane/platform.yaml $(dp_platform_stack_name) -y \
		--params VpcId=$(vpc_id_param_name),\
	PublicSubnetIds=$(public_subnet_ids_param_name),\
	PrivateSubnetIds=$(private_subnet_ids_param_name),\
	NMSLoadBalancerDNSName=$(nms_lb_dns_param_name),\
	Image=$(data_plane_image_tag)

.PHONY: deploy-bastion
deploy-bastion:
	@rain deploy $(cfn_dir)/bastion.yaml $(bastion_stack_name) -y \
		--params NMSLoadBalancerDNSName=$(nms_lb_dns_param_name)

.PHONY: upload-license
upload-license:
	@aws secretsmanager put-secret-value \
      	--secret-id $(cp_repo_stack_name)-nms-license \
        --secret-string $(shell base64 -w0 ./certs/license.lic)

.PHONY: login-ecr
login-ecr:
	@aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin $(ecr)

.PHONY: publish-clickhouse-image
publish-clickhouse-image:
	@docker build --platform linux/amd64 -f docker/clickhouse/Dockerfile \
		-t $(clickhouse_image_tag) \
		docker/clickhouse/
	@docker push $(clickhouse_image_tag)

.PHONY: publish-nms-image
publish-nms-image:
	@docker build --platform linux/amd64 -f docker/nms/Dockerfile \
		--secret id=nginx-crt,src=./certs/nginx-repo.crt \
		--secret id=nginx-key,src=./certs/nginx-repo.key \
		-t $(nms_image_tag) \
		docker/nms/
	@docker push $(nms_image_tag)

.PHONY: publish-dp-image
publish-dp-image:
	@docker build --platform linux/amd64 -f docker/data-plane/Dockerfile \
		--secret id=nginx-crt,src=./certs/nginx-repo.crt \
		--secret id=nginx-key,src=./certs/nginx-repo.key \
		-t $(data_plane_image_tag) \
		docker/data-plane/
	@docker push $(data_plane_image_tag)

.PHONY: get-nms-url
get-nms-url:
	@aws cloudformation --region ${AWS_DEFAULT_REGION} describe-stacks --stack-name $(cp_platform_stack_name) \
		--query 'Stacks[0].Outputs[?OutputKey==`URL`].OutputValue' --output text

port-forwarding:
	@aws ssm start-session --target $(shell aws cloudformation --region ${AWS_DEFAULT_REGION} describe-stacks --stack-name $(bastion_stack_name) --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text) \
		--document-name AWS-StartPortForwardingSession \
		--parameters "portNumber"=["8443"],"localPortNumber"=["8443"] \
		--region ${AWS_DEFAULT_REGION}

## Docker Container
.PHONY: deploy-docker
deploy-docker: create-docker-env
	@docker compose -f stack/docker/docker-compose.yaml up --build -d

.PHONY: teardown-docker
teardown-docker:
	@docker compose -f stack/docker/docker-compose.yaml down -v

.PHONY: create-docker-env
create-docker-env:
	@test -e $(docker_stack_dir)/.env || cp $(docker_stack_dir)/.env.example $(docker_stack_dir)/.env

# Dev
.PHONY: test
test: cfn-format cfn-lint

.PHONY: cfn-format
cfn-format:
	@rain fmt $(cfn_dir)/*.yaml -w

.PHONY: cfn-format
cfn-lint:
	@cfn-lint $(cfn_dir)/**/*.yaml
