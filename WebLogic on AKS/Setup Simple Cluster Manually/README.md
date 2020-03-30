# Set up simple WebLogic cluster on AKS manually

The page describe how to set up simple WebLogic cluster on ASK, we recommand running the following commands with Azure Cloud Shell, without having to install anything on your local environment.  

## Start Azure Cloud Shell
If you don't know how to start Azure Cloud Shell, please go to [Use Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#use-azure-cloud-shell).   

## Create AKS cluster  
AKS is a managed Kubernetes service that lets you quickly deploy and manage clusters. To learn more, please go to [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/). We will deploy an Azure Kubernetes Service (AKS) cluster using the Azure CLI.  
``
az aks create --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --vm-set-type VirtualMachineScaleSets --node-count 3 --generate-ssh-keys --kubernetes-version 1.14.8 --nodepool-name nodepool1 --node-vm-size Standard_D4s_v3 --location $AKS_PERS_LOCATION  
``
After the deployment successes, run the fowllowing command to connect to aks instance.  
``
az aks get-credentials --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
``
To verify the connection to your cluster, use the kubectl get command to return a list of the cluster nodes.  
``
kubectl get nodes
``
Example output:  
``
    aks-nodepool1-58449474-vmss000000   Ready    agent   2d20h   v1.14.8
``

## Create storage and set up file share  
We will create external data volume to access and persist data. There are several options for data sharing [Storage options for applications in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/concepts-storage).  
We will use use Azure Files as a Kubernetes volume.  
Create storage account:  
``
az storage account create -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -l $AKS_PERS_LOCATION --sku Standard_LRS
`` 
Create a file share  
``
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -o tsv)

az storage share create -n $AKS_PERS_SHARE_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING
``
Create a Kubernetes secret  
``
STORAGE_KEY=$(az storage account keys list --resource-group $AKS_PERS_RESOURCE_GROUP --account-name $AKS_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY
``
Mount the file share as a volume, create a file name pv.yaml, keey share name and secret name same with above setting.  
``
apiVersion: v1
kind: PersistentVolume
metadata:
  name: azurefile
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  azureFile:
    secretName: azure-secrea
    shareName: weblogic
    readOnly: false
  mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
``
Create a file name pvc.yaml for PersistentVolumeClaim.  
``
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurefile
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  resources:
    requests:
      storage: 5Gi
``

Use the kubectl command to create the pod.  
``
kubectl apply -f pv.yaml

kubectl apply -f pvc.yaml
``
Use the command to verify:  
``
kubectl get pv
kubectl get pvc
`` 
Example output:  
``
NAME        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM               STORAGECLASS   REASON   AGE

azurefile   5Gi        RWX            Retain           Bound    default/azurefile   azurefile               2d21h


NAME        STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS   AGE

azurefile   Bound    azurefile   5Gi        RWX            azurefile      2d21h
``

## Install WebLogic Operator  
## Create WebLogic Domain  
## Deploy sample application  
## Troubleshooting  

https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough
https://oracle.github.io/weblogic-kubernetes-operator/userguide/introduction/introduction/
https://docs.microsoft.com/en-us/azure/aks/azure-files-volume

