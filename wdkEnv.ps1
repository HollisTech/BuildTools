param(    
    [ValidateSet("EWDK","VS2022","VS2019","VS2017","VS2015")]
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
   
