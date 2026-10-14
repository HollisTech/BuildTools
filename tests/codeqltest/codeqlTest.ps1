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

function assertEndsWith {
    # for assertions about which file was chosen: the tail of a path is stable,
    # its root is not (8.3 short form, drive mapping, length)
    param($suffix, $actual, $what)
    $a = "$actual"
    if (!$a.EndsWith("$suffix", [StringComparison]::OrdinalIgnoreCase)) {
        Write-Error "$what`: expected a path ending '$suffix', got '$a'"
        $script:status = $false
    } else {
        log "$what`: $a"
    }
}

function assertPathEqual {
    # Paths need canonicalizing before comparison: the same file can be named in
    # 8.3 short form, which is what $env:TEMP is on a CI runner
    # (C:\Users\RUNNER~1\AppData\Local\Temp), while a resolved path comes back
    # long. Comparing the strings would then never match.
    param($expected, $actual, $what)
    $e = "$expected"
    $a = "$actual"
    if ($e -and (Test-Path $e)) { $e = (Get-Item $e).FullName }
    if ($a -and (Test-Path $a)) { $a = (Get-Item $a).FullName }
    if ($e -ne $a) {
        Write-Error "$what`: expected '$e', got '$a'"
        $script:status = $false
    } else {
        log "$what`: $a"
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

    log "codeql.json tooling description test"
    $tooling = readCodeQlJson -jsonFile "$root\codeql.test.json"
    assertEqual (Resolve-Path "$root\codeql.test.json").Path $tooling.file "file read"
    assertEqual "2.20.1" $tooling.version "cli version"
    assertEqual "D:\codeql-home" $tooling.home "cli home"
    assertEqual 2 $tooling.packs.Count "pack count"
    assertEqual "microsoft/windows-drivers@1.8.0" $tooling.packs[0] "driver pack"
    assertEqual "microsoft/cpp-queries@0.0.4" $tooling.packs[1] "cpp pack"
    assertEqual "D:\wdk\dvl.exe" $tooling.dvlExe "dvl path"
    # a json without a "cli" section, or without the section's keys, must not throw
    $partial = "$env:TEMP\codeql-partial-test.json"
    '{ "packs" : [ "microsoft/windows-drivers@1.10.0" ] }' | Set-Content -Path $partial -Encoding utf8
    try {
        $t2 = readCodeQlJson -jsonFile $partial
        assertEqual 1 $t2.packs.Count "pack count, minimal json"
        assertEqual "" "$($t2.version)" "no cli section leaves the version unset"
        assertEqual "" "$($t2.dvlExe)" "no dvl section leaves the path unset"
    }
    finally {
        Remove-Item $partial -Force
    }
    # with nothing named, the description that ships with the tools is the fallback
    $shipped = readCodeQlJson
    assertEqual 2 $shipped.packs.Count "shipped codeql.json pack count"
    assertEqual "microsoft/cpp-queries@0.0.5" $shipped.packs[1] "shipped codeql.json names both packs"
    # the suite has to come from the driver pack, whatever the list order
    assertEqual "microsoft/windows-drivers@1.8.0" (getCodeQlDriverPack -packs $tooling.packs) "driver pack by role"
    assertEqual "microsoft/windows-drivers@1.8.0" `
        (getCodeQlDriverPack -packs @("microsoft/cpp-queries@0.0.4", "microsoft/windows-drivers@1.8.0")) "driver pack out of order"

    log "dvl.exe search test"
    # a project tree with WDK nuget packages, the layout a nuget build has:
    # <root>\packages\Microsoft.Windows.WDK.<arch>.<version>\c\tools\dvl\dvl.exe
    # the root's canonical form, not "$env:TEMP\...": TEMP is an 8.3 short path
    # on a CI runner, and the search returns long form paths
    $fakeRoot = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "hts-codeql-dvltest") -Force).FullName
    try {
        foreach ($pkg in @("Microsoft.Windows.WDK.x64.10.0.26100.3323",
                "Microsoft.Windows.WDK.x64.10.0.28000.2526",
                "Microsoft.Windows.WDK.ARM64.10.0.28000.2526")) {
            $dir = "$fakeRoot\packages\$pkg\c\tools\dvl"
            $null = mkdir $dir
            Set-Content -Path "$dir\dvl.exe" -Value "fake" -Encoding ascii
        }
        # a package that is present but has no dvl.exe must not win on version
        $null = mkdir "$fakeRoot\packages\Microsoft.Windows.WDK.x64.10.0.30000.1\c"
        # the architecture being built picks the package, and the newest of that
        # architecture wins
        # the assertion is on which package was chosen, ie the tail of the path,
        # not on its root: a root can be named in 8.3 short form (a CI runner's
        # $env:TEMP is C:\Users\RUNNER~1\...) and then an exact string comparison
        # against the long form never matches, which is how this test first
        # failed on GitHub.
        assertEndsWith "packages\Microsoft.Windows.WDK.x64.10.0.28000.2526\c\tools\dvl\dvl.exe" `
            (getDvlExe -searchRoot $fakeRoot -architecture x64) "x64 package, newest with a dvl.exe"
        assertEndsWith "packages\Microsoft.Windows.WDK.ARM64.10.0.28000.2526\c\tools\dvl\dvl.exe" `
            (getDvlExe -searchRoot $fakeRoot -architecture arm64) "arm64 package"
        # an explicitly configured dvl.exe wins over the search
        $configured = "$fakeRoot\packages\Microsoft.Windows.WDK.x64.10.0.26100.3323\c\tools\dvl\dvl.exe"
        assertPathEqual $configured `
            (getDvlExe -dvlExe $configured -searchRoot $fakeRoot -architecture arm64) "configured path wins"
        # no packages: the installed WDK is the fallback, and a CI runner has
        # neither, which is the -dvl failure path
        $emptyRoot = "$fakeRoot\no-packages"
        $null = mkdir $emptyRoot
        $fallback = getDvlExe -searchRoot $emptyRoot
        $installedWdk = "${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe"
        if (Test-Path $installedWdk -PathType Leaf) {
            assertEqual (Convert-Path $installedWdk) $fallback "installed WDK is the fallback"
        }
        else {
            assertEqual "" "$fallback" "no dvl.exe anywhere returns nothing"
        }
        # short and long form of one file must compare equal: this is the
        # condition the CI runner hit, where $env:TEMP is C:\Users\RUNNER~1\...
        # and a resolved path comes back C:\Users\runneradmin\...
        $shortWdk = "C:\PROGRA~2\Windows Kits\10\Tools\dvl\dvl.exe"
        $longWdk = "${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe"
        if ((Test-Path $shortWdk -PathType Leaf) -and (Test-Path $longWdk -PathType Leaf)) {
            assertPathEqual $longWdk $shortWdk "short and long form of one path compare equal"
            # and it is only the canonical form that makes them equal
            if ("$shortWdk" -ne "$longWdk") {
                log "short and long form differ as strings, as expected"
            }
            else {
                Write-Error "this machine has no 8.3 short names (C:\PROGRA~2 not distinct), so the short/long case is not covered here"
                $script:status = $false
            }
        }
        else {
            # informational, not a failure: a machine (or runner image) without
            # 8.3 names cannot exercise this, and the package assertions above
            # are already immune to the path's root form
            log "no short-form path available here (C:\PROGRA~2 absent), short/long comparison not exercised"
        }
    }
    finally {
        if (Test-Path $fakeRoot) { Remove-Item -Recurse -Force $fakeRoot }
    }

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
