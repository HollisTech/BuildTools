<#

.SYNOPSIS
    Install, and report on, the CodeQL tooling used for Windows driver analysis.

.DESCRIPTION
    CodeQL analysis of Windows driver code needs three pieces of tooling, none of
    which is part of the Visual Studio or WDK install:

      1. the CodeQL CLI, unpacked into a directory such as C:\codeql-home,
      2. the Microsoft driver query pack (microsoft/windows-drivers) and the
         C/C++ query library it depends on (microsoft/cpp-queries), installed by
         the CLI into $env:USERPROFILE\.codeql\packages,
      3. dvl.exe, which ships with the WDK and turns the SARIF results into the
         driver verification log that the HLK Static Tools Logo test consumes.

    Without -install this script only reports what it finds, and exits non-zero
    if the CLI or the query pack is missing, so it can be used as a check in a
    build or CI step. With -install it downloads the CodeQL CLI release into
    -codeqlHome and any missing query packs, and then reports.

    build.ps1 -codeql uses the same tooling and the same locations; see
    docs/codeql.md.

.PARAMETER codeqlHome
    The directory holding the CodeQL CLI, for example C:\codeql-home.
    Default is $env:CODEQL_HOME, or C:\codeql-home.

.PARAMETER codeqlCli
    The path to a specific codeql.cmd to use, overriding -codeqlHome.

.PARAMETER version
    The CodeQL CLI version to download with -install. Default 2.25.5, the oldest
    version validated for the 26H1 driver query packs.

.PARAMETER pack
    The driver query pack to check for, as 'name@version'. Default
    "microsoft/windows-drivers@1.10.0".

.PARAMETER install
    Download the CodeQL CLI and any missing query packs.

.PARAMETER help
    Switch to display detailed help for this script.

.EXAMPLE
    .\codeql.ps1 -install
    Installs the CodeQL CLI and the driver query pack if they aren't present,
    then reports the resulting versions and paths.

.EXAMPLE
    .\codeql.ps1
    Reports which CodeQL pieces are available, without installing anything.
    Exits non-zero if the CodeQL CLI or the driver query pack is missing.

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
    [string]$version="2.25.5",
    # the driver codeql query pack, 'name@version'.
    [string]$pack="microsoft/windows-drivers@1.10.0",
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
    $cli = getCodeQlCli -codeqlHome $codeqlHome -codeqlCli $codeqlCli -version $version -install:$install
    $foundVersion = getCodeQlVersion -codeqlCli $cli
    Write-Output "CodeQL CLI:        $cli"
    Write-Output "CodeQL CLI version: $foundVersion"
    if ($foundVersion -ne $version -and $install) {
        Write-Output "  note: $version was requested, $foundVersion is installed."
    }
    try {
        getCodeQlPacks -codeqlCli $cli -packs @($pack) -install:$install
        Write-Output "Query pack:        $pack"
    }
    catch {
        Write-Output "Query pack:        $pack is NOT installed"
        Write-Output "  $_"
        $status = 1
    }
    Write-Output "Query packs in:    $env:USERPROFILE\.codeql\packages"
    foreach ($suite in @("recommended", "mustrun", "mustfix")) {
        $spec = getCodeQlSuiteSpec -pack $pack -suite $suite
        Write-Output "  suite $($suite.PadRight(11)) $spec"
    }
    # dvl.exe ships with the WDK (the 10.0.22621.0+ WDK), not with VS
    $dvl = @(@("${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe") |
        Where-Object { test-path $_ -PathType Leaf })
    if ($dvl.Count) {
        Write-Output "dvl.exe:           $($dvl[0])"
    } else {
        Write-Output "dvl.exe:           NOT found; install the WDK, -dvl needs it"
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
