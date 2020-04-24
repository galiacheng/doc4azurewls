
# Add/Delete WebLogic Cluster Nodes with Azure CLI

This article describes how to add and delete nodes to an existing WebLogic Cluster, which is created with [Azure WebLogic Cluster Application](https://portal.azure.com/#create/oracle.20191007-arm-oraclelinux-wls-cluster20191007-arm-oraclelinux-wls-cluster) from [Azure Portal](https://ms.portal.azure.com/). After doing the following steps in the article, you will add expected managed nodes to your cluster with WebLogic managed server set up, or remove managed nodes from your cluster and deleting the related azure resource.

## Prerequisites  

* Existing WebLogic Cluster Instance  
This article assumes you have set up your cluster with [Azure WebLogic Cluster Application](https://portal.azure.com/#create/oracle.20191007-arm-oraclelinux-wls-cluster20191007-arm-oraclelinux-wls-cluster), if you don't have one, please follow [Get Started with Oracle WebLogic Server on Microsoft Azure IaaS](https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/12.2.1.4/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7) to create one with the following default configuration:  

```
WebLogic Domain Name: clusterDomain
Username for WebLogic Administrator: weblogic
Username for WebLogic Administrator: zaq1XSW2cde3
```

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli?view=azure-cli-latest)  
Login azure cli with `az login` and set your working subscription.  

```
az login
az account set -s your-subscription
```

## Download Add/Delete node template  

Download latest template from https://github.com/galiacheng/arm-oraclelinux-wls-cluster/actions.  
Select the latest build and download `arm-oraclelinux-wls-cluster-addnode-1.0.19-arm-assembly`, `arm-oraclelinux-wls-cluster-deletenode-1.0.0-arm-assembly` from Artifacts, and unzip to your local enviroment.  

## Add nodes  

We have got template of adding note in last step, now we are going to add 2 nodes to your cluster.  
We need OTN account to download JDK and WebLogic installer, if you don't have one, please request it from https://profile.oracle.com/myprofile/account/create-account.jspx.  
Create parameters file `parameters.json`, put it in the same folder with `mainTemplate.json` and input values of parameters. The parameters are used to specify information of existing cluster and configuration of new nodes.  
Besides, we have to specify the location of scripts, please add `_artifactsLocation` and input value as following.  

`Location`: location of your cluster instance.  
`acceptOTNLicenseAgreement`: Y
`adminPasswordOrKey`: your admin password for vm machine that will host new managed nodes.  
`adminURL`: the url of weblogic cluster admin server, should be adminVM:7001, if you use default setting to create weblogic cluster.  
`adminUsername`: your admin user name for vm machine that will host new managed nodes.  
`dnsLabelPrefix`: dns prefix of the managed node address.  
`managedServerPrefix`: prefix of managed server name, used to create managerd server in WebLogic Cluster.  
`numberOfNodes`: expected numbers of new managed nodes.  
`otnAccountPassword`: your otn account password.  
`otnAccountUsername`: your otn account.  
`vmSizeSelect`: size of vm machine.  
`wlsDomainName`: domain name of WebLogic Cluster, default value is clusterDomain.  
`wlsPassword`: password for WebLogic Administrator.  
`wlsPassword`: Username for WebLogic Administrator, default value is weblogic.  

```
{
  "_artifactsLocation":{
	"value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-cluster/master/addnode/src/main/"
  },
  "Location": {
    "value": "eastus"
  },
  "acceptOTNLicenseAgreement": {
    "value": "Y"
  },
  "adminPasswordOrKey": {
    "value": "wlsEng@aug2019"
  },
  "adminURL": {
    "value": "adminVM:7001"
  },
  "adminUsername": {
    "value": "weblogic"
  },
  "dnsLabelPrefix": {
    "value": "wls"
  },
  "managedServerPrefix": {
    "value": "msp"
  },
  "numberOfNodes": {
    "value": 2
  },
  "otnAccountPassword": {
    "value": "password"
  },
  "otnAccountUsername": {
    "value": "youraccount@example.com"
  },
  "vmSizeSelect": {
    "value": "Standard_A1"
  },
  "wlsDomainName": {
    "value": "clusterDomain"
  },
  "wlsPassword": {
    "value": "zaq1XSW2cde3"
  },
  "wlsUserName": {
    "value": "weblogic"
  }
}
```

Deploy addnode template to add nodes to WebLogic Cluster, with az cli.  
```
az group deployment create --verbose --resource-group yourresourcegroup --name addnode --parameters @parameters.json --template-file mainTemplate.json
```

## Delete nodes

Unzip arm-oraclelinux-wls-cluster-deletenode-1.0.0-arm-assembly.zip to your local machine, then you will got template to delete nodes.  
Now we are going to delete two nodes, with managered server name `msp1, msp2`, vitual machine name `mspVM1, mspVM2`.  
Create parameters file `parameters.json`, put it in the same folder with `mainTemplate.json` and input values of parameters. The parameters specify information of existing cluster and details of managed nodes to be deleted.  
Besides, we have to specify the location of scripts, please add `_artifactsLocation` and input value as following. 

`adminVMName`: vm name of which host WebLogic Admin Server, default value is adminVM.  
`deletingManagedServerNames`: msp1,msp2  
`deletingManagedServerMachineNames`: mspVM1,mspVM2  
`wlsUserName`: weblogic  
`wlsPassword`: zaq1XSW2cde3  
`wlsForceShutDown`: false  

```
{
  "_artifactsLocation":{
	"value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-cluster/master/deletenode/src/main/"
  },
  "adminVMName": {
    "value": "adminVM"
  },
  "deletingManagedServerNames": {
    "value": "msp1,msp2"
  },
  "deletingManagedServerMachineNames": {
    "value": "mspVM1,mspVM2"
  },
  "wlsUserName": {
    "value": "weblogic"
  },
  "wlsPassword": {
    "value": "APB9faTHAPB9faTH"
  },
  "wlsForceShutDown": {
    "value": "false"
  }
}
```

Deploy the template to delete managed nodes from WebLogic Cluster.  
```
# please change resource group to yours
az group deployment create --verbose --resource-group wls-cluster-deletenode --name deletenode --parameters @parameters.json --template-file mainTemplate.json
```

After deployment success, will output commands to delete azure resources.  
If you don't want to keep the related azure resource, run the command to delete them.  
Steps to get the output:  
1. Go to Azure Portal https://ms.portal.azure.com  
2. Search "resource" and select `Resource groups`  
3. Find your resource group by input filter and open the resource group  
4. Click Deployments  
5. Click deployment name `deletenode`  
6. Click Outputs  
7. Copy the commands and run with Azure CLI.  

Example outputs:

```
export resourceGroup=wls-cluster-deletenode;export deleteingIDs="";export managedServerMachineNames=$(echo mspVM1,mspVM2 | tr "," "\n");az extension add --name resource-graph;for machine in $managedServerMachineNames;do vmId=$(az graph query -q "Resources | where type =~ \"microsoft.compute/virtualmachines\" | where name=~ \"${machine}\" | where resourceGroup =~ \"${resourceGroup}\" | project vmid = id" -o tsv); nicId=$(az graph query -q "Resources | where type =~ \"microsoft.compute/virtualmachines\" | where name=~ \"${machine}\" | where resourceGroup =~ \"${resourceGroup}\" | extend nics=array_length(properties.networkProfile.networkInterfaces) | mv-expand nic=properties.networkProfile.networkInterfaces | where nics == 1 or nic.properties.primary =~ \"true\" or isempty(nic) | project nicId = tostring(nic.id)" -o tsv);ipId=$(az graph query -q "Resources | where type =~ \"microsoft.network/networkinterfaces\" | where id=~ \"${nicId}\" | extend ipConfigsCount=array_length(properties.ipConfigurations) | mv-expand ipconfig=properties.ipConfigurations | where ipConfigsCount == 1 or ipconfig.properties.primary =~ \"true\" | project publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" -o tsv);osDiskId=$(az graph query -q "Resources | where type =~ \"microsoft.compute/virtualmachines\" | where name=~ \"${machine}\" | where resourceGroup =~ \"${resourceGroup}\" | project osDiskId = tostring(properties.storageProfile.osDisk.managedDisk.id)" -o tsv);dataDiskIds=$(az graph query -q "Resources | where type =~ \"microsoft.compute/virtualmachines\" | where name=~ \"${machine}\" | where resourceGroup =~ \"${resourceGroup}\" | mv-expand datadisk=properties.storageProfile.dataDisks | project datadisk.managedDisk.id" -o tsv);deleteingIDs=$(echo $deleteingIDs ${vmId} ${nicId} ${ipId} ${osDiskId} ${dataDiskIds});done;echo "List ID of resource to be deleted: ";echo ${deleteingIDs} | tr " " "\n";echo -n "Are you sure to delete these resources (y/n)?";read answer;if [ "$answer" != "${answer#[Yy]}" ] ;then az resource delete --verbose --ids ${deleteingIDs};fi
```

Example running result:

```
List ID of resource to be deleted:
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Compute/virtualMachines/mspVM1
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Network/networkInterfaces/mspVM1_NIC
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Network/publicIPAddresses/mspVM1_PublicIP
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/WLS-CLUSTER-DELETENODE/providers/Microsoft.Compute/disks/mspVM1_OsDisk_1_9edff7c5121c40b68e4f0be6062ec0f4
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/WLS-CLUSTER-DELETENODE/providers/Microsoft.Compute/disks/mspVM1_disk2_47d7143c5edf4e7f866a8247b1c650f1
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Compute/virtualMachines/mspVM2
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Network/networkInterfaces/mspVM2_NIC
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/wls-cluster-deletenode/providers/Microsoft.Network/publicIPAddresses/mspVM2_PublicIP
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/WLS-CLUSTER-DELETENODE/providers/Microsoft.Compute/disks/mspVM2_OsDisk_1_9afebca3a279463d9d8ba23331b04d78
/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/WLS-CLUSTER-DELETENODE/providers/Microsoft.Compute/disks/mspVM2_disk2_698615b5b8e14c0c84d6e2d7f5c8dd0b
Are you sure to delete these resources (y/n)?y
[
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null
]
command ran in 119.781 seconds.
```








