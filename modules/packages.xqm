xquery version "3.0";

module namespace packages="http://exist-db.org/apps/existdb-packages";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace functx = "http://www.functx.com";

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace http="http://expath.org/ns/http-client";


declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $packages:configuration := doc($config:app-root || "/configuration.xml");

declare variable $packages:DEFAULTS := doc($config:app-root || "/defaults.xml")/apps;
declare variable $packages:ADMINAPPS := ["dashboard","backup"];
declare variable $packages:HIDE := ("dashboard");

(:~
 : fetch the complete list of locally installed applications and libaries
 :)
declare function packages:get-local-packages(){
    packages:get-local-applications() | packages:get-local-libraries()
};


(:~
 : fetch the list of locally installed applications
 :)
declare function packages:get-local-applications(){
    packages:get-local("application")
};

(:~
 : fetch the list of locally installed libraries
 :)
declare function packages:get-local-libraries(){
    packages:get-local("library")
};

declare function packages:get-remote-packages(){

    let $apps := packages:public-repo-contents(packages:installed-apps("application"))
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

declare function packages:get-repo-locations(){
    data($packages:configuration//repository)
};

(: should be private but there seems to be a bug :)
declare function packages:get-local($type as xs:string){
    let $log := util:log("info", "user: " || xmldb:get-current-user())

    let $apps :=  packages:installed-apps($type)
    let $allowed-apps :=
         for $app in $apps
         (: todo: this path matching is hardly good enough i guess - how to do better? :)
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


(: should be private but there seems to be a bug :)
declare function packages:installed-apps($type as xs:string) as element(app)* {

    let $path := functx:substring-before-last(request:get-uri(),'/existdb-packages')
    return
    packages:scan-repo(
        function ($app, $expathXML, $repoXML) {
            if ($repoXML//repo:type = $type) then
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

                let $src :=
                  if ($icon) then $path || '/existdb-packageservice/package/icon?package=' || $app
                  else $path || '/existdb-packageservice/resources/images/package.png'

                return
                    <repo-app status="installed" url="{$expathXML//@name}" path="{$app-url}">
                        {
                            if (string-length($expathXML//expath:title/text()) != 0) then
                                <repo-title>{$expathXML//expath:title/text()}</repo-title>
                            else
                                <repo-title>unknown title</repo-title>

                        }
                        {
                            if(string-length($expathXML//@name/string()) != 0) then
                                <repo-name>{$expathXML//@name/string()}</repo-name>
                            else
                                <repo-name>unknown name</repo-name>
                        }
                        {
                            if(string-length($repoXML//repo:description/text()) != 0) then
                                <repo-description>{$repoXML//repo:description/text()}</repo-description>
                            else ()
                        }
                        {
                            for $author in $repoXML//repo:author
                            let $author := if (string-length($author/text()) != 0) then
                                <repo-author>{$author/text()}</repo-author>
                            else ()
                            return
                                $author
                        }
                        {
                            if(string-length($expathXML//@abbrev/string()) != 0) then
                                <repo-abbrev>{$expathXML//@abbrev/string()}</repo-abbrev>
                            else ()
                        }
                        {
                        if(string-length($repoXML//repo:website/text()) != 0) then
                            <repo-website>{$repoXML//repo:website/text()}</repo-website>
                        else ()
                        }
                        {
                            if(string-length($expathXML//expath:package/@version/string()) != 0) then
                                <repo-version>{$expathXML//expath:package/@version/string()}</repo-version>
                            else
                                <repo-version>unknown</repo-version>
                        }
                        {
                            if(string-length($repoXML//repo:license/text()) != 0) then
                                <repo-license>{$repoXML//repo:license/text()}</repo-license>
                            else ()
                        }
                        <repo-icon src="{$src}">&#160;</repo-icon>
                        {
                            if (string-length($app-url) != 0) then
                            <repo-url>{$app-url}</repo-url>
                            else ()
                        }

                        <repo-type>{$repoXML//repo:type/text()}</repo-type>
                    </repo-app>
            else
                ()
        }
    )
};



(: should be private but there seems to be a bug :)
declare function packages:scan-repo($callback as function(xs:string, element(), element()?) as item()*) {
    for $app in repo:list()
    let $expathMeta := packages:get-package-meta($app, "expath-pkg.xml")
    let $repoMeta := packages:get-package-meta($app, "repo.xml")
    return
        $callback($app, $expathMeta, $repoMeta)
};

(: should be private but there seems to be a bug :)
declare function packages:get-package-meta($app as xs:string, $name as xs:string) {
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

(: should be private but there seems to be a bug :)
declare function packages:public-repo-contents($installed as element(app)*) {
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

(: should be private but there seems to be a bug :)
declare function packages:get-version() {
    (util:system-property("product-semver"), util:system-property("product-version"))[1]
};

(: should be private but there seems to be a bug :)
declare function packages:required-version($required as element(requires)) {
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

(: should be private but there seems to be a bug :)
declare function packages:is-newer($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        packages:compare-versions($verInstalled, $verAvailable)
};

(: should be private but there seems to be a bug :)
declare function packages:compare-versions($installed as xs:string*, $available as xs:string*) as xs:boolean {
    if (empty($installed)) then
        exists($available)
    else if (empty($available)) then
        false()
    else if (head($available) = head($installed)) then
        packages:compare-versions(tail($installed), tail($available))
    else
        number(head($available)) > number(head($installed))
};