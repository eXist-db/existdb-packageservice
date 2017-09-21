xquery version "3.0";

declare namespace json="http://www.json.org";
declare namespace control="http://exist-db.org/apps/dashboard/controller";

import module namespace login-helper="http://exist-db.org/apps/dashboard/login-helper" at "modules/login-helper.xql";

import module namespace packages="http://exist-db.org/apps/dashboard/packages/rest" at "modules/packages.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare variable $login := login-helper:get-login-method();

request:set-attribute("betterform.filter.ignoreResponseBody", "true"),
if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
else if ($exist:path = "/") then
(: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

(:
else if (ends-with($exist:path, ".html")) then
        try {
            let $loggedIn := $login("org.exist.login",  (), true())
            let $user := request:get-attribute("org.exist.login.user")
            return
                if ($user and sm:is-dba($user)) then (
                    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                        {$user}
                        <cache-control cache="no"/>
                    </dispatch>
                )
                else (
                    response:set-status-code(401),
                    <response>
                        <user>{$user}</user>
                        <fail>Wrong user or password</fail>
                    </response>
                )
        } catch * {
            response:set-status-code(500),
            <response>
                <fail>{$err:description}</fail>
            </response>
        }
:)

else if(starts-with($exist:path,"/packages/local")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../modules/local-packages.xql"></forward>
    </dispatch>
else if(starts-with($exist:path,"/packages/remote")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="../modules/remote-packages.xql"></forward>
    </dispatch>
else
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
