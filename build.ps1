<#
.Description
    Build a visual studio solution or project using the correct environment.
#>

[CmdletBinding()]
param(
    # use this json file to set parameter values.
    [string] $jsonFile = $null,
    # the root directory for the project
    [string] $projectRootPath = $null,
    # the psth to the build tools
    [string] $htsToolsPath = $null,
    <#
    Which visual studio tools to use. 
    Specify one of "EWDK","VS2022","VS2019","VS2017","VS2015".
    Default EWDK.
    #>
    [ValidateSet("EWDK","VS2022","VS2019","VS2017","VS2015")]
    [string]$toolset="EWDK",
    # the directory where the msbuild project file to be built is located
    [Parameter(ValueFromPipeline)]    
    [string]$projectPath=".",
    # the name of the msbuild project file to be built
    [string]$projectName=$null,
    # the build target
    [string]$target="Build",
    # an array of build configurations to be built.
    [string[]]$configurations="Release",
    # an array of build platforms to be built
    [string[]]$platforms="x64",
    # an array of arbitrary build property (name=value) strings that should be passed to the build
    [string[]]$properties=@(),
    # the directory path for build log files
    [string]$logDir=$null,
    <#
    Verbosity of the console log from msbuild, one of "Quiet","Normal","Verbose".
    Default: "Quiet".
    #>
    [ValidateSet("Quiet","Normal","Verbose")]
    [string]$consoleLogLevel = "Quiet",
    # the build number for this build, set as a msbuild property named 'buildNumber'.
    [int]$buildNumber=0, 
    # a wrapper command or script, it will be passed the msbuild command line.
    [string]$wrapper=$null,
    # generate an msbuild detailed summary
    [switch]$detailedSummary,
    # invoke help for this script.
    [switch]$help
)
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$buildModule = "$root\buildFuncs.psm1"
Import-Module -Name $buildModule

try
{
    if ($help) { 
        get-help $PSCommandPath -Detailed
        exit 1
    }
    if ($jsonFile) {
        if (!(test-path $jsonFile -PathType Leaf)) {
            Write-Error "JSON file: $jsonFile invalid."
            exit 1
        }
        log "using JSON file $jsonFile"
        $params = (Get-Content -Raw $jsonFile) | ConvertFrom-Json
        $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters
        foreach ($key in  $ParameterList.Keys) {
            if ($params.PSobject.Properties[$key]) {                
                $val = $params.$key
                $var = Get-Variable -Name $key 
                $var.value =$val
                log "setting $($var.name) to $val from JSON file"
            } 
        }
    }
    if (-not [string]::IsNullOrEmpty($projectRootPath)) {
        if ([string]::IsNullOrEmpty($htsToolsPath)) {
            $htsToolsPath = "$projectRootPath/BuildTools"
        }
    
        if (-not ([string]::IsNullOrEmpty($htsToolsPath))) {        
            if (!(test-path $htsToolsPath -PathType Container)) {
                Write-Error "htsToolsPath: $htsToolsPath invalid."
                exit 1
            }
                   
            if (!(test-path $projectRootPath -PathType Container)) {
                Write-Error "projectRootPath: $projectRootPath invalid."
                exit 1
            } 
            $projectRootPath = Convert-Path $projectRootPath
            $htsToolsPath = Convert-Path $htsToolsPath
            $properties += @("htsToolsDir=$htsToolsPath", "projectRootPath=$projectRootPath")
        }
    } 
    if (!(test-path $projectPath -PathType Container)) {
        Write-Error "projectpath: $projectpath invalid."
        exit 1
    }
    $projectPath = Convert-Path $projectPath
    if (Test-Path -path $projectPath -PathType Container) {
        if (!$projectName) {
            # if not set, find the first msbuild target in projectPath
            $proj = @(get-childitem  $projectPath\* -Include "*.sln","*.proj","*.vcxproj","*.csproj")
            if ($proj.Count) {
                $projectName = $proj[0].Name
            } else {
                Write-Error "No msbuild projects found in $projectPath."
            }
        }    
    }
    else {
        $projectName = split-path -leaf $projectPath
        $projectPath = Split-Path $projectPath
    }
    if (!(Test-Path "$projectPath\$projectName")) {
        Write-Error "Cannot find $projectName in '$projectPath'."
        exit 1
    }
    
    if (!$logdir) {
        if (-not [string]::IsNullOrEmpty($projectRootPath)) {
            $logdir = "$projectRootPath/logs"
        }
        else {
            $logdir = "./logs"
        }
    }

    if (!(test-path $logdir)) {
        $null = mkdir $logdir 
    }    
    if (!(test-path -PathType Container $logDir)) {
        Write-Error "$logDir must be a directory."
        exit 1
    }
    $logDir = Convert-path  $logDir
    log "Building $projectPath\$projectName with logging to: $logDir"

    if ("$($configurations[0])" -eq "all") {
        $configurations = @("Release", "Debug")
    } 

    if ("$($platforms[0])" -eq "all") {
        $platforms = @("x86", "x64")
        $match = Get-Content "$projectPath\$projectName" | Select-String -Pattern '|Win32' -SimpleMatch
        if ($match) {
            $platforms = @("Win32", "x64")
        }
    }

    $consolelog = "/clp::NoSummary;"
    switch ($consoleLogLevel) {
        "Quiet" {
            $consolelog += "NoItemAndpropertiesList;ErrorsOnly;verbosity:quiet"
            $msVerbosity = "/verbosity:quiet"
        }
        "Normal" {        
            $consolelog += "NoItemAndpropertiesList;verbosity:normal"
            $msVerbosity = "/verbosity:normal"
        }
        "Verbose" {
            $consolelog += "verbosity:diagnostic"
            $msVerbosity = "/verbosity:diagnostic"
        }
    }
      
    $msbuild = "msbuild.exe"
    #
    # use echoargs to test calling msbuild.
    # $msbuild = "EchoArgs.exe"
    #
    if ($wrapper) {
        $msbuild = "$($wrapper) $msbuild"
    }
    $msbuildArgs = @(
        ".\$projectName",
        "/t:$target",
        $msVerbosity,
        "/noLogo",
        "/nr:false",
        "/p:BuildNumber=$buildNumber"
    )
    if ($detailedSummary) {
        $msbuildArgs += "-detailedSummary"
    }
    if ($properties.count) {
        $props = $properties -join ';'
        $msbuildArgs += "/p:$($props)"
    }

    $totalRunStart = Get-Date  
    $dashes = "====================="
    foreach ($config in $configurations) {
        foreach ($platform in $platforms) {
            $logPrefix = "$($target.replace(':','-'))_${config}_$($platform.replace(' ','-'))"
            $log = "$logDir\${logPrefix}.log"
            $errlog = "$logDir\${logPrefix}_errors.log"
            $warnlog = "$logDir\${logPrefix}_warnings.log"
            $buildArgs = @{
                toolSet = $toolset 
                consoleLog = $consolelog
                config = $config 
                platform = $platform
                msBuild = $msBuild 
                cmdCommon = $msbuildArgs
                log = $log 
                errlog = $errlog 
                warnlog = $warnlog
                projectPath = $projectPath
                buildMod = $buildModule
            }

            $runStart = Get-Date
            log " $dashes Starting $config $platform $target $dashes`n"
            $larr = @(doBuild @buildArgs)
            $runEnd = Get-Date
            if ($larr.Count -eq 0)
            {
                $err = 1
            }
            else
            {
                $err = $larr[-1] # The last line is the $LASTEXITCODE
                if ($larr.Count -gt 1)
                { 
                    Write-Output $larr[0..$($larr.Count - 2)] # drop last line
                }
            }
            if (Test-Path $errlog) {
                if((Get-Item $errlog).length -gt 0){
                    Write-Output " There were errors in the $config $platform $target"
                    Write-Output " Errors:"
                    get-content $errlog | Write-Output
                    $err = 1
                } else {
                    Remove-item $errlog
                }
            }
            if (Test-Path $warnlog) {
                if((Get-Item $warnlog).length -gt 0){
                    $badWarnings = @(filterWarnings -warningFile $warnlog -projectPath $projectPath)
                    if ($badWarnings.Count) {
                        Write-Output " There were unexpected warnings in the $config $platform $target Build."
                        Write-Output " Warnings:"
                        $badWarnings | Write-Output
                        $err = 1
                    }
                } else {
                    Remove-item $warnlog
                }
            }        
            log $(" $dashes $config $platform $target Complete Status $err Time {0:g} $dashes`n" -f   $($runEnd - $runStart))
            if ($err -ne 0) {
                Write-Output " There were errors in the $config $platform $target. Error: $err."
                exit $err
            }
        }
    }
    $totalRunEnd = Get-Date
    Write-Output (" Total Build Time {0:g} " -f $($totalRunEnd - $totalRunStart))

}
catch {
    Write-Output $_ | Format-List * -Force | Out-String
    exit 1
}
finally {
    get-module -name buildFuncs | Remove-Module 
}

