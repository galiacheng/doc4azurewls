#!/bin/sh
# Before running the script, please change the following variables with your information.
# 1. Value of variables: 
#   AKS_PERS_RESOURCE_GROUP
#   AKS_CLUSTER_NAME
#   AKS_PERS_STORAGE_ACCOUNT_NAME
#   AKS_PERS_LOCATION
#   AKS_PERS_SHARE_NAME
# 2. Docker account information, search the command and input your username, password, email.
# kubectl create secret docker-registry regcred \
# --docker-server=docker.io \
# --docker-username=username \
# --docker-password=password \
# --docker-email=test@example.com

export SCRIPT_PWD=`pwd`

# Change these parameters as needed for your own environment
AKS_PERS_RESOURCE_GROUP=wls-aks-simple-cluster$RANDOM
AKS_CLUSTER_NAME=WLSSimpleCluster$RANDOM
AKS_PERS_STORAGE_ACCOUNT_NAME=wlssimplecluster$RANDOM
AKS_PERS_LOCATION=eastus
AKS_PERS_SHARE_NAME=weblogic

echo $AKS_PERS_RESOURCE_GROUP $AKS_CLUSTER_NAME $AKS_PERS_STORAGE_ACCOUNT_NAME

# Create a resource group
az group create --name $AKS_PERS_RESOURCE_GROUP --location $AKS_PERS_LOCATION

# Create aks cluster, please change parameters as you expected
az aks create --resource-group $AKS_PERS_RESOURCE_GROUP \
--name $AKS_CLUSTER_NAME \
--vm-set-type VirtualMachineScaleSets \
--node-count 3 \
--generate-ssh-keys \
--kubernetes-version 1.14.8 \
--nodepool-name nodepool1 \
--node-vm-size Standard_D4s_v3 \
--location $AKS_PERS_LOCATION \
--enable-addons http_application_routing

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

# Connect to AKS cluster
az aks get-credentials --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME

# Create a Kubernetes secret
kubectl create secret generic azure-secret \
--from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME \
--from-literal=azurestorageaccountkey=$STORAGE_KEY

# Mount the file share as a volume
kubectl apply -f ${SCRIPT_PWD}/pv.yaml
kubectl get pv azurefile -o yaml
kubectl apply -f ${SCRIPT_PWD}/pvc.yaml
kubectl get pvc azurefile -o yaml

# Grant the Helm service account the cluster-admin role
kubectl apply -f ${SCRIPT_PWD}/grantHelmRole.yaml

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

# Create WebLogic Domain Credentials, please change weblogic username, password, domain name as you expected.
git clone https://github.com/oracle/weblogic-kubernetes-operator
cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
./create-weblogic-credentials.sh -u weblogic -p welcome1 -d domain1

# Create Docker Credentials, please change to your docker account.
kubectl create secret docker-registry regcred \
--docker-server=docker.io \
--docker-username=username \
--docker-password=password \
--docker-email=test@example.com

# Create Weblogic Domain
cd ../create-weblogic-domain/domain-home-on-pv
./create-domain.sh -i ${SCRIPT_PWD}/domain1.yaml -o ~/azure/output -e -v

kubectl  apply -f ${SCRIPT_PWD}/admin-lb.yaml
kubectl  apply -f ${SCRIPT_PWD}/cluster-lb.yaml

# Print ip address
kubectl  get svc