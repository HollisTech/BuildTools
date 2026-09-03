
$root = $PSScriptRoot
$buildModule = "$root\..\buildFuncs.psm1"
Import-Module -Name $buildModule -force
$status = $true
Push-Location $root
try {
    log "build number test"
    $num = buildNumber -jsonFile "$root\protected-test1.json" -allowModified
    log "buildnumber returned $num"
    if ($num) {
        log "regex test passed"
    } else {
        write-error "regex test failed"
        $status = $false
    }
    $num = buildNumber -jsonFile "$root\protected-test2.json" -allowModified
    log "buildnumber returned $num"
    if ($num -eq 0) {
        log "explicit match test passed"
    } else {
        write-error "explicit test failed"
        $status = $false
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
    ../build.ps1 -jsonfile "$root/buildtest/build.json"
    if ($LASTEXITCODE -ne 0) {
        write-error "Build exit code $LASTEXITCODE "
        $status = $false
    }
    foreach ($dir in $buildDirs) {
        $p = "./buildtest/$($dir)"
        if (!(test-path $p)) {
            write-error "build expected artifact directory $p"
            $status = $false
        }
    }
    # build.ps1 unloads this module!
    Import-Module -Name $buildModule -force
    if ($status) {
        log "JSON build test passed"
        exit 0
    } else {
        log "JSON build test failed"
        exit 1
    }
}
finally {
    if (Get-Module -Name buildFuncs) {
        Remove-Module -name buildFuncs
    }
    Pop-Location
}
