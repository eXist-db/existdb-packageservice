xquery version "3.0";

module namespace packages="http://exist-db.org/apps/dashboard/packages/rest";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace http="http://expath.org/ns/http-client";

declare variable $packages:DEFAULTS := doc($config:app-root || "/defaults.xml")/apps;

declare variable $packages:HIDE := ("dashboard");

declare
    %rest:GET
    %rest:path("/packages")
    %rest:query-param("format", "{$format}")
    %rest:query-param("plugins", "{$plugins}")
    %rest:query-param("type", "{$type}")
function packages:get($type as xs:string?, $format as xs:string?, $plugins as xs:string?) {
    let $apps := packages:default-apps($plugins) | packages:installed-apps($format)
    let $apps :=
        if ($type = "local") then $apps else packages:public-repo-contents($apps)
    let $apps := if ($format = "manager") then $apps except $apps[@removable="no"] else $apps
    for $app in $apps
    order by upper-case($app/title/text())
    return
       packages:display($config:REPO, $app, $format)
};

declare %private function packages:default-apps($plugins as xs:string?) {
    if ($plugins) then
        $packages:DEFAULTS/app
    else
        filter(function($app as element(app)) {
            if ($app/type = 'plugin') then
                ()
            else
                $app
        }, $packages:DEFAULTS/app)
};

declare %private function packages:installed-apps($format as xs:string?) as element(app)* {
    packages:scan-repo(
        function ($app, $expathXML, $repoXML) {
            if ($format = "manager" or $repoXML//repo:type = "application") then
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
                        <icon>{if ($icon) then 'modules/get-icon.xql?package=' || $app else 'resources/images/package.png'}</icon>
                        <url>{$app-url}</url>
                        <type>{$repoXML//repo:type/text()}</type>
                    </app>
            else
                ()
        }
    )
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

declare %private function packages:display($repoURL as xs:anyURI?, $app as element(app), $format as xs:string?) {
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
        switch ($format)
            case "manager" return
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
                                <a href="{$url}" target="_blank" title="click to open application"><img class="appIcon" src="{$icon}"/></a>
                            </existdb-app-icon>
                        else
                            <existdb-app-icon>
                                <img class="appIcon" src="{$icon}"/>
                            </existdb-app-icon>
                        }
                        <existdb-app-title>{$app/title/text()}</existdb-app-title>
                        {
                            if ($app/@available) then
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
                                    { $app/changelog/change[@version = $available]/node() }
                                    </existdb-app-changes>
                                ) else
                                    ()
                            else
                                <existdb-app-version>Version: {$app/version/text()}</existdb-app-version>
                        }
                        {
                            if ($app/@size) then
                                <existdb-app-size>{ $app/@size idiv 1024 }k</existdb-app-size>
                            else
                                ()
                        }
                        {
                            if ($app/requires) then
                                <existdb-app-requires class="requires">Requires eXist-db {packages:required-version($app/requires)}</existdb-app-requires>
                            else
                                ()
                        }
                        {
                            if ($app/note) then
                                (: Installation notes are shown if user clicks on install :)
                                <existdb-app-note class="installation-note" style="display: none">{ $app/note/node() }</existdb-app-note>
                            else
                                ()
                        }
                        <existdb-app-shortname>{ $app/abbrev/text() }</existdb-app-shortname>
                        <existdb-app-namespace>{ $app/name/string() }</existdb-app-namespace>
                        <existdb-app-description>{ $app/description/text() }</existdb-app-description>
                        {
                        for $author in $app/author
                            return
                            <existdb-app-author>{$author/text()}</existdb-app-author>
                        }
                        <existdb-app-license>{ $app/license/text() }</existdb-app-license>
                        {
                            if ($app/website != "") then
                                <existdb-app-website><a href="{$app/website}">{ $app/website/text() }</a></existdb-app-website>
                            else
                                ()
                        }
                        {
                            if ($app/other/version) then
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

                            else
                                ()
                        }
                        <existdb-app-actions class="appFunctions">
                        {

                            if ($app/@status = "installed") then
                                <existdb-package-remove-action url="{$app/@path}" abbrev="{$app/abbrev}" type="application"></existdb-package-remove-action>
                            else
                                <existdb-package-install-action url="{$app/name}" abbrev="{$app/abbrev}" type="application" version="{$app/version}"></existdb-package-install-action>
                        }
                        </existdb-app-actions>

                    </existdb-package-descriptor>
            default return
                if ($app/abbrev = $packages:HIDE) then
                    ()
                else
                    <li class="package dojoDndItem {$app/type}" style="opacity: 0;">
                        <button id="{util:uuid()}" title="{$app/title/text()}" data-exist-appUrl="{$app/url}"
                            data-exist-requireLogin="{$app/@role = 'dba'}">
                            {
                                if ($app/url) then
                                    <a href="{$app/url}" target="_blank"><img class="appIcon" src="{$icon}"/></a>
                                else
                                    <img class="appIcon" src="{$icon}"/>
                            }
                            <h3>{$app/title/text()}</h3>
                        </button>
                    </li>
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