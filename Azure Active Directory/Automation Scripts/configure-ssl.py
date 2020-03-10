#!/usr/bin/python
# Save Script as : configure_ssl.py

import time
import getopt
import sys
import re

# Get location of the properties file.
properties = ''
try:
   opts, args = getopt.getopt(sys.argv[1:],"p:h::",["properies="])
except getopt.GetoptError:
   print 'configure_ssl.py -p <path-to-properties-file>'
   sys.exit(2)
for opt, arg in opts:
   if opt == '-h':
      print 'configure_ssl -p <path-to-properties-file>'
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
serverName=configProps.get("ssl.server")
ksTrustPath=configProps.get("ssl.trust.path")
ksTrustPassword=configProps.get("ssl.trust.password")
privateKeyAlias=configProps.get("ssl.privateKeyAlias")
keyPhrase=configProps.get("ssl.keyPhrase")

# Display the variable values.
print 'adminUsername=', adminUsername
print 'adminPassword=', adminPassword
print 'adminURL=', adminURL
print 'serverName=', serverName
print 'ksTrustPath=', ksTrustPath
print 'ksTrustPassword=', ksTrustPassword
print 'privateKeyAlias=', privateKeyAlias
print 'keyPhrase=', keyPhrase

# Connect to the AdminServer.
connect(adminUsername, adminPassword, adminURL)

edit()
startEdit()
print "==============================="
print "set keystore to "+serverName
print "==============================="
cd('/Servers/' + serverName)
cmo.setKeyStores('CustomIdentityAndCustomTrust')
cmo.setCustomTrustKeyStoreFileName(ksTrustPath)
cmo.setCustomTrustKeyStoreType('JKS')
set('CustomTrustKeyStorePassPhrase', ksTrustPassword)
print "==============================="
print "set SSL to "+serverName
print "==============================="
cd('/Servers/' + serverName + '/SSL/' + serverName)
cmo.setServerPrivateKeyAlias(privateKeyAlias)
set('ServerPrivateKeyPassPhrase', keyPhrase)

save()
activate()
disconnect()
exit()