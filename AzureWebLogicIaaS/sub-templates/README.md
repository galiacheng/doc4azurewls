
# Run Sub-tempalte with Az CLI

This article introduces how to run Azure WebLogic Offer sub-template with az cli.


Table of Contents
=================

[Prerequisites](#prerequisites)  
[Database Template](#database-template) 

## Prerequisites

### WebLogic Server Instance

All the sub tempates will be applied to an existing WebLogic Server instance.  If you don't have one, please create a new instance from Azure portal, links to WebLogic offers are available from [Oracle WebLogic Server 12.2.1.3](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/oracle.oraclelinux-wls-cluster?tab=Overview).  

### Environment for Setup

* [Git](https://git-scm.com/downloads), use `git --version` to test if `git` works.
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.
* [JDK](https://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html), use `java -version` to test if `java` works. 
* [maven](https://maven.apache.org/download.cgi), use `mvn --version` to test if `mvn` works. 

### Clone and Build WebLogic Server Offer

Clone the repository from address of the following steps, and run this command to buid the template.  

```
mvn clean install
```

Templates will output to target folder, we will use sub tempaltes in target/arm/nestedtemplates to deploy service into existing WebLogic Server instance.  

## Database Template

### Before you begin

To apply database to Weblogic Server, you must have an existing database instance to use. Three kinds of database are available now, Oracle, SQL Server, and Postgresql. If you do not have an instance, please create from Azure portal.

We will use Postgresql in the sample parameters, please change the value to your instance.  

### Deploy Database Template

Clone and build repository with command:

```
# Admin offer
git clone https://github.com/wls-eng/arm-oraclelinux-wls-admin
# Cluster offer 
# git clone https://github.com/wls-eng/arm-oraclelinux-wls-cluster
# Dynamic Cluster offer
# git clone https://github.com/wls-eng/arm-oraclelinux-wls-dynamic-cluster

cd arm-oraclelinux-wls-admin
# cd arm-oraclelinux-wls-cluster
# cd arm-oraclelinux-wls-dynamic-cluster
mvn clean install

cd target/arm/nestedtemplates
```

Create parameters.json with the following variables, and change the value to your value, or you can find the sample parameters from [parameters/db-parameters-admin.json](parameters/db-parameters-admin.json).
 

Please change _artifactsLocation to `https://raw.githubusercontent.com/wls-eng/arm-oraclelinux-wls-cluster/master/arm-oraclelinux-wls-cluster/src/main/arm/` for cluster offer and `https://raw.githubusercontent.com/wls-eng/arm-oraclelinux-wls-dynamic-cluster/master/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/` for dynamic cluster offer.

```
{
    "_artifactsLocation":{
        "value": "https://raw.githubusercontent.com/wls-eng/arm-oraclelinux-wls-admin/master/src/main/arm/"
      },
      "_artifactsLocationSasToken":{
        "value": ""
      },
      "location": {
        "value": "eastus"
      },
      "databaseType": {
        "value": "postgresql"
      },
      "dsConnectionURL": {
        "value": "jdbc:postgresql://oraclevm.postgres.database.azure.com:5432/postgres"
      },
      "dbPassword": {
        "value": "<db-psw>"
      },
      "dbUser": {
        "value": "<db-user>"
      },
      "jdbcDataSourceName": {
        "value": "jdbc/WebLogicDB"
      },
      "wlsPassword": {
        "value": "<wls-psw>"
      },
      "wlsUserName": {
        "value": "<wls-user>"
      }
    }
``` 

Replace the following parameters and run the command to apply database service to your WebLogic Server.  

```
RESOURCE_GROUP=<resource-group-of-your-weblogic-server-instance>

# cd arm-oraclelinux-wls-admin\target\arm\nestedtemplates
# Create parameters.json with above variables, and place it in the same folder with dbTemplate.json.
az group deployment create --verbose --resource-group $RESOURCE_GROUP --name cli --parameters @parameters.json --template-file dbTemplate.json
```

You will not get any error if the database service is deployed successfully.

This is an example output of successful deployment.  

```
{
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Resources/deployments/cli2",
  "location": null,
  "name": "cli2",
  "properties": {
    "correlationId": "6fc805b9-1c47-4b32-b9b0-59745a21e559",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-admin-0602",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Resources/deployments/3b35b279-0e94-5264-85f5-0d9d662f8a38",
        "resourceGroup": "oraclevm-admin-0602",
        "resourceName": "3b35b279-0e94-5264-85f5-0d9d662f8a38",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT17.4377546S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-admin-0602"
      }
    ],
    "outputs": {
      "artifactsLocationPassedIn": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      },
      "_artifactsLocationDbTemplate": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "databaseType": {
        "type": "String",
        "value": "postgresql"
      },
      "dbPassword": {
        "type": "SecureString"
      },
      "dbUser": {
        "type": "String",
        "value": "weblogic@oraclevm"
      },
      "dsConnectionURL": {
        "type": "String",
        "value": "jdbc:postgresql://oraclevm.postgres.database.azure.com:5432/postgres"
      },
      "jdbcDataSourceName": {
        "type": "String",
        "value": "jdbc/WebLogicCafeDB"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "wlsPassword": {
        "type": "SecureString"
      },
      "wlsUserName": {
        "type": "String",
        "value": "weblogic"
      }
    },
    "parametersLink": null,
    "providers": [
      {
        "id": null,
        "namespace": "Microsoft.Resources",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              null
            ],
            "properties": null,
            "resourceType": "deployments"
          }
        ]
      },
      {
        "id": null,
        "namespace": "Microsoft.Compute",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "virtualMachines/extensions"
          }
        ]
      }
    ],
    "provisioningState": "Succeeded",
    "template": null,
    "templateHash": "6381424766408193665",
    "templateLink": null,
    "timestamp": "2020-06-02T06:05:03.141828+00:00"
  },
  "resourceGroup": "oraclevm-admin-0602",
  "type": "Microsoft.Resources/deployments"
}

```


