xquery version "3.1";

let $repo := request:get-parameter("package", ())
return
    try {
        response:stream-binary(repo:get-resource($repo, "icon.svg"), "image/svg+xml", ())
    }
    catch * {
        response:stream-binary(repo:get-resource($repo, "icon.png"), "image/png", ())
    }
