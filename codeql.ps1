<#

.SYNOPSIS
    Install, and report on, the CodeQL tooling used for Windows driver analysis.

.DESCRIPTION
    CodeQL analysis of Windows driver code needs three pieces of tooling, none of
    which is part of the Visual Studio or WDK install:

      1. the CodeQL CLI, unpacked into a directory such as C:\codeql-home,
      2. the query packs: the Microsoft driver pack, and the C/C++ pack its
         suites reference. Both are needed - see the suite check below - and the
         CLI installs them into $env:USERPROFILE\.codeql\packages,
      3. dvl.exe, which ships with the WDK and turns the SARIF results into the
         driver verification log that the HLK Static Tools Logo test consumes.

    The three are described in codeql.json, so a project pins its toolchain in
    one place and otherwise inherits the versions the tools were tested with.
    An explicitly passed parameter overrides the file.

    Without -install this script only reports what it finds, and exits non-zero
    if a component is missing or the query suites do not resolve, so it can be
    used as a check in a build or CI step. With -install it downloads the CodeQL
    CLI release and any missing query packs, then reports.

    The report ends with a suite resolution check, which is what catches the
    mistake this script used to make: the driver pack declares
    microsoft/cpp-queries as a dependency, but the CLI does not download a
    pack's declared dependencies, and the driver suites reference the
    cpp-queries pack by name, so installing the driver pack alone leaves every
    driver suite unresolvable.

    build.ps1 -codeql uses the same components and the same locations; see
    docs/codeql.md.

.PARAMETER codeqlHome
    The directory holding the CodeQL CLI, for example C:\codeql-home.
    Default is $env:CODEQL_HOME, C:\codeql-home, or codeql.json.

.PARAMETER codeqlCli
    The path to a specific codeql.cmd to use, overriding -codeqlHome.

.PARAMETER version
    The CodeQL CLI version to download with -install. Default is the version
    from codeql.json, else 2.25.5, the oldest version validated for the 26H1
    driver packs.

.PARAMETER packs
    The query packs to check for and install, as 'name[@version]' entries.
    Default is the pair from codeql.json, else the pair released with the
    WHCP_26H1 / main branch: microsoft/windows-drivers@1.10.0 and
    microsoft/cpp-queries@0.0.5.

.PARAMETER dvlExe
    The path to dvl.exe. Default is the dvl.exe of the installed WDK.

.PARAMETER suite
    The query suite the resolution check runs, to prove the packs are complete:
    a name such as recommended, mustrun or mustfix. Default recommended.

.PARAMETER jsonFile
    The codeql.json tooling description to read. Default: ./codeql.json if the
    current directory has one, else the one that ships with the build tools.

.PARAMETER install
    Download the CodeQL CLI and any missing query packs.

.PARAMETER help
    Switch to display detailed help for this script.

.EXAMPLE
    .\codeql.ps1 -install
    Installs the CodeQL CLI and any missing query packs, then reports the
    resulting versions, paths, and suite resolution.

.EXAMPLE
    .\codeql.ps1
    Reports which components are present, without installing anything. Exits
    non-zero if one is missing or a driver suite does not resolve.

.NOTES
    - Downloading the CodeQL CLI is roughly 400MB, and the query packs add
      roughly 150MB on top of that.
    - The CodeQL CLI is only redistributed by GitHub for the analysis of open
      source software and certain other uses; run 'codeql --license' for the
      license terms.
    - Run this script with PowerShell 7 or later, like the rest of the tools.
#>

[CmdletBinding()]
param(
    # the directory holding the CodeQL CLI.
    [string]$codeqlHome=$null,
    # the path to a specific codeql.cmd to use.
    [string]$codeqlCli=$null,
    # the CodeQL CLI version to install.
    [string]$version=$null,
    # the query packs to check for and install, 'name[@version]'.
    [string[]]$packs=$null,
    # the path to dvl.exe.
    [string]$dvlExe=$null,
    # the query suite the resolution check runs.
    [string]$suite="recommended",
    # the codeql.json tooling description to read.
    [string]$jsonFile=$null,
    # install the CodeQL CLI and any missing query packs.
    [switch]$install,
    # invoke help for this script.
    [switch]$help
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$buildModule = "$root\buildFuncs.psm1"
Import-Module -Name $buildModule -Force

$status = 0
try {
    if ($help) {
        get-help $PSCommandPath -Detailed
        exit 1
    }
    # parameter, else codeql.json (the project's, else the tools'), else default
    $tooling = readCodeQlJson -jsonFile $jsonFile -projectRootPath (Get-Location).Path -htsToolsPath $root
    if ([string]::IsNullOrEmpty($version) -and -not [string]::IsNullOrEmpty($tooling.version)) {
        $version = $tooling.version
    }
    if ([string]::IsNullOrEmpty($codeqlHome) -and -not [string]::IsNullOrEmpty($tooling.home)) {
        $codeqlHome = $tooling.home
    }
    if ([string]::IsNullOrEmpty($codeqlCli) -and -not [string]::IsNullOrEmpty($tooling.cli)) {
        $codeqlCli = $tooling.cli
    }
    if ([string]::IsNullOrEmpty($dvlExe) -and -not [string]::IsNullOrEmpty($tooling.dvlExe)) {
        $dvlExe = $tooling.dvlExe
    }
    if (!$packs -or !$packs.Count) {
        if ($tooling.packs -and $tooling.packs.Count) {
            $packs = $tooling.packs
        }
        else {
            $packs = $script:defaultCodeQlPacks
        }
    }
    if ([string]::IsNullOrEmpty($version)) {
        $version = "2.25.5"
    }
    if ($tooling.file) {
        Write-Output "Tooling from:      $($tooling.file)"
    }
    else {
        Write-Output "Tooling from:      built in defaults, no codeql.json found"
    }

    # 1. the CodeQL CLI
    $cli = getCodeQlCli -codeqlHome $codeqlHome -codeqlCli $codeqlCli -version $version -install:$install
    $foundVersion = getCodeQlVersion -codeqlCli $cli
    Write-Output "CodeQL CLI:        $cli"
    Write-Output "CodeQL CLI version: $foundVersion"
    if ($foundVersion -ne $version) {
        Write-Output "  note: codeql.json asks for $version, $foundVersion is installed."
    }

    # 2. the query packs
    foreach ($pack in $packs) {
        try {
            getCodeQlPacks -codeqlCli $cli -packs @($pack) -install:$install
            Write-Output "Query pack:        $pack"
        }
        catch {
            Write-Output "Query pack:        $pack is NOT installed"
            Write-Output "  $_"
            $status = 1
        }
    }
    Write-Output "Query packs in:    $env:USERPROFILE\.codeql\packages"
    $driverPack = getCodeQlDriverPack -packs $packs
    foreach ($suiteName in @("recommended", "mustrun", "mustfix")) {
        Write-Output "  suite $($suiteName.PadRight(11)) $(getCodeQlSuiteSpec -pack $driverPack -suite $suiteName)"
    }

    # 3. dvl.exe
    $found = @()
    if (-not [string]::IsNullOrEmpty($dvlExe)) {
        $found = @(@($dvlExe) | Where-Object { test-path $_ -PathType Leaf })
        if (!$found.Count) {
            Write-Output "dvl.exe:           NOT found at the configured $dvlExe"
            $status = 1
        }
    }
    else {
        # ships with the WDK (the 10.0.22621.0+ WDK), not with Visual Studio
        $found = @(@("${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe") |
            Where-Object { test-path $_ -PathType Leaf })
    }
    if ($found.Count) {
        Write-Output "dvl.exe:           $($found[0])"
    }
    elseif ([string]::IsNullOrEmpty($dvlExe)) {
        Write-Output "dvl.exe:           NOT found; install the WDK, -dvl needs it"
        $status = 1
    }

    # the suites have to resolve, which needs every pack they reference: this is
    # the check that catches a pack list that is missing one of them.
    $suiteSpec = getCodeQlSuiteSpec -pack $driverPack -suite $suite
    $resolveOutput = @(& $cli resolve queries $suiteSpec 2>&1)
    $resolveExit = $LASTEXITCODE
    if ($resolveExit -eq 0) {
        Write-Output "Suite check:       $suiteSpec resolves, $(@($resolveOutput | Where-Object { "$_" -match '\.ql$' }).Count) queries"
    }
    else {
        Write-Output "Suite check:       FAILED to resolve $suiteSpec"
        @($resolveOutput | Where-Object { "$_" -match 'fatal|error|cannot be found' }) |
            ForEach-Object { Write-Output "  $_" }
        Write-Output "  a pack the suite references is missing from the pack list"
        $status = 1
    }

    Write-Output ""
    Write-Output "To analyze a driver project:"
    Write-Output "  .\build.ps1 -toolset VS2022 -codeql -codeqlSuite recommended -dvl"
    exit $status
}
finally {
    if (Get-Module -name buildFuncs) {
        Remove-Module -name buildFuncs
    }
}
