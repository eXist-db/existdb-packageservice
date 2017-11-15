xquery version "3.0";

(:~
: User: joern
: Date: 07.04.17
: Time: 11:45
: To change this template use File | Settings | File Templates.
:)

(:
import module namespace packages="http://exist-db.org/apps/existdb-packages" at "packages.xqm";
import module namespace ce="http://exist-db.org/apps/custom-elements" at "custom-element.xqm";

<repo-packages>
    {
        let $pkgs := packages:get-remote-packages()
        let $prefix := "repo-"
        let $ignores := ('ul', 'li')
        return
            for $pkg in $pkgs
            return
                ce:convert-to-custom-element($pkg, $prefix, $ignores)
    }
</repo-packages>
:)

import module namespace packages="http://exist-db.org/apps/existdb-packages" at "packages.xqm";
import module namespace ce="http://exist-db.org/apps/custom-elements" at "custom-element.xqm";
import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

<repo-packages>
    {
        let $pkgs := packages:get-remote()
        return
            for $pkg in $pkgs
(:            let $icon := if (exists($pkg/icon)) then data($pkg/icon) else "default.png":)
            let $path := '/exist/apps/existdb-packageservice/'
            let $icon :=    if (exists($pkg/icon)) then
                                $config:DEFAULT-REPO || "/public/" || data($pkg/icon)
                            else
                                $path || "resources/images/package.png"
            order by data($pkg/repo-title)
            return
                <repo-app url="{data($pkg/name)}"
                          abbrev="{data($pkg/abbrev)}"
                          type="{data($pkg/type)}"
                          version="{data($pkg/version)}"
                          status="available">
                    <repo-icon src="{$icon}">&#160;</repo-icon>
                    <repo-type>{data($pkg/type)}</repo-type>
                    <repo-title>{data($pkg/title)}</repo-title>
                    <repo-version>{data($pkg/version)}</repo-version>
                    <repo-name>{data($pkg/name)}</repo-name>
                    <repo-description>{data($pkg/description)}</repo-description>

                    <repo-authors>
                    {
                    for $author in $pkg//author
                    return
                        <repo-author>{data($author)}</repo-author>
                    }
                    </repo-authors>

                    <repo-abbrev>{data($pkg/abbrev)}</repo-abbrev>

                    {
                    if (exists($pkg/website)) then
                        <repo-website>{data($pkg/website)}</repo-website>
                    else ()
                    }

                    <repo-license>{data($pkg/license)}</repo-license>

                    <repo-version version="{data($pkg/version)}"> </repo-version>

                    {
                    if(exists($pkg/requires)) then
                        <repo-requires processor="{data($pkg/requires/@processor)}" semver-min="{data($pkg/requires/@semver-min)}"> </repo-requires>
                    else ()
                    }
                    {
                    if(exists($pkg/changelog)) then
                        <repo-changelog>
                            {
                            for $change in $pkg/changelog//change
                            return
                                <repo-change version="{data($change/@version)}">{$change/*}</repo-change>
                            }
                        </repo-changelog>
                    else ()
                    }
                    {
                    if(exists($pkg/other)) then
                        <repo-other>
                            {
                            for $version in $pkg/other/version
                            return
                                <repo-version version="{data($version/@version)}" path="{data($version/@path)}">
                                    {
                                    if (exists($version/requires)) then
                                        <repo-requires processor="{data($version/requires/@processor)}"></repo-requires>
                                    else ()
                                    }
                                </repo-version>
                            }
                        </repo-other>
                    else ()
                    }
                    {
                    if(exists($pkg/note)) then
                        <repo-note>{data($pkg/note)}</repo-note>
                    else ()
                    }
                </repo-app>
    }
</repo-packages>