# Set up simple WebLogic cluster on AKS manually

The page describe how to set up simple WebLogic cluster on ASK, we recommand running the following commands with Azure Cloud Shell, without having to install anything on your local environment.  

## Start Azure Cloud Shell
If you don't know how to start Azure Cloud Shell, please go to [Use Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough#use-azure-cloud-shell).   

## Create AKS cluster  
AKS is a managed Kubernetes service that lets you quickly deploy and manage clusters. To learn more, please go to [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/).  We will deploy an Azure Kubernetes Service (AKS) cluster using the Azure CLI.  
```
az aks create \
--resource-group $AKS_PERS_RESOURCE_GROUP \
--name $AKS_CLUSTER_NAME \
--vm-set-type VirtualMachineScaleSets \
--node-count 3 \
--generate-ssh-keys \
--kubernetes-version 1.14.8 \
--nodepool-name nodepool1 \
--node-vm-size Standard_D4s_v3 \
--location $AKS_PERS_LOCATION
```
After the deployment successes, run the fowllowing command to connect to aks instance.  
```
az aks get-credentials --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

To verify the connection to your cluster, use the kubectl get command to return a list of the cluster nodes.  

```
kubectl get nodes
```

Example output:  

```
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-58449474-vmss000000   Ready    agent   2d22h   v1.14.8
aks-nodepool1-58449474-vmss000001   Ready    agent   2d22h   v1.14.8
aks-nodepool1-58449474-vmss000002   Ready    agent   2d22h   v1.14.8
```

## Create storage and set up file share  
We will create external data volume to access and persist data. There are several options for data sharing [Storage options for applications in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/concepts-storage).  
We will use use Azure Files as a Kubernetes volume, click the link to [learn more](https://docs.microsoft.com/en-us/azure/aks/azure-files-volume).  
Create storage account first:  

```
az storage account create \
-n $AKS_PERS_STORAGE_ACCOUNT_NAME \
-g $AKS_PERS_RESOURCE_GROUP \
-l $AKS_PERS_LOCATION \
--sku Standard_LRS
```  

Create a file share. We need storage connection string to create file share, run the the command to get connection string, then create share with az storage share create.  

```
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -o tsv)

az storage share create -n $AKS_PERS_SHARE_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING
```
Create a Kubernetes secret. We need storage key for the secret. Run az storage account keys list to query storage key and use kubectl create secret to create azure-secret.  
```
STORAGE_KEY=$(az storage account keys list --resource-group $AKS_PERS_RESOURCE_GROUP --account-name $AKS_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY
```
Mount the file share as a volume, create a file name pv.yaml, keey share name and secret name same with above setting.  
```
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
```
Create a file name pvc.yaml for PersistentVolumeClaim.  
```
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
```

Use the kubectl command to create the pod.  
```
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
```

Use the command to verify:  

```
kubectl get pv,pvc
``` 
Example output:  
```
NAME        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM               STORAGECLASS   REASON   AGE
azurefile   5Gi        RWX            Retain           Bound    default/azurefile   azurefile               2d21h

NAME        STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS   AGE
azurefile   Bound    azurefile   5Gi        RWX            azurefile      2d21h
```

## Install WebLogic Operator  
Before installing WebLogic Operator, we have to grant the Helm service account the cluster-admin role by running the following command:
```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: helm-user-cluster-admin-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
EOF
```
Install WebLogic Operator:  
```
helm init
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts
helm repo update

# For Helm 3.x
helm install weblogic-operator weblogic-operator/weblogic-operator
```
To verify th operator with command:
```
kubectl get pods -w
```
Output:
```
NAME                                              READY   STATUS      RESTARTS   AGE
weblogic-operator-6655cdc949-x58ts                1/1     Running     0          2d21h
```
## Create WebLogic Domain  
We will use sample script in weblogic operator repo, clone the repo first.
```
git clone https://github.com/oracle/weblogic-kubernetes-operator
```
1. Create domain credentials  
We will use create-weblogic-credentials.sh in weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials.
```
#cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
./create-weblogic-credentials.sh -u weblogic -p welcome1 -d domain1
```
2. Create Docker Credentials for pulling image.
```
kubectl create secret docker-registry regcred \
--docker-server=docker.io \
--docker-username=username \
--docker-password=password \
--docker-email=test@example.com
```
To verify secrets with command:
```
kubectl get secret
```
Output:
```
NAME                                      TYPE                                  DATA   AGE
azure-secret                              Opaque                                2      2d21h
default-token-mwdj8                       kubernetes.io/service-account-token   3      2d22h
domain1-weblogic-credentials              Opaque                                2      2d21h
regcred                                   kubernetes.io/dockerconfigjson        1      2d20h
sh.helm.release.v1.weblogic-operator.v1   helm.sh/release.v1                    1      2d21h
weblogic-operator-secrets                 Opaque                                1      2d21h
```
3. Create Weblogic Domain  
We will use create-domain.sh in weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv to create domain.
Firstly, create a copy of create-domain-inputs.yaml and name domain1.yaml, change the following inputs:
```
image: store/oracle/weblogic:12.2.1.3
imagePullSecretName: regcred
exposeAdminNodePort: true
persistentVolumeClaimName: azurefile
```
Create domain1 with command:
```
#cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv
./create-domain.sh -i domain1.yaml -o ~/azure/output -e -v
```
Output for successful deployment:
```
ToDo
```
4. Create LoadBalancer for admin and cluster  
Create admin-lb.yaml with the following content
```
apiVersion: v1
kind: Service
metadata:
  name: domain1-admin-server-external-lb
  namespace: default
spec:
  ports:
  - name: default
    port: 7001
    protocol: TCP
    targetPort: 7001
  selector:
    weblogic.domainUID: domain1
    weblogic.serverName: admin-server
  sessionAffinity: None
  type: LoadBalancer
```
Create admin loadbalancer.
```
kubectl  apply -f admin-lb.yaml
```
Create cluster-lb.yaml with the following content
```
apiVersion: v1
kind: Service
metadata:
  name: domain1-cluster-1-lb
  namespace: default
spec:
  ports:
  - name: default
    port: 8001
    protocol: TCP
    targetPort: 8001
  selector:
    weblogic.domainUID: domain1
    weblogic.clusterName: cluster-1
  sessionAffinity: None
  type: LoadBalancer
```
Create cluster loadbalancer.
```
kubectl  apply -f cluster-lb.yaml
```
Get address of admin and managed server:
```
kubectl  get svc
```
With output:
```
NAME                               TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)              AGE
domain1-admin-server               ClusterIP      None          <none>           30012/TCP,7001/TCP   2d20h
domain1-admin-server-external      NodePort       10.0.182.50   <none>           7001:30701/TCP       2d20h
domain1-admin-server-external-lb   LoadBalancer   10.0.67.79    52.188.176.103   7001:32227/TCP       2d20h
domain1-cluster-1-lb               LoadBalancer   10.0.112.43   104.45.176.215   8001:30874/TCP       2d17h
domain1-cluster-cluster-1          ClusterIP      10.0.162.19   <none>           8001/TCP             2d20h
domain1-managed-server1            ClusterIP      None          <none>           8001/TCP             2d20h
domain1-managed-server2            ClusterIP      None          <none>           8001/TCP             2d20h
domain1-managed-server3            ClusterIP      None          <none>           8001/TCP             2d17h
domain1-managed-server4            ClusterIP      None          <none>           8001/TCP             2d17h
internal-weblogic-operator-svc     ClusterIP      10.0.192.13   <none>           8082/TCP             2d22h
kubernetes                         ClusterIP      10.0.0.1      <none>           443/TCP              2d22h
```
Address to access admin server: http://52.188.176.103:7001/console
## Deploy sample application  
Go to Admin server and deploy webtestapp.war.  
1. Go to admin server console, click "Lock & Edit"  
2. Click Deployments  
3. Click Install  
4. Choose file webtestapp.war  
6. Leave configuration as default  
7. click finish  
8. Activate changes  
8. Go to Deplyments -> Control -> select webtestapp -> Start -> Servicing all requests  

After successful deployment, go to the application with domain1-cluster-1-lb external ip.  
```
kubectl  get svc domain1-cluster-1-lb

NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)          AGE
domain1-cluster-1-lb   LoadBalancer   10.0.112.43   104.45.176.215   8001:30874/TCP   2d18h
```
Application address is : http://104.45.176.215:8001/webtestapp  
The test application will list the server host and server ip in the page.
## Troubleshooting  
## Useful links
[Quickstart: Deploy an Azure Kubernetes Service cluster using the Azure CLI](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)  
[WebLogic Kubernetes Operator](https://oracle.github.io/weblogic-kubernetes-operator/userguide/introduction/introduction/)  
[Manually create and use a volume with Azure Files share in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/azure-files-volume)  
[Create a Secret by providing credentials on the command line](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line)  

