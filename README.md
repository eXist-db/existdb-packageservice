# eXistdb Package Service



Exposes endpoints to read local and remote packages.

The service is intended to be used by front-end applications like
package-manager and dashboard.

Access to certain functions is granted on behalf of the eXistdb
user groups that the user is member of. See section 'Authorization'.

This approach was taken to expose just the information that a certain user is allowed to access.

## Endpoint for local apps

```
/exstdb-packageservice/packages/local
```

will return a list of locally installed packages if the 
current user has at least a 'view-packages' permission.

This endpoint will be used by ``èxistdb-local-packages`` web component.

## Endpoint for remote apps

```
/exstdb-packageservice/packages/remote
```


## Authorization

eXistdb package service was designed with security in mind. It uses its own authorization model to just expose the information a certain user is
allowed to see. There's no client-side parametrization which easily can be manipulated to gain more information
about the system.

Permissions are configured in configuration.xml which should be visited and checked for correct settings before
deploying it. 

## Roles

Three user groups are pre-defined for the package service. These are a mere convenience and need not be used.

For a given context there are 2 approaches to configure the app:

1. uses the pre-defined user groups in the app that accesses the service
1. map existing user groups in your app in configurations.xml

There's no functional difference between the two so either way is fine.

### Package Admin

The package admin role is there in case the user shall be allowed to install and remove packages but shall not
be a database administrator.

* may see all package details
* may install packages
* may remove packages

### Package Manager 

* may see all package details

### Package User

* may see packages with short info

### Guest

By adding or removing the 'guest' user and giving it a similar access-level as the 'package-user' you can
allow or deny guest users access to packages.

By giving 'guest' users a lower access-level than 'package-user' access to packages will be denied. Same
would be achieved by completely removing the 'guest' entry in configuration.xml

## Web Components

existdb-packageservice also provides 2 Polymer Web Components that uses the above endpoints and can be dropped
into your applications.

These are ```<existdb-local-packages>``` and ```existdb-remote-packages```.

### Installing the components



