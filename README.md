# eXistdb Package Service

Exposes endpoints to read local and remote packages.

## Endpoint for local apps

```
/exstdb-packageservice/packages/local
```

will return a list of locally installed packages if the 
current user has at least a 'view-packages' permission.

Access to certain functions are granted on behalf of the eXistdb
user groups that the user is member of.

The service is intended to be used by other front-end applications like
package-manager and dashboard.

There are 

## Authorization

Permissions are configured in configuration.xml.

There are 3 possible roles for Package Service as described below.

### Package Admin

* may see all package details
* may add packages
* may remove packages

### Package Manager 

* may see all package details

### Package User

* may see packages with short info



