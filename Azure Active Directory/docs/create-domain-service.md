This document describe how to create domain service.  

## Create Domain Service
We will follow [Tutorial: Create and configure an Azure Active Directory Domain Services instance](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance) to create domain service.  
Very important steps are listed here:  
1. DNS domain name: if you don't have a verified one, please input a custome domain name, such as wls-security.com, make sure no naming conflicts with existing DNS namespace, we will use secure LDAP, you must register and own this custom domain name to generate the required certificates.  
2. [Update DNS settings for the Azure virtual network](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance#update-dns-settings-for-the-azure-virtual-network), we have to update DNS seetings, otherwise, the domain is not accessible.  
3. [Enable user accounts for Azure AD DS](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-create-instance#enable-user-accounts-for-azure-ad-ds), as we will use cloud-only user to login the domain, we have to reset password. Go to https://myapps.microsoft.com/ and change password. It will take about half an hour for password sync.  

# Step by step  
1. Make sure domain service is enabled in your tanent.  
2. Go to Azure Portal  
3. Create resource group wls-test.  
4. Search Azure AD Domain Services, click Add to add a new one.  
5. Input the following details in Basics section:  
   Resource group: wls-test  
   DNS domain name: wls-security.com  
   Location: East US  
   SKU: Standard  
   Forest type: User  
6. Keep the Networking section as default.  
7. Administration  
   Click AAD DC Administrators group and add the user you created. Users in this group have permission to query and list users of the domain. We will use it in WebLogic LDAP Server configuration.  
   ![Add AAD DC Administrators](images/Add-AADDC-Administrators.PNG)  
8. Click Review and create.  
9. It will take about 2 hours to deploy the service.  
10. Update DNS server setting for your virtual network. After deploy successfully, go to resource group wls-test, and click domain wls-security.com, you will open Overview page. There will be a panel called Required configuration steps, you will see Update DNS server setting for your virtual network, click button Configure to set DNS. It will take several minutes to finish it.  
11. Go to https://myapps.microsoft.com/ and reset you user password, we will use the user to connect ldap server after LDAP configuration.  


