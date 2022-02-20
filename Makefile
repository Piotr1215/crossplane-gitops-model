.PHONY : setup_mac setup_linux install_kind_linux install_kind_mac create_kind_cluster install_crossplane install_crossplane_cli

default: setup_linux

KIND_VERSION := $(shell kind --version 2>/dev/null)

install_kind_linux : 
ifdef KIND_VERSION
	@echo "Found version $(KIND_VERSION)"
else
	@curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
	@chmod +x ./kind
	@mv ./kind /bin/kind
endif

install_kind_mac : 
ifdef KIND_VERSION
	@echo "Found version $(KIND_VERSION)"
else
	@brew install kind
endif

create_kind_cluster :
	@echo "Creating kind cluster"
	@kind create cluster --name crossplane-cluster 
	@kind get kubeconfig --name crossplane-cluster
	@kubectl config set-context kind-crossplane-cluster 

install_crossplane : 
	@echo "Installing crossplane"
	@kubectl create namespace crossplane-system
	@helm repo add crossplane-stable https://charts.crossplane.io/stable
	@helm repo upate
	@helm install crossplane --namespace crossplane-system crossplane-stable/crossplane
	@kubectl wait deployment.apps/crossplane --namespace crossplane-system --for condition=AVAILABLE=True --timeout 1m

CROSSPLANE_CLI := $(shell kubectl crossplane --version 2>/dev/null)

install_crossplane_cli :
ifdef CROSSPLANE_CLI
	@echo "Crssplane CLI already installed"
else
	@curl -sL https://raw.githubusercontent.com/crossplane/crossplane/release-1.5/install.sh | sh
endif

FLUX_CLI := $(shell flux --version 2>/dev/null)

install_flux_cli :
ifdef FLUX_CLI
	@echo "Flux CLI already installed"
else
	@curl -s https://fluxcd.io/install.sh | sudo bash
endif

setup_aws :
	@echo "Setting up AWS provider"
	@kubectl apply -f aws-provider.yaml
	@kubectl wait -f aws-provider.yaml --for condition=HEALTHY=True --timeout 1m
	./generate-aws-secret.sh
	@kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf
	@kubectl apply -f aws-provider-config.yaml 
	@rm creds.conf

cleanup :
	@kind delete clusters crossplane-cluster

setup_mac : install_kind_mac create_kind_cluster install_crossplane install_crossplane_cli install_flux_cli setup_aws

setup_linux : install_kind_linux create_kind_cluster install_crossplane install_crossplane_cli install_flux_cli setup_aws
