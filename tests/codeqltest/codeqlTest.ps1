<#

.SYNOPSIS
    Test the CodeQL support functions that don't need the CodeQL CLI.

.DESCRIPTION
    getSarifResults and getCodeQlSuiteSpec are pure functions over a SARIF file
    and over a pack/suite name, so they can be tested without a CodeQL install.
    Tests the result summary by severity, where a result's severity comes from
    its own level when present and from the rule's defaultConfiguration when it
    isn't, and the suite name to suite specifier resolution.

.NOTES
    Run from anywhere; the test locates the module relative to itself.
#>

$root = $PSScriptRoot
$buildModule = "$root\..\..\buildFuncs.psm1"
Import-Module -Name $buildModule -Force
$status = $true

function assertEqual {
    param($expected, $actual, $what)
    if ("$expected" -ne "$actual") {
        Write-Error "$what`: expected '$expected', got '$actual'"
        $script:status = $false
    } else {
        log "$what`: $actual"
    }
}

try {
    log "sarif result summary test"
    $results = getSarifResults -sarifFile "$root\sample.sarif"
    assertEqual 4 $results.total "total"
    assertEqual 1 $results.error "error"
    assertEqual 2 $results.warning "warning"
    assertEqual 1 $results.note "note"
    assertEqual 3 $results.rules.Count "distinct rules"
    assertEqual "cpp/test/warning-rule (2)" $results.rules[0] "top rule"

    log "sarif result summary test on a missing file"
    $missing = getSarifResults -sarifFile "$root\no-such-file.sarif"
    assertEqual 0 $missing.total "total of a missing file"
    assertEqual 0 $missing.rules.Count "rules of a missing file"

    log "codeql suite spec test"
    $pack = "microsoft/windows-drivers@1.10.0"
    assertEqual "microsoft/windows-drivers:windows-driver-suites/recommended.qls" `
        (getCodeQlSuiteSpec -pack $pack) "default suite"
    assertEqual "microsoft/windows-drivers:windows-driver-suites/mustfix.qls" `
        (getCodeQlSuiteSpec -pack $pack -suite mustfix) "mustfix suite"
    assertEqual "microsoft/windows-drivers:windows-driver-suites/mustrun.qls" `
        (getCodeQlSuiteSpec -pack $pack -suite MUSTrun) "suite name is case insensitive"
    $path = (Resolve-Path "$root\sample.sarif").Path -replace '\.sarif$', '.qls'
    Copy-Item "$root\sample.sarif" $path
    try {
        assertEqual (Resolve-Path $path).Path (getCodeQlSuiteSpec -pack $pack -suite $path) "suite path is passed through"
    }
    finally {
        Remove-Item $path -Force
    }

    log "codeql artifact paths test"
    # the names build.ps1 hands to doBuild, so the build loop itself assembles
    # nothing: one database, one sarif, one dvl and one console log per
    # configuration and platform.
    $codeQlState = @{
        driverName = "HtsVsp"
        dbRoot     = "C:\db"
        output     = "C:\out"
        logDir     = "C:\logs"
    }
    $paths = getCodeQlPaths -codeQl $codeQlState -config Release -platform x64
    assertEqual "HtsVsp_Release_x64" $paths.name "artifact prefix"
    assertEqual "C:\db\HtsVsp_Release_x64_db" $paths.database "database path"
    assertEqual "C:\out\HtsVsp_Release_x64.sarif" $paths.sarif "sarif path"
    assertEqual "C:\out\HtsVsp_Release_x64.DVL.XML" $paths.dvl "dvl path"
    assertEqual "C:\logs\CodeQL_Release_x64.log" $paths.log "console log path"
    $paths = getCodeQlPaths -codeQl $codeQlState -config Debug -platform ARM64
    assertEqual "HtsVsp_Debug_ARM64" $paths.name "artifact prefix, other configuration"
    assertEqual "C:\logs\CodeQL_Debug_ARM64.log" $paths.log "console log path, other configuration"

    log "publishCodeQlAnalysis return contract test"
    # build.ps1 captures this function's output to get the finding count, so the
    # report has to go to the host: if it went to the output stream the count
    # would be buried in an array of report lines and the caller's
    # '$findings -lt 0' would silently be comparing an array.
    $paths = getCodeQlPaths -codeQl $codeQlState -config Release -platform x64
    $paths.sarif = "$root\sample.sarif"
    $pipeline = @(publishCodeQlAnalysis -codeQl $codeQlState -paths $paths -config Release -platform x64)
    assertEqual 1 $pipeline.Count "output stream carries only the finding count"
    assertEqual 4 $pipeline[0] "finding count returned"

    if ($status) {
        log "codeql tests passed"
        exit 0
    } else {
        log "codeql tests failed"
        exit 1
    }
}
finally {
    if (Get-Module -Name buildFuncs) {
        Remove-Module -name buildFuncs
    }
}
