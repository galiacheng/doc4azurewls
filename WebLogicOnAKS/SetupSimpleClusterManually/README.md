# Set up simple WebLogic cluster on AKS manually

This article shows how to use the [Oracle WebLogic Kubernetes
Operator](https://oracle.github.io/weblogic-kubernetes-operator/)
(hereafter "the Operator") to set up WebLogic cluster on Azure
Kubernetes Service (AKS). After completing this article, your WebLogic
cluster domain runs on an AKS cluster instance and you can manage your
WebLogic domain with a browser by accessing WebLogic Server Console
portal.

Table of Contents
=================

[Prerequisites](#prerequisites)  
[Create AKS cluster](#create-aks-cluster)  
[Create storage and set up file share](#create-storage-and-set-up-file-share)  
[Install WebLogic Operator](#install-weblogic-operator)  
[Create WebLogic Domain](#create-weblogic-domain)  
[Automation](#automation)  
[Deploy sample application](#deploy-sample-application)  
[Access WebLogic logs](#access-weblogic-logs)  
[Troubleshooting](#troubleshooting)  
[Useful links](#useful-links)  

## Prerequisites

This article assumes the following prerequisites.

### Local Environment

* OS: Linux, Unix, [WSL for Windows 10](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure)

* [kubectl](https://kubernetes-io-vnext-staging.netlify.com/docs/tasks/tools/install-kubectl/)

* [helm](https://helm.sh/docs/intro/install/), version 3.1 and above

### Azure Cloud Shell

Azure Cloud Shell already has the necessary prerequisites installed. To
start Azure Cloud Shell, please go to [Overview of Azure Cloud
Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview).

## Create Azure Kubernetes Service (AKS) cluster

AKS is a managed Kubernetes service that lets you quickly deploy and
manage clusters. To learn more, please go to [Azure Kubernetes Service
(AKS)](https://docs.microsoft.com/en-us/azure/aks/).  We will deploy an
Azure Kubernetes Service (AKS) cluster using the Azure CLI.

We will disable http-appliaction-routing by default, if you want to
enable http_application_routing, please follow [HTTP application
routing](https://docs.microsoft.com/en-us/azure/aks/http-application-routing).

If you run commands in your local environment, please run az login and
az account set to login to Azure and set your working subscription
first.

```
# login
az login

# set subscription
az account set -s your-subscription
```

Run the following commands to create AKS cluster instance.

```
# Change these parameters as needed for your own environment
AKS_CLUSTER_NAME=WLSSimpleCluster
AKS_PERS_RESOURCE_GROUP=wls-simple-cluster
AKS_PERS_LOCATION=eastus

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

After the deployment finishes, run the fowllowing command to connect to
AKS cluster.  This command updates your local `~/.kube/config` so that
subsequent `kubectl` commands interact with the named AKS cluster.

```
az aks get-credentials --resource-group $AKS_PERS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

To verify the connection to your cluster, use the kubectl get command to
return a list of the cluster nodes.

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

Our usage pattern for the Operator involves creating Kubernetes
"persistent volumes" to allow WebLogic to persist its configuration and
data separately from the Kubernetes pods that run WebLogic workloads.

We will create external data volume to access and persist data. There
are several options for data sharing [Storage options for applications
in Azure Kubernetes Service
(AKS)](https://docs.microsoft.com/en-us/azure/aks/concepts-storage).

We will use use Azure Files as a Kubernetes volume.  Consult the [Azure
Files
Documentation](https://docs.microsoft.com/en-us/azure/aks/azure-files-volume)
for details about this full featured cloud storage solution.  

Create storage account first:

```
# Change the value as needed for your own environment
AKS_PERS_STORAGE_ACCOUNT_NAME=wlssimplestorageacct

az storage account create \
   -n $AKS_PERS_STORAGE_ACCOUNT_NAME \
   -g $AKS_PERS_RESOURCE_GROUP \
   -l $AKS_PERS_LOCATION \
   --sku Standard_LRS
```

Create a file share. We need a storage connection string to create the
file share.  Run the `show-connection-string` command to get connection
string, then create the share with `az storage share create`, as shown
here.

```
# Change value as needed for your own environment
AKS_PERS_SHARE_NAME=weblogic

export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $AKS_PERS_STORAGE_ACCOUNT_NAME -g $AKS_PERS_RESOURCE_GROUP -o tsv)

az storage share create -n $AKS_PERS_SHARE_NAME --connection-string $AZURE_STORAGE_CONNECTION_STRING
```

Create a Kubernetes secret. We need storage key for the secret. Run `az
storage account keys` list to query storage key and use `kubectl create
secret` to create an `azure-secret`.

```
STORAGE_KEY=$(az storage account keys list --resource-group $AKS_PERS_RESOURCE_GROUP --account-name $AKS_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)

kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=$AKS_PERS_STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$STORAGE_KEY
```

Mount the file share as a persistent volume, create file `pv.yaml` with
the following content, use the `shareName` (weblogic in this example)
and `secretName` (azure-secret in this example) from the above settings.

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
    secretName: azure-secret
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

Create file `pvc.yaml` with the following content for
PersistentVolumeClaim.  Both `pv.yaml` and `pvc.yaml` have exactly the
same content in the `metadata` and `storageClassName`.  This is
required.

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

Use the `kubectl` command to create the persistent volume and persistent volume claim.

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

Carefully inspect the output and verify it matches the above.  `ACCESS
MODES`, `CLAIM`, and `STORAGECLASS` are vital.


## Install WebLogic Operator

Oracle WebLogic Server Kubernetes Operator (the Operator) is an adapter
to integrate WebLogic Server and Kubernetes, allowing Kubernetes to
serve as a container infrastructure hosting WebLogic Server instances.

The official Oracle documentation for the Operator is
[https://oracle.github.io/weblogic-kubernetes-operator/](https://oracle.github.io/weblogic-kubernetes-operator/).

The steps in this document use files from the GitHub repo of the
Operator, at version v2.5.0.  Clone the Operator from GitHub, and check
out the v2.5.0 tag.

```
git clone https://github.com/oracle/weblogic-kubernetes-operator
cd weblogic-kubernetes-operator/
git checkout v2.5.0
```

Kubernetes operators use [Helm](https://helm.sh/) to manage Kubernetes
applications.  We must to grant the Helm service account with the
cluster-admin role with the following command.

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

Install WebLogic Operator, The operator’s Helm chart is located in the
`kubernetes/charts/weblogic-operator` directory. Please check helm version
first if you are using Azure Cloud Shell, and run the corresponding
command.

```
# get helm version
helm version

# For helm 2.x
helm init
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts
helm repo update
helm install weblogic-operator/weblogic-operator --name weblogic-operator

# For Helm 3.x
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts
helm repo update
helm install weblogic-operator weblogic-operator/weblogic-operator
```

To verify the operator with command, status should be running.

```
kubectl get pods -w
```

Output:

```
NAME                                              READY   STATUS      RESTARTS   AGE
weblogic-operator-6655cdc949-x58ts                1/1     Running     0          2d21h
```
## Create WebLogic Domain

We will use sample script in weblogic operator repository.

1. Create domain credentials We will use
   `create-weblogic-credentials.sh` in
   `weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials`
   to create domain credentials.

```
#cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain-credentials
./create-weblogic-credentials.sh -u weblogic -p welcome1 -d domain1
```

2. Create Docker Credentials for pulling image, please change
   `docker-username`, `docker-password`, `docker-email` to your
   DockerHub account.

   If you don't have a docker account, please sign up in [docker
   hub](https://www.docker.com/), then checkout [Oracle WebLogic
   Server](https://hub.docker.com/_/oracle-weblogic-server-12c), we will
   use 12.2.1.3.

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

   We will use `create-domain.sh` in
   `weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv`
   to create the domain in the persistent volume you created previously.

   Firstly, create a copy of `create-domain-inputs.yaml` named `domain1.yaml`, and change the following inputs.

   * `image`: change to docker path of the image, with value `store/oracle/weblogic:12.2.1.3`.
   * `imagePullSecretName`: uncomment the line, and change it to docker credential you create just now, named `regcred` in this example.
   * `exposeAdminNodePort`: set true, as we will use admin console portal to manage WebLogic Server.
   * `persistentVolumeClaimName`: we will persist data to azurefile in this example.
   
   Here is an example:

   ```
   image: store/oracle/weblogic:12.2.1.3
   imagePullSecretName: regcred
   exposeAdminNodePort: true
   persistentVolumeClaimName: azurefile
   ```

   Create `domain1` with command:

   ```
   #cd weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-on-pv
   ./create-domain.sh -i domain1.yaml -o ~/azure/output -e -v
   ```

   The following example output shows weblogic domain is created successfully.

   ```
   NAME: weblogic-operator
   LAST DEPLOYED: Mon Mar 30 10:29:58 2020
   NAMESPACE: default
   STATUS: deployed
   REVISION: 1
   TEST SUITE: None
   fatal: destination path 'weblogic-kubernetes-operator' already exists and is not an empty directory.
   secret/domain1-weblogic-credentials created
   secret/domain1-weblogic-credentials labeled
   The secret domain1-weblogic-credentials has been successfully created in the default namespace.
   secret/regcred created
   Input parameters being used
   export version="create-weblogic-sample-domain-inputs-v1"
   export adminPort="7001"
   export adminServerName="admin-server"
   export domainUID="domain1"
   export domainHome="/shared/domains/domain1"
   export serverStartPolicy="IF_NEEDED"
   export clusterName="cluster-1"
   export configuredManagedServerCount="5"
   export initialManagedServerReplicas="2"
   export managedServerNameBase="managed-server"
   export managedServerPort="8001"
   export image="store/oracle/weblogic:12.2.1.3"
   export imagePullPolicy="IfNotPresent"
   export imagePullSecretName="regcred"
   export productionModeEnabled="true"
   export weblogicCredentialsSecretName="domain1-weblogic-credentials"
   export includeServerOutInPodLog="true"
   export logHome="/shared/logs/domain1"
   export t3ChannelPort="30012"
   export exposeAdminT3Channel="false"
   export adminNodePort="30701"
   export exposeAdminNodePort="true"
   export namespace="default"
   javaOptions=-Dweblogic.StdoutDebugEnabled=false
   export persistentVolumeClaimName="azurefile"
   export domainPVMountPath="/shared"
   export createDomainScriptsMountPath="/u01/weblogic"
   export createDomainScriptName="create-domain-job.sh"
   export createDomainFilesDir="wlst"
   export istioEnabled="false"
   export istioReadinessPort="8888"

   Generating /home/haixia/azure/output/weblogic-domains/domain1/create-domain-job.yaml
   Generating /home/haixia/azure/output/weblogic-domains/domain1/delete-domain-job.yaml
   Generating /home/haixia/azure/output/weblogic-domains/domain1/domain.yaml
   Checking to see if the secret domain1-weblogic-credentials exists in namespace default
   Checking if the persistent volume claim azurefile in NameSpace default exists
   The persistent volume claim azurefile already exists in NameSpace default
   configmap/domain1-create-weblogic-sample-domain-job-cm created
   Checking the configmap domain1-create-weblogic-sample-domain-job-cm was created
   configmap/domain1-create-weblogic-sample-domain-job-cm labeled
   Checking if object type job with name domain1-create-weblogic-sample-domain-job exists
   No resources found in default namespace.
   Creating the domain by creating the job /home/haixia/azure/output/weblogic-domains/domain1/create-domain-job.yaml
   job.batch/domain1-create-weblogic-sample-domain-job created
   Waiting for the job to complete...
   Error from server (BadRequest): container "create-weblogic-sample-domain-job" in pod "domain1-create-weblogic-sample-domain-job-p5htr" is waiting to start: PodInitializing
   status on iteration 1 of 20
   pod domain1-create-weblogic-sample-domain-job-p5htr status is Init:0/1
   Error from server (BadRequest): container "create-weblogic-sample-domain-job" in pod "domain1-create-weblogic-sample-domain-job-p5htr" is waiting to start: PodInitializing
   status on iteration 2 of 20
   pod domain1-create-weblogic-sample-domain-job-p5htr status is Init:0/1
   status on iteration 3 of 20
   pod domain1-create-weblogic-sample-domain-job-p5htr status is Completed
   domain.weblogic.oracle/domain1 created

   Domain domain1 was created and will be started by the WebLogic Kubernetes Operator

   Administration console access is available at http://wlssimplec-wls-aks-simple-c-685ba0-35aaf494.hcp.eastus.azmk8s.io:30701/console
   The following files were generated:
     /home/haixia/azure/output/weblogic-domains/domain1/create-domain-inputs.yaml
     /home/haixia/azure/output/weblogic-domains/domain1/create-domain-job.yaml
     /home/haixia/azure/output/weblogic-domains/domain1/domain.yaml

   Completed
   ```
   
   If your output does not show a successful completion, you must
   troubleshoot the reason and resolve it before proceeding to the next
   step.

4. In order to expose the power of WebLogic to the outside world, you
   must create a `LoadBalancer` for the admin and cluster

   Create `admin-lb.yaml` with the following content:

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

   Create the admin loadbalancer service.

   ```
   kubectl  apply -f admin-lb.yaml
   ```

   Create `cluster-lb.yaml` with the following content

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

   Create the cluster loadbalancer service.

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
   internal-weblogic-operator-svc     ClusterIP      10.0.192.13   <none>           8082/TCP             2d22h
   kubernetes                         ClusterIP      10.0.0.1      <none>           443/TCP              2d22h
   ```
   Address to access admin server: http://52.188.176.103:7001/console

## Automation

If you want automation for above steps, please clone this repo to your
machine and run [setup-simple-cluster.sh](setup-simple-cluster.sh).

The script will create resource group, AKS instance with 3 nodes,
storage account, create file share, and set up weblogic

```
bash setup-simple-cluster.sh new-resource-group-name new-aks-name new-storage-account-name location file-share-name docker-username docker-password docker-emai

```

It will print server ip address after successful deployment.

If the external ip status if pending, you can also get the server
information with the command:

```
kubectl  get svc
```

## Deploy sample application

Go to Admin server and deploy webtestapp.war.

1. Go to admin server console, click "Lock & Edit"
2. Click Deployments
3. Click Install
4. Select file webtestapp.war
5. Next. Install this deployment as an application
6. Next. Select cluster-1 and All servers in the cluster
7. Keep configuration as default and click Finish
8. Activate Changes
![Deploy Application](pictures/screenshot-deploy-test-app.PNG)

Start deployment:

1. Go to Deplyments
2. Click Control
3. select webtestapp
4. Start
5. Servicing all requests

After successful deployment, go to the application with domain1-cluster-1-lb external ip.

```
kubectl  get svc domain1-cluster-1-lb

NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)          AGE
domain1-cluster-1-lb   LoadBalancer   10.0.112.43   104.45.176.215   8001:30874/TCP   2d18h
```

Application address is : http://104.45.176.215:8001/webtestapp

The test application will list the server host and server ip in the
page.

## Access WebLogic logs

Logs are stored in azure file share, following the steps to access log:

1. Go to Azure portal https://ms.portal.azure.com
2. Go to your resource group
3. Open the storage account
4. Go to file service
5. Click file share
6. Click file share name(e.g. weblogic in this example)
7. Click logs
8. Click domain1
   WebLogic Server logs are listed in the folder.
   ![WebLogic Logs](pictures/screenshot-logs.PNG)

## Troubleshooting

1. Get pod error details

   You may get the following message while creating weblogic domain: "the job status is not Completed!"

   ```
   status on iteration 20 of 20
   pod domain1-create-weblogic-sample-domain-job-nj7wl status is Init:0/1
   The create domain job is not showing status completed after waiting 300 seconds.
   Check the log output for errors.
   Error from server (BadRequest): container "create-weblogic-sample-domain-job" in pod "domain1-create-weblogic-sample-domain-job-nj7wl" is waiting to start: PodInitializing
   [ERROR] Exiting due to failure - the job status is not Completed!
   ```

   You can get detail error message by running `kubectl describe pod`,
   as shown here.

   ```
   # replace domain1-create-weblogic-sample-domain-job-nj7wl with your pod name
   kubectl describe pod domain1-create-weblogic-sample-domain-job-nj7wl
   ```
   Error example:

   ```
   Events:
     Type     Reason       Age                  From                                        Message
     ----     ------       ----                 ----                                        -------
     Normal   Scheduled    4m2s                 default-scheduler                           Successfully assigned default/domain1-create-weblogic-sample-domain-job-qqv6k to aks-nodepool1-58449474-vmss000001
     Warning  FailedMount  119s                 kubelet, aks-nodepool1-58449474-vmss000001  Unable to mount volumes for pod "domain1-create-weblogic-sample-domain-job-qqv6k_default(15706980-73cb-11ea-b804-b2c91b494b00)": timeout expired waiting for volumes to attach or mount for pod "default"/"domain1-create-weblogic-sample-domain-job-qqv6k". list of unmounted volumes=[weblogic-sample-domain-storage-volume]. list of unattached volumes=[create-weblogic-sample-domain-job-cm-volume weblogic-sample-domain-storage-volume weblogic-credentials-volume default-token-zr7bq]
     Warning  FailedMount  114s (x9 over 4m2s)  kubelet, aks-nodepool1-58449474-vmss000001  MountVolume.SetUp failed for volume "azurefile" : Couldn't get secret default/azure-secrea
     ```
2. Fail to access Admin Console

   There are different cases for Admin Console failure.
   
   * Create weblogic domain job fails

   You can check deloy log and find the failure details with kubectl
   describe pod podname, please go to 1.Get pod error details.

   * Process of start Admin Server is still running.

   Check with kubectl get svc and if domain1-admin-server is not listed,
   we need to wait some seconds for Admin Server starts.

   The following output is an example that Admin Server starts.

   ```
   NAME                               TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)              AGE
   domain1-admin-server               ClusterIP      None          <none>          30012/TCP,7001/TCP   7m3s
   domain1-admin-server-external      NodePort       10.0.78.211   <none>          7001:30701/TCP       7m3s
   domain1-admin-server-external-lb   LoadBalancer   10.0.6.144    40.71.233.81    7001:32758/TCP       7m32s
   domain1-cluster-1-lb               LoadBalancer   10.0.29.231   52.142.39.152   8001:31022/TCP       7m30s
   domain1-cluster-cluster-1          ClusterIP      10.0.80.134   <none>          8001/TCP             1s
   domain1-managed-server1            ClusterIP      None          <none>          8001/TCP             1s
   domain1-managed-server2            ClusterIP      None          <none>          8001/TCP             1s
   internal-weblogic-operator-svc     ClusterIP      10.0.1.23     <none>          8082/TCP             9m59s
   kubernetes                         ClusterIP      10.0.0.1      <none>          443/TCP              16m
   ```

## Useful links

[Quickstart: Deploy an Azure Kubernetes Service cluster using the Azure CLI](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)  
[WebLogic Kubernetes Operator](https://oracle.github.io/weblogic-kubernetes-operator/userguide/introduction/introduction/)  
[Manually create and use a volume with Azure Files share in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/azure-files-volume)  
[Create a Secret by providing credentials on the command line](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line)

