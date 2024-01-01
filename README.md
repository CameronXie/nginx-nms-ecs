# NGINX Management Suite On AWS ECS

This project demonstrates a possible solution to deploy NGINX Management Suite and Data Plane (NGINX Plus, NGINX Agent)
on AWS ECS.

This project is using https://github.com/nginxinc/NGINX-Demos/tree/master/nginx-nms-docker
and https://github.com/nginxinc/NGINX-Demos/tree/master/nginx-agent-docker as references to build nms and data plane
Docker images.

## Prerequisites

* NGINX Management Suite License. Store the `license.lic`, `nginx-repo.crt` and `nginx-repo.key` in `certs` directory.
* Docker Version 24+
* An AWS IAM user account which has sufficient permission to deploy VPC, ECR, ECS and EFS. Update `AWS_ACCESS_KEY_ID`
  and `AWS_SECRET_ACCESS_KEY` in `.env`.

## Folder Structure

```shell
.
├── Makefile
├── README.md
├── certs
│   ├── license.lic               # NMS license file
│   ├── nginx-repo.crt            # NGINX certificate
│   └── nginx-repo.key            # NGINX private key
├── docker
│   ├── clickhouse
│   ├── data-plane
│   ├── dev
│   └── nms
├── docker-compose.yaml
└── stack
    ├── cfn                       # CloudFormation to deploy to ECS
    │   ├── control-plane         # Control Plane / NMS Stack
    │   ├── data-plane            # Data Plane / NGINX Plus, NGINX Agent Stack
    │   └── vpc.yaml              # VPC Stack
    └── docker
        └── docker-compose.yaml   # docker-compose file to deploy to Docker containers.
```

## Deploy to AWS ECS

Run `make deploy` to deploy both control plane and data plane on AWS ECS.

To access NMS load balancer, optionally can run `make deploy-bastion` to deploy a bastion box on AWS EC2, and
run `make port-forwarding` to forward traffic from the host machine to NMS load balancer via two reverse proxies.
Open http://localhost:8443/ in web browser on local machine.

## Deploy to Docker

Run `make deploy-docker` to deploy both control plane and data plane on docker containers.

## How to test

Run `make test` to run CloudFormation template formatting and linting.  
