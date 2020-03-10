#!/usr/bin/python
# Save Script as : configure_active_directory.py

import time
import getopt
import sys
import re

# Get location of the properties file.
properties = ''
try:
   opts, args = getopt.getopt(sys.argv[1:],"p:h::",["properies="])
except getopt.GetoptError:
   print 'configure_active_directory.py -p <path-to-properties-file>'
   sys.exit(2)
for opt, arg in opts:
   if opt == '-h':
      print 'configure_active_directory -p <path-to-properties-file>'
      sys.exit()
   elif opt in ("-p", "--properties"):
      properties = arg
print 'properties=', properties

# Load the properties from the properties file.
from java.io import FileInputStream
 
propInputStream = FileInputStream(properties)
configProps = Properties()
configProps.load(propInputStream)

# Set all variables from values in properties file.
adminUsername=configProps.get("admin.username")
adminPassword=configProps.get("admin.password")
adminURL=configProps.get("admin.url")
domainName=configProps.get("domain.name")
providerName=configProps.get("provider.name")
adUsername=configProps.get("ad.username")
adPassword=configProps.get("ad.password")
adPrincipal=configProps.get("ad.principal")
adHost=configProps.get("ad.host")
adGroupBaseDN=configProps.get("ad.group.base.dn")
adUserBaseDN=configProps.get("ad.user.base.dn")
adUserNameFilter=configProps.get("ad.user.name.filter")

# Display the variable values.
print 'adminUsername=', adminUsername
print 'adminPassword=', adminPassword
print 'adminURL=', adminURL
print 'domainName=', domainName
print 'providerName=', providerName
print 'adUsername=', adUsername
print 'adPassword=', adPassword
print 'adPrincipal=', adPrincipal
print 'adHost=', adHost
print 'adGroupBaseDN=', adGroupBaseDN
print 'adUserBaseDN=', adUserBaseDN
print 'adUserNameFilter', adUserNameFilter

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

edit()
startEdit()

# Configure DefaultAuthenticator.
cd('/SecurityConfiguration/' + domainName + '/Realms/myrealm/AuthenticationProviders/DefaultAuthenticator')
cmo.setControlFlag('SUFFICIENT')

# Configure Active Directory.
cd('/SecurityConfiguration/' + domainName + '/Realms/myrealm')
cmo.createAuthenticationProvider(providerName, 'weblogic.security.providers.authentication.ActiveDirectoryAuthenticator')

cd('/SecurityConfiguration/' + domainName + '/Realms/myrealm/AuthenticationProviders/' + providerName)
cmo.setControlFlag('OPTIONAL')

cd('/SecurityConfiguration/' + domainName + '/Realms/myrealm')
set('AuthenticationProviders',jarray.array([ObjectName('Security:Name=myrealm' + providerName), ObjectName('Security:Name=myrealmDefaultAuthenticator'), ObjectName('Security:Name=myrealmDefaultIdentityAsserter')], ObjectName))

cd('/SecurityConfiguration/' + domainName + '/Realms/myrealm/AuthenticationProviders/' + providerName)
cmo.setControlFlag('SUFFICIENT')
cmo.setUserNameAttribute(adUsername)
cmo.setUserFromNameFilter(adUserNameFilter)
cmo.setPrincipal(adPrincipal)
cmo.setHost(adHost)
set('Credential', adPassword)
cmo.setGroupBaseDN(adGroupBaseDN)
cmo.setUserBaseDN(adUserBaseDN)
cmo.setPort(636)
cmo.setSSLEnabled(true)
cmo.setConnectTimeout(5)
cmo.setConnectionPoolSize(60)
cmo.setCacheSize(3200)

save()
activate()

disconnect()
exit()