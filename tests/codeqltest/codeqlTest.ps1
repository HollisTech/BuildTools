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
