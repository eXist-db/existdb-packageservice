xquery version "3.0";

module namespace packages="http://exist-db.org/apps/dashboard/packages/rest";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";


import module namespace functx = "http://www.functx.com";


import module namespace console="http://exist-db.org/xquery/console";

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace http="http://expath.org/ns/http-client";


declare option output:method "html5";
declare option output:media-type "text/html";


declare variable $packages:DEFAULTS := doc($config:app-root || "/defaults.xml")/apps;

declare variable $packages:ADMINAPPS := ["dashboard","backup"];

declare variable $packages:HIDE := ("dashboard");

declare function packages:get-local-packages-raw(){
    let $log := util:log("info", "user: " || xmldb:get-current-user())

    let $apps :=  packages:installed-apps()
    let $allowed-apps :=
         for $app in $apps
             let $db-path := "/db/" || substring-after(data($app/url),"/exist/")

             let $log := util:log("info", "app url " || data($app/url))
             let $log := util:log("info", "db url " || $db-path)
             let $log := util:log("info", "app access " || sm:has-access(xs:anyURI($db-path),"r-x"))
             let $groups := sm:get-user-groups(xmldb:get-current-user())

             order by upper-case($app/title/text())
             return
                 if(sm:has-access(xs:anyURI($db-path),"r-x")) then
                     $app
                 else ()

    return
        if($allowed-apps) then(
            $allowed-apps
        )
        else (
            <no-packages>You do not have sufficient priviledges to view packages</no-packages>
        )
};

declare function packages:get-remote-packages-raw(){

    let $apps := packages:public-repo-contents(packages:installed-apps())
    let $allowed-apps :=
        for $app in $apps
            let $db-path := "/db/" || substring-after(data($app/url),"/exist/")

            order by upper-case($app/title/text())
            return
                 if(sm:has-access(xs:anyURI($db-path),"r-x")) then
                     $app
                 else ()

    return
        if($allowed-apps) then(
            $allowed-apps
        )
        else (
            <no-packages>You do not have sufficient priviledges to view packages</no-packages>
        )
};



(: todo: filter admin apps (must have group dba) from the list - these are displayed in the sidebar :)
declare function packages:get-local-packages(){
    let $log := util:log("info", "user: " || xmldb:get-current-user())

    let $apps :=  packages:installed-apps()
    let $allowed-apps :=
         for $app in $apps
             let $db-path := "/db/" || substring-after(data($app/url),"/exist/")

             let $log := util:log("info", "app url " || data($app/url))
             let $log := util:log("info", "db url " || $db-path)
             let $log := util:log("info", "app access " || sm:has-access(xs:anyURI($db-path),"r-x"))
             let $groups := sm:get-user-groups(xmldb:get-current-user())

             order by upper-case($app/title/text())
             return
                 if(sm:has-access(xs:anyURI($db-path),"r-x")) then
                     packages:display($config:REPO, $app, xs:integer(50))
                 else ()

    return
        if($allowed-apps) then(
            $allowed-apps
        )
        else (
            <no-packages>You do not have sufficient priviledges to view packages</no-packages>
        )
};


(:~
    returns a list of <existdb-package-descriptor> elements.

    The user needs to have at least 'VIEW-PACKAGE-PERMISSION' to see the list
    otherwise just an empty <no-packages> element will be returned.

    Further the user needs to have access rights for the given app collection.

    todo: is hiding of packages still needed?
    todo: refactor display function
:)
declare function packages:get-local-packages-orig(){
    let $access-level := packages:get-user-access-level()

(:
    let $log := util:log("info", "user: " || xmldb:get-current-user())
    let $log := util:log("info", "access-level: " || $access-level)
:)

    let $view-access-level := xs:integer($config:VIEW-PACKAGE-PERMISSION)
    let $default-apps-access-level := xs:integer($config:DEFAULT-APPS-PERMISSION)

    let $apps :=  packages:installed-apps()
    return

        if ( $access-level >= $view-access-level) then (
            for $app in $apps
            let $db-path := "/db/" || substring-after(data($app/url),"/exist/")

(:
            let $log := util:log("info", "app url " || data($app/url))
            let $log := util:log("info", "db url " || $db-path)
            let $log := util:log("info", "app access " || sm:has-access(xs:anyURI($db-path),"r-x"))
:)
            order by upper-case($app/title/text())
            return
                if(sm:has-access(xs:anyURI($db-path),"r-x")) then
                    packages:display($config:REPO, $app, $access-level)
                else ()
        ) else (
            <no-packages>You do not have sufficient priviledges to view packages</no-packages>
        )
};

declare function packages:get-remote-packages(){
    let $access-level := packages:get-user-access-level()
    let $log := console:log("access-level: " || $access-level)
    let $install-level := xs:integer($config:INSTALL-PACKAGE-PERMISSION)

    let $apps := packages:public-repo-contents(packages:installed-apps())
    return
        if ( $access-level >= $install-level) then
            for $app in $apps
            order by upper-case($app/title/text())
            return
                packages:display($config:REPO, $app, $access-level)
        else
           <no-packages>You do not have sufficient priviledges to access remote packages</no-packages>

};


declare %private function packages:get-user-access-level()  {
    let $groups := " " || string-join(xmldb:get-user-groups(xmldb:get-current-user()), " ") || " "
    let $f := $config:AUTH//group[contains($groups, data(./@name))]
    (:let $log := console:log("found: " || count($f)):)
    let $max := max($f/@access-level)
    return $max
};


(:
declare %private function packages:default-apps() {
        filter(function($app as element(app))
        {
            $app
        }, $packages:DEFAULTS/app)
};
:)

declare %private function packages:installed-apps() as element(app)* {

    let $path := functx:substring-before-last(request:get-uri(),'/packages')
    return
    packages:scan-repo(
        function ($app, $expathXML, $repoXML) {
            if ($repoXML//repo:type = "application") then
                let $icon :=
                    let $iconRes := repo:get-resource($app, "icon.png")
                    let $hasIcon := exists($iconRes)
                    return
                        $hasIcon
                let $app-url :=
                    if ($repoXML//repo:target) then
                        let $target :=
                            if (starts-with($repoXML//repo:target, "/")) then
                                replace($repoXML//repo:target, "^/.*/([^/]+)", "$1")
                            else
                                $repoXML//repo:target
                        return
                            replace(
                                request:get-context-path() || "/" || request:get-attribute("$exist:prefix") || "/" || $target || "/",
                                "/+", "/"
                            )
                    else
                        ()
                return
                    <app status="installed" path="{$expathXML//@name}">
                        <title>{$expathXML//expath:title/text()}</title>
                        <name>{$expathXML//@name/string()}</name>
                        <description>{$repoXML//repo:description/text()}</description>
                        {
                            for $author in $repoXML//repo:author
                            return
                                <author>{$author/text()}</author>
                        }
                        <abbrev>{$expathXML//@abbrev/string()}</abbrev>
                        <website>{$repoXML//repo:website/text()}</website>
                        <version>{$expathXML//expath:package/@version/string()}</version>
                        <license>{$repoXML//repo:license/text()}</license>
                        <icon>{if ($icon) then $path || '/modules/get-icon.xql?package=' || $app else $path || '/resources/images/package.png'}</icon>
                        <url>{$app-url}</url>
                        <type>{$repoXML//repo:type/text()}</type>
                    </app>
            else
                ()
        }
    )
};

declare %private function packages:display($repoURL as xs:anyURI?, $app as element(app), $access-level as xs:integer) {
    let $view-details-level := xs:integer($config:VIEW-DETAILS-PERMISSION)
    let $install-package-level := xs:integer($config:INSTALL-PACKAGE-PERMISSION)
    let $remove-package-level := xs:integer($config:REMOVE-PACKAGE-PERMISSION)
    let $hasDetailsLevel := if($access-level >= $view-details-level) then true() else false()

    let $icon :=
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "/public/" || $app/icon[1]
        else
            "resources/images/package.png"
    let $url :=
        if ($app/url) then
            $app/url
        else
            $app/@path
    return
        let $installed := $app/@installed/string()
        let $available := $app/@available/string()
        let $hasNewer :=
            if ($app/@available) then
                packages:is-newer($available, $installed)
            else
                false()
        let $status := if ($app/@status = 'installed') then 'installed' else 'notInstalled'

        return
            <existdb-package-descriptor tabindex="0" url="{$url}" data-name="{$app/name/string()}" status="{$status}" type="{$app/type}" installed="{$installed}" available="{$available}" abbrev="{$app/abbrev}" short-title="{$app/title/text()}">
                { if ($hasNewer) then attribute data-update { "true" } else () }

                {
                    if ($app/@status = "installed" and $app/type = 'application') then
                        <existdb-app-icon>
                            <a href="{$url}" target="_blank" title="click to open application" tabindex="-1"><img class="appIcon" src="{$icon}"/></a>
                        </existdb-app-icon>
                    else
                        <existdb-app-icon>
                            <img class="appIcon" src="{$icon}"/>
                        </existdb-app-icon>
                }
                <existdb-app-title>{$app/title/text()}</existdb-app-title>
                {
                    if ($hasDetailsLevel and $app/@available) then
                        if ($hasNewer) then (

                            <existdb-app-update installed="{$installed}" available="{$available}">
                                {
                                    if ($app/changelog/change[@version = $available]) then
                                        <a href="#" class="show-changes" data-version="{$available}">Changes</a>
                                    else
                                        ()
                                }
                            </existdb-app-update>,
                            <existdb-app-changes>
                                {$app/changelog/change[@version = $available]/node()}
                            </existdb-app-changes>
                        ) else
                            ()
                    else
                        <existdb-app-version>Version: {$app/version/text()}</existdb-app-version>
                }
                <existdb-app-actions class="appFunctions">
                    {

                        if ($app/@status = "installed" and $access-level >= $install-package-level) then
                            <existdb-package-remove-action url="{$app/@path}" abbrev="{$app/abbrev}" type="application"></existdb-package-remove-action>
                        else (),

                        if ($access-level >= $remove-package-level) then
                            <existdb-package-install-action url="{$app/name}" abbrev="{$app/abbrev}" type="application" version="{$app/version}"></existdb-package-install-action>
                        else ()
                    }
                </existdb-app-actions>

            </existdb-package-descriptor>
};

declare %private function packages:display-full($repoURL as xs:anyURI?, $app as element(app), $access-level as xs:integer) {
    let $view-details-level := xs:integer($config:VIEW-DETAILS-PERMISSION)
    let $install-package-level := xs:integer($config:INSTALL-PACKAGE-PERMISSION)
    let $remove-package-level := xs:integer($config:REMOVE-PACKAGE-PERMISSION)
    let $hasDetailsLevel := if($access-level >= $view-details-level) then true() else false()

    let $icon :=
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "/public/" || $app/icon[1]
        else
            "resources/images/package.png"
    let $url :=
        if ($app/url) then
            $app/url
        else
            $app/@path
    return
        let $installed := $app/@installed/string()
        let $available := $app/@available/string()
        let $hasNewer :=
            if ($app/@available) then
                packages:is-newer($available, $installed)
            else
                false()
        let $status := if ($app/@status = 'installed') then 'installed' else 'notInstalled'

        return
            <existdb-package-descriptor tabindex="0" data-name="{$app/name/string()}" status="{$status}" type="{$app/type}" installed="{$installed}" available="{$available}" abbrev="{$app/abbrev}" short-title="{$app/title/text()}">
                { if ($hasNewer) then attribute data-update { "true" } else () }

                {
                    if ($app/@status = "installed" and $app/type = 'application') then
                        <existdb-app-icon>
                            <a href="{$url}" target="_blank" title="click to open application" tabindex="-1"><img class="appIcon" src="{$icon}"/></a>
                        </existdb-app-icon>
                    else
                        <existdb-app-icon>
                            <img class="appIcon" src="{$icon}"/>
                        </existdb-app-icon>
                }
                <existdb-app-title>{$app/title/text()}</existdb-app-title>
                {
                    if ($hasDetailsLevel and $app/@available) then
                        if ($hasNewer) then (

                            <existdb-app-update installed="{$installed}" available="{$available}">
                                {
                                    if ($app/changelog/change[@version = $available]) then
                                        <a href="#" class="show-changes" data-version="{$available}">Changes</a>
                                    else
                                        ()
                                }
                            </existdb-app-update>,
                            <existdb-app-changes>
                                {$app/changelog/change[@version = $available]/node()}
                            </existdb-app-changes>
                        ) else
                            ()
                    else
                        <existdb-app-version>Version: {$app/version/text()}</existdb-app-version>
                }
                <existdb-app-details>
                {
                    if ($hasDetailsLevel and $app/@size) then
                        <existdb-app-size>{$app/@size idiv 1024}k</existdb-app-size>
                    else
                        ()
                }
                {
                    if ($hasDetailsLevel and $app/requires) then
                        <existdb-app-requires class="requires">Requires eXist-db {packages:required-version($app/requires)}</existdb-app-requires>
                    else
                        ()
                }
                {
                    if ($hasDetailsLevel and $app/note) then
                        <existdb-app-note class="installation-note" style="display: none">{$app/note/node()}</existdb-app-note>
                    else
                        ()
                }
                {
                    if($hasDetailsLevel) then (
                        <existdb-app-shortname>&#160;</existdb-app-shortname>,
                        <existdb-app-namespace>{$app/name/string()}</existdb-app-namespace>,
                        <existdb-app-description>{$app/description/text()}</existdb-app-description>
                    )
                    else ()
                }
                {
                    if ($hasDetailsLevel) then
                        <existdb-app-authors>
                        {
                            for $author in $app/author
                            return
                            <existdb-app-author>{$author/text()}</existdb-app-author>
                        }
                        </existdb-app-authors>
                    else ()
                }
                {
                    if($hasDetailsLevel) then
                        <existdb-app-license>{$app/license/text()}</existdb-app-license>
                    else ()
                }
                {
                    if ($hasDetailsLevel and $app/website != "") then
                        <existdb-app-website><a href="{$app/website}">{$app/website/text()}</a></existdb-app-website>
                    else
                        ()
                }
                {
                    if ($hasDetailsLevel and $app/other/version) then
                        <existdb-app-versions>
                            {
                                for $version in $app/other/version
                                return
                                    <existdb-app-version version="{$version/@version/string()}">
                                        <div class="version">{$version/@version/string()}</div>
                                        <form action="">
                                            <input type="hidden" name="package-url" value="{$app/name}"/>
                                            <input type="hidden" name="abbrev" value="{$app/abbrev}"/>
                                            <input type="hidden" name="version" value="{$version/@version}"/>
                                            <input type="hidden" name="action" value="install"/>
                                            <input type="hidden" name="type" value="application"/>
                                            <button class="installApp" title="Install">Install</button>
                                        </form>
                                    </existdb-app-version>
                            }
                        </existdb-app-versions>
                    else
                        ()
                }
                </existdb-app-details>
                <existdb-app-actions class="appFunctions">
                    {

                        if ($app/@status = "installed" and $access-level >= $install-package-level) then
                            <existdb-package-remove-action url="{$app/@path}" abbrev="{$app/abbrev}" type="application"></existdb-package-remove-action>
                        else (),

                        if ($access-level >= $remove-package-level) then
                            <existdb-package-install-action url="{$app/name}" abbrev="{$app/abbrev}" type="application" version="{$app/version}"></existdb-package-install-action>
                        else ()
                    }
                </existdb-app-actions>

            </existdb-package-descriptor>
};


declare %private function packages:scan-repo($callback as function(xs:string, element(), element()?) as item()*) {
    for $app in repo:list()
    let $expathMeta := packages:get-package-meta($app, "expath-pkg.xml")
    let $repoMeta := packages:get-package-meta($app, "repo.xml")
    return
        $callback($app, $expathMeta, $repoMeta)
};

declare %private function packages:get-package-meta($app as xs:string, $name as xs:string) {
    let $data :=
        let $meta := repo:get-resource($app, $name)
        return
            if (exists($meta)) then util:binary-to-string($meta) else ()
    return
        if (exists($data)) then
            try {
                util:parse($data)
            } catch * {
                <meta xmlns="http://exist-db.org/xquery/repo">
                    <description>Invalid repo descriptor for app {$app}</description>
                </meta>
            }
        else
            ()
};

declare %private function packages:public-repo-contents($installed as element(app)*) {
    try {
        let $url := $config:REPO || "/public/apps.xml?version=" || packages:get-version() ||
            "&amp;source=" || util:system-property("product-source")
        (: EXPath client module does not work properly. No idea why. :)
(:        let $request :=:)
(:            <http:request method="get" href="{$url}" timeout="10">:)
(:                <http:header name="Cache-Control" value="no-cache"/>:)
(:            </http:request>:)
(:        let $data := http:send-request($request):)
        let $data := httpclient:get($url, false(), ())
        let $status := xs:int($data/@statusCode)
        return
            if ($status != 200) then
                response:set-status-code($status)
            else
                map(function($app as element(app)) {
                    (: Ignore apps which are already installed :)
                    if ($app/abbrev = $installed/abbrev) then
                        if (packages:is-newer($app/version/string(), $installed[abbrev = $app/abbrev]/version)) then
                            element { node-name($app) } {
                                attribute available { $app/version/string() },
                                attribute installed { $installed[abbrev = $app/abbrev]/version/string() },
                                $app/@*,
                                $app/*
                            }
                        else
                            ()
                    else
                        $app
                }, $data/httpclient:body//app)
    } catch * {
        util:log("WARN", "Error while retrieving app packages: " || $err:description)
    }
};

declare %private function packages:get-version() {
    (util:system-property("product-semver"), util:system-property("product-version"))[1]
};

declare %private function packages:required-version($required as element(requires)) {
    string-join((
        if ($required/@semver-min) then
            " > " || $required/@semver-min
        else
            (),
        if ($required/@semver-max) then
            " < " || $required/@semver-max
        else
            (),
        if ($required/@version) then
            " " || $required/@version
        else
            ()
    ))
};

declare %private function packages:is-newer($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        packages:compare-versions($verInstalled, $verAvailable)
};

declare %private function packages:compare-versions($installed as xs:string*, $available as xs:string*) as xs:boolean {
    if (empty($installed)) then
        exists($available)
    else if (empty($available)) then
        false()
    else if (head($available) = head($installed)) then
        packages:compare-versions(tail($installed), tail($available))
    else
        number(head($available)) > number(head($installed))
};