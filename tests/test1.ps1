
$root = $PSScriptRoot
$buildModule = "$root\..\buildFuncs.psm1"
Import-Module -Name $buildModule -force
try {
    log "build number test"
    $num = buildNumber -jsonFile "$root\protected-test1.json" -allowModified
    log "buildnumber returned $num"
    if ($num) {
        log "regex test passed"
    } else {
        write-error "regex test failed"
    }
    $num = buildNumber -jsonFile "$root\protected-test2.json" -allowModified
    log "buildnumber returned $num"
    if ($num -eq 0) {
        log "explicit match test passed"
    } else {
        write-error "explicit test failed"
    }
    log "build number test passed"

    log "JSON build test"
    # clean build artifacts
    $buildDirs = "bin","inc","logs"
    foreach ($dir in $buildDirs) {
        $p = "./buildtest/$($dir)"
        if (test-path $p) {
            Remove-Item -recurse -path $p -force
        }
    }
    ../build.ps1 -jsonfile ./buildtest/build.json
    if ($LASTEXITCODE -ne 0) {
        write-error "Build exit code $LASTEXITCODE "
    }
    foreach ($dir in $buildDirs) {
        $p = "./buildtest/$($dir)"
        if (!(test-path $p)) {
            write-error "build expected artifact directory $p"
        }
    }    
    Import-Module -Name $buildModule -force
    log "JSON build test passed"
}
finally {
    if (Get-Module -Name buildFuncs) {
        Remove-Module -name buildFuncs
    }
}
