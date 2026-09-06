<#
.SYNOPSIS
    Sets up the development environment for the Windows Driver Kit (WDK).
.DESCRIPTION
    This script sets up a powershell session for the development environment 
    for the Windows Driver Kit (WDK) by initializing the necessary environment variables and paths.
    Supports the same set of toolsets as documented for build.ps1.
    Does not support nuget based WDK/SDK builds.
.PARAMETER toolset
    The toolset to use for the development environment.
.PARAMETER noSession
    Specifies whether to create a new PowerShell session.
.NOTES
    This script is intended to be used in a PowerShell environment.
      
#>
param(    
    [ValidateSet("EWDK","VS2026","VS2022","VS2019","VS2017","VS2015")]
    [string]$toolset="EWDK",
    [switch] $noSession
)

if ($noSession) {
    $root = $PSScriptRoot
    $buildModule = "$root\buildFuncs.psm1"
    Import-Module -Name $buildModule
    $toolcommands = getVsCmdScripts -ToolsVersion $toolSet 
    foreach( $cmdScript in $toolcommands) {
        log "evaluate: $cmdScript"
        Invoke-CmdScript $cmdScript
    } 
    try {
        $host.UI.RawUI.WindowTitle = "$($toolset) Shell"
    }
    catch {}
    # posh git auto clobbers the title
    & pwsh  -nologo  -noexit -command { 
        if ((get-module -name posh-git) -and $gitpromptsettings) {
            $gitpromptsettings.WindowTitle = $null
        } 
    }
} else {
    if ($env:VSCMD_VER) {
        if ($env:Version_Number) {
            $wdkver = $env:Version_Number
        } elseif ($env:WindowsSDKVersion) {
            $wdkver = $env:WindowsSDKVersion
        }
        "using existing Visual Studio version: $($env:VSCMD_VER), with WDK $wdkver"
        exit
    }

    & pwsh  -nologo -noprofile  -command  $PSCommandPath -noSession @PSBoundParameters
}
   
