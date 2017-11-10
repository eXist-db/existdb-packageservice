xquery version "3.0";

(:~
: User: joern
: Date: 07.04.17
: Time: 11:44
: To change this template use File | Settings | File Templates.
:)

import module namespace packages="http://exist-db.org/apps/existdb-packages" at "packages.xqm";

<repo-packages>
    {packages:get-local-applications()}
</repo-packages>