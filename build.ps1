<#

.SYNOPSIS
    Build a Visual Studio solution or project using the specified environment.

.DESCRIPTION
    This script automates the process of building Visual Studio solutions or projects.
    It supports multiple Visual Studio versions, build configurations, and platforms.
    The script can also read parameters from a JSON file. All build output is logged.

.PARAMETER jsonFile
    Path to a JSON file containing parameter values. If provided, the script will
    use the values from the JSON file to override default or explicitly set parameters.

.PARAMETER projectRootPath
    The root directory of the project. This is used to determine the location of
    build tools and logs if not explicitly specified.

.PARAMETER htsToolsPath
    The path to the build tools directory. If not specified, it defaults to 
    "$projectRootPath/BuildTools".

.PARAMETER toolset
    Specifies the Visual Studio toolset to use for the build. Valid options are:
    "EWDK", "VS2022", "VS2019", "VS2017", "VS2015". Default is "EWDK".

.PARAMETER projectPath
    The directory where the MSBuild project file to be built is located. Defaults to the current directory.

.PARAMETER projectName
    The name of the MSBuild project file to be built. If not specified, the script
    will attempt to find the first MSBuild-compatible project file in the projectPath.

.PARAMETER target
    The build target to execute. Default is "Build".

.PARAMETER configurations
    An array of build configurations to be built (e.g., "Release", "Debug"). 
    Default is "Release". Use "all" to build both "Release" and "Debug".

.PARAMETER platforms
    An array of build platforms to be built (e.g., "x64", "x86"). Default is "x64".
    Use "all" to build for all supported platforms.

.PARAMETER properties
    An array of arbitrary build properties in the format "name=value" to be passed to MSBuild.

.PARAMETER logDir
    The directory path where build log files will be stored. If not specified, it defaults to
    "$projectRootPath/logs" or "./logs" if projectRootPath is not set.

.PARAMETER consoleLogLevel
    Specifies the verbosity of the console log output from MSBuild. Valid options are:
    "Quiet", "Normal", "Verbose". Default is "Quiet".

.PARAMETER buildNumber
    The build number for this build. This is passed as an MSBuild property named 'BuildNumber'.
    Default is 0.

.PARAMETER wrapper
    A wrapper command or script to be used. The wrapper will be passed the MSBuild command line.

.PARAMETER detailedSummary
    Switch to generate a detailed summary of the MSBuild process.

.PARAMETER help
    Switch to display detailed help for this script.

.EXAMPLE    
    .\build.ps1 
    Builds the project or solution located in the current directory using the default toolset (EWDK), 
    with the "Release" configuration and "x64" platform.

.EXAMPLE
    .\build.ps1 -toolset "VS2022" 
    Builds the project or solution located in the current directory using Visual Studio 2022, 
    with the "Release" configuration and "x64" platform.

.EXAMPLE
    .\build.ps1 -jsonFile "buildParams.json"
    Builds the project using parameters specified in the "buildParams.json" file.
    The json file format expected is a simple key-value pair structure. 
    The keys should match the parameter names of this script.

.NOTES
    - Ensure that the required Visual Studio toolset is installed and accessible.
    - The script assumes it is located in its repository directory, and uses, at minimum buildfuncs.psm1.
    - Configuring this repository as a submodule in your project is the simple way to use this script.
    - Specifying the EWDK toolset will use the first mounted EWDK volume found, 
      unless the environment variable EWDKRoot is set. The path set in EWDKRoot will be used instead.
    - This script is intended for use in a Windows environment with Powershell 7 or later. 
      It may or may not work correctly in earlier versions of Powershell.
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
    [int]$buildNumber=-1, 
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
    if ($buildNumber -lt 0) {
        $buildNumber = buildNumber
        log "No build number specified, using $buildNumber"
    } else {
        log "Using specified build number: $buildNumber"
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
    $err = 0
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
    exit $err

}
catch {
    Write-Output $_ | Format-List * -Force | Out-String
    exit 1
}
finally {
    get-module -name buildFuncs | Remove-Module 
}

