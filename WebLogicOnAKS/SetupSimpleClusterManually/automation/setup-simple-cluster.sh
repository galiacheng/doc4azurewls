#!/bin/bash

#Function to output message to StdErr
function echo_stderr()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./setup-simple-cluster.sh <AKS_PERS_RESOURCE_GROUP> <AKS_CLUSTER_NAME> <AKS_PERS_STORAGE_ACCOUNT_NAME> <AKS_PERS_LOCATION> <AKS_PERS_SHARE_NAME> <DOCKER_USERNAME> <DOCKER_PASSWORD> <DOCKER_EMAIL> <SP_APP_ID> <SP_CLIENT_SECRECT> <SP_TENANT_ID>"  
}

function login()
{
    # login with a service principle
    az login --service-principal --username $SP_APP_ID --password $SP_CLIENT_SECRET --tenant $SP_TENANT_ID
}

function createResourceGroup()
{
    # Create a resource group
    az group create --name $AKS_PERS_RESOURCE_GROUP --location $AKS_PERS_LOCATION
}

function createAndConnectToAKSCluster()
{
    # Create aks cluster, please change parameters as you expected
    az aks create --resource-group $AKS_PERS_RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME \
    --vm-set-type VirtualMachineScaleSets \
    --node-count 3 \
    --generate-ssh-keys \
    --nodepool-name nodepool1 \
    --node-vm-size Standard_D4s_v3 \
    --location $AKS_PERS_LOCATION \
    --service-principal $SP_APP_ID \
    --client-secret $SP_CLIENT_SECRET

    # Connect to AKS cluster
    az aks get-credentials --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
}

function createFileShare()
{
    # Create a storage account
    az storage account create -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -l $AKS_PERS_LOCATION --sku Standard_LRS

    # Export the connection string as an environment variable, this is used when creating the Azure file share
    export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -o tsv)

    # Create the file share
    az storage share create -n $AKS_PERS_SHARE_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING

    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --resource-group $AKS_PERS_RESOURCE_GROUP --account-name $AKS_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

    # Echo storage account name and key
    echo Storage account name: $AKS_PERS_STORAGE_ACCOUNT_NAME
    echo Storage account key: $STORAGE_KEY

    # Create a Kubernetes secret
    kubectl create secret generic azure-secret \
    --from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME \
    --from-literal=azurestorageaccountkey=$STORAGE_KEY

    # Mount the file share as a volume
    kubectl apply -f ${SCRIPT_PWD}/.config/pv.yaml
    kubectl get pv azurefile -o yaml
    kubectl apply -f ${SCRIPT_PWD}/.config/pvc.yaml
    kubectl get pvc azurefile -o yaml
}

function installWebLogicOperator()
{
    # Grant the Helm service account the cluster-admin role
    kubectl apply -f ${SCRIPT_PWD}/.config/grant-helm-role.yaml

    # Print pod stuats
    kubectl -n kube-system get pods

    # Helm
    helmVersion=$(echo `helm version` | grep -Po '(?<=Version:\"v)\d')
    if [ $helmVersion -lt 3 ]
    then 
        helm init
        helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts
        helm repo update
        helm install weblogic-operator/weblogic-operator --name weblogic-operator
    else
        # For Helm 3.x
        helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts
        helm repo update
        helm install weblogic-operator weblogic-operator/weblogic-operator
    fi
}

function createWebLogicDomain()
{
    # Create WebLogic Domain Credentials, please change weblogic username, password, domain name as you expected.
    cd ${SCRIPT_PWD}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
    ./create-weblogic-credentials.sh -u weblogic -p welcome1 -d domain1

    # Create Docker Credentials, please change to your docker account.
    kubectl create secret docker-registry regcred \
    --docker-server=docker.io \
    --docker-username=${DOCKER_USERNAME} \
    --docker-password=${DOCKER_PASSWORD} \
    --docker-email=${DOCKER_EMAIL}

    # Create Weblogic Domain
    cd ${SCRIPT_PWD}/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv
    ./create-domain.sh -i ${SCRIPT_PWD}/.config/domain1.yaml -o ~/azure/output -e -v

    kubectl  apply -f ${SCRIPT_PWD}/.config/admin-lb.yaml
    kubectl  apply -f ${SCRIPT_PWD}/.config/cluster-lb.yaml

    # Print ip address
    kubectl  get svc
}

export SCRIPT_PWD=`pwd`

if [ $# -lt 11 ]
then
    usage
    exit 1
fi

# Change these parameters as needed for your own environment
export AKS_PERS_RESOURCE_GROUP="$1"
export AKS_CLUSTER_NAME="$2"
export AKS_PERS_STORAGE_ACCOUNT_NAME="$3"
export AKS_PERS_LOCATION="$4"
export AKS_PERS_SHARE_NAME="$5"
export DOCKER_USERNAME="$6"
export DOCKER_PASSWORD="$7"
export DOCKER_EMAIL="$8"
export SP_APP_ID="$9"
export SP_CLIENT_SECRET="${10}"
export SP_TENANT_ID="${11}"

echo $AKS_PERS_RESOURCE_GROUP $AKS_CLUSTER_NAME $AKS_PERS_STORAGE_ACCOUNT_NAME

login

createResourceGroup

createAndConnectToAKSCluster

createFileShare

installWebLogicOperator

createWebLogicDomain

cleanup









