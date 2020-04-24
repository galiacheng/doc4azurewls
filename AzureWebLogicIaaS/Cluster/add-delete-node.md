
# Add/Delete WebLogic Cluster Nodes

This article describes how to add nodes to an existing WebLogic Cluster, which is created with [Azure WebLogic Cluster Application](https://portal.azure.com/#create/oracle.20191007-arm-oraclelinux-wls-cluster20191007-arm-oraclelinux-wls-cluster) from [Azure Portal](https://ms.portal.azure.com/), and delete nodes from the existing WebLogic Cluster. After doing following the article, you will add managed nodes to your cluster with WebLogic managed server set up, or remove managed nodes from your cluster and deleting the related azure resource.

## Prerequisites  

* Existing WebLogic Cluster Instance  
This article assumes you have set up your cluster with [Azure WebLogic Cluster Application](https://portal.azure.com/#create/oracle.20191007-arm-oraclelinux-wls-cluster20191007-arm-oraclelinux-wls-cluster), if you don't have one, please follow [Get Started with Oracle WebLogic Server on Microsoft Azure IaaS](https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/12.2.1.4/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7) to create one with the following default configuration:  
We will use those configuration to aad/delete nodes.  

```
WebLogic Domain Name: clusterDomain
Username for WebLogic Administrator: weblogic
Username for WebLogic Administrator: zaq1XSW2cde3

```

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli?view=azure-cli-latest)  
* [JDK 1.8](https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html)  
* [Maven](https://maven.apache.org/download.cgi)  
* [Git](https://git-scm.com/downloads)  

## Build Add/Delete node template  
Now we only allow add/delete node by deploying ARM teamplate with Azure CLI. We will use the source code from [wls-eng/arm-oraclelinux-wls-cluster](https://github.com/wls-eng/arm-oraclelinux-wls-cluster) to build the template of adding/deleting node. The repo depends on [azure/azure-javaee-iaas](https://github.com/Azure/azure-javaee-iaas).  Clone the parent repo first and then clone the cluster repo.  

Clone the source code to your enviroment with `git clone`  
```
git clone https://github.com/Azure/azure-javaee-iaas.git
git clone https://github.com/wls-eng/arm-oraclelinux-wls-cluster.git
```

Build azure-javaee-iaas  

```
cd azure-javaee-iaas
mvn clean install
```

Build the teamplate with `mvn clean install`, please run the command in the top level of the repo.  

```
cd arm-oraclelinux-wls-cluster
mvn -Ptemplate-validation-tests clean install
```

Template of adding node outputs to `arm-oraclelinux-wls-cluster/addnode/target/arm`, template of deleting node outputs to `arm-oraclelinux-wls-cluster/deletenode/target/arm`.  

## Add nodes  

We have got template of adding note in last step, now we are going to add 2 nodes to your cluster.  
We need OTN account to download JDK and WebLogic installer, if you don't have one, please request it from https://profile.oracle.com/myprofile/account/create-account.jspx.  
Create parameters files, rename addnodedeploy.parameters.json as parameters.json, and input values of parameters. The parameters are used to specify information of existing cluster and configuration of new nodes.  
Besides, we have to specify the location of scripts, please add `_artifactsLocation` and input value as following.  
Location: location of your cluster instance.  
acceptOTNLicenseAgreement: Y
adminPasswordOrKey: your admin password for vm machine that will host new managed nodes.  
adminURL: the url of weblogic cluster admin server, should be adminVM:7001, if you use default setting to create weblogic cluster.  
adminUsername: your admin user name for vm machine that will host new managed nodes.  
dnsLabelPrefix: dns prefix of the managed node address.  
managedServerPrefix: prefix of managed server name, used to create managerd server in WebLogic Cluster.  
numberOfNodes: expected numbers of new managed nodes.  
otnAccountPassword: your otn account password.  
otnAccountUsername: your otn account.  
vmSizeSelect: size of vm machine.  
wlsDomainName: domain name of WebLogic Cluster, default value is clusterDomain.  
wlsPassword: password for WebLogic Administrator.  
wlsPassword: Username for WebLogic Administrator, default value is weblogic.  

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






