# Set up simple WebLogic cluster on AKS manually

The page describe how to set up simple WebLogic cluster on ASK, we recommand running the following commands with Azure Cloud Shell, without having to install anything on your local environment.  

## Start Azure Cloud Shell
If you don't know how to start Azure Cloud Shell, please go to [Use Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#use-azure-cloud-shell).   

## Create AKS cluster  
AKS is a managed Kubernetes service that lets you quickly deploy and manage clusters. To learn more, please go to [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/). We will deploy an Azure Kubernetes Service (AKS) cluster using the Azure CLI.  
``
az aks create --resource-group $AKS_PERS_RESOURCE_GROUP \  
--name $AKS_CLUSTER_NAME \  
--vm-set-type VirtualMachineScaleSets \  
--node-count 3 \  
--generate-ssh-keys \  
--kubernetes-version 1.14.8 \  
--nodepool-name nodepool1 \  
--node-vm-size Standard_D4s_v3 \  
--location $AKS_PERS_LOCATION  
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
NAME                                STATUS   ROLES   AGE     VERSION  
aks-nodepool1-58449474-vmss000000   Ready    agent   2d20h   v1.14.8  
aks-nodepool1-58449474-vmss000001   Ready    agent   2d20h   v1.14.8  
aks-nodepool1-58449474-vmss000002   Ready    agent   2d20h   v1.14.8  
``

2. Create storage and set up file share  

3. Install WebLogic Operator  
4. Create WebLogic Domain  
5. Deploy sample application  
6. Troubleshooting  

https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough
https://oracle.github.io/weblogic-kubernetes-operator/userguide/introduction/introduction/
https://docs.microsoft.com/en-us/azure/aks/azure-files-volume

