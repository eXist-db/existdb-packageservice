# eXistdb Package Service

The packager service bundles some common functions to access package repositories.

See modules/packages.xqm for details


todo: The following still needs another review

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




