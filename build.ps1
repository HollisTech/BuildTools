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
    "EWDK", "VS2026" "VS2022", "VS2019", "VS2017", "VS2015". Default is "EWDK".

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

.PARAMETER noNugetRestore
    Switch to skip the NuGet package restore step. 
    If not specified, NuGet packages will be restored if a packages.config file is found in the projectPath.

.PARAMETER codeql
    Switch to run CodeQL static analysis of the driver source code as part of the
    build. The build is handed to 'codeql database create' as the build command,
    so the CodeQL C/C++ extractor observes the compilation, and the resulting
    database is then analyzed into a SARIF file under the log directory.

    The toolset (and so the compiler) is unchanged: this is a build option, not
    a separate build. Because the extractor only sees compilation that happens
    while the database is created, the target defaults to Rebuild when this
    switch is used, and Release is strongly preferred over Debug.

    The CodeQL CLI is looked for in -codeqlCli, then -codeqlHome, then the
    CODEQL_HOME environment variable, then C:\codeql-home. Use -installCodeQL to
    download the CLI and the driver query packs if they aren't present yet.
    See docs/codeql.md, and
    https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/static-tools-and-codeql.

    Expect one msbuild warning from the second Rebuild on - see -codeqlDbDir -
    and allow it in the project's allowed-warnings.json, which docs/codeql.md
    shows. The default -target of Rebuild is what makes it appear.

    CodeQL's own output goes to "$logDir\CodeQL_<config>_<platform>.log", not to
    the build console: it narrates every step and every query it evaluates.

.PARAMETER codeqlHome
    The directory holding the CodeQL CLI, for example C:\codeql-home.
    Default is $env:CODEQL_HOME, or C:\codeql-home.

.PARAMETER codeqlCli
    The path to a specific codeql.cmd to use, overriding -codeqlHome.

.PARAMETER codeqlVersion
    The CodeQL CLI version to download when -installCodeQL is used. Default
    2.25.5.

.PARAMETER codeqlPack
    The driver CodeQL query pack, as 'name@version'. Default
    "microsoft/windows-drivers@1.10.0", the pack released with the WHCP_26H1 /
    main branch. The version must be one paired with -codeqlVersion in the
    Microsoft version matrix.

.PARAMETER codeqlSuite
    The query suite to run: "recommended" (default), "mustrun", "mustfix", or
    the path to a .qls file. mustrun is the suite WHCP certification requires;
    mustfix is the subset that must be clean to pass. Because the queries can
    produce false positives, failures do not fail the build unless
    -codeqlFailOnResults is specified.

.PARAMETER codeqlOutputDir
    The directory for the CodeQL SARIF files and driver verification logs.
    Default "$logDir/codeql".

.PARAMETER codeqlDbDir
    The directory the CodeQL databases are created in. Default
    "$env:LOCALAPPDATA/hts-codeql", outside the source tree, because a database
    per configuration and platform is several hundred MB and is an artifact
    rather than source. Note this does not avoid the msbuild Clean warning below:
    the CodeQL compiler tracer records its own build-tracer.log as a build
    output, so a later Rebuild's Clean tries to delete that file while the
    running extractor holds it open, wherever the database lives. Add

        "Microsoft\\.CppClean\\.targets.*build-tracer\\.log.*being used by another process"

    to allowedWarnings in the project's allowed-warnings.json, which is the
    supported way to keep a known-benign warning from failing the build.

.PARAMETER codeqlJobs
    The number of threads for the CodeQL import and query evaluation, passed to
    the CodeQL CLI as -j. Default 0, which uses one thread per core.

.PARAMETER codeqlProjectFile
    The driver project (.vcxproj) that the analysis belongs to, used when
    generating a driver verification log. Default is the project file when
    -projectName is a .vcxproj, otherwise the first .vcxproj with a sibling
    .inf or .inx file under -projectPath.

.PARAMETER codeqlDriverName
    The driver name used in the driver verification log, without the .sys or
    .dll extension. Default is the TargetName of -codeqlProjectFile.

.PARAMETER installCodeQL
    Switch to download and install the CodeQL CLI and any missing query packs
    instead of failing when they are not present.

.PARAMETER dvl
    Switch to also create a driver verification log (DVL) from the SARIF
    results, using the dvl.exe shipped with the WDK/eWDK. The DVL is what the
    HLK Static Tools Logo test parses, and is required for WHCP certification.
    Only meaningful with -codeql.

.PARAMETER codeqlFailOnResults
    Switch to fail the build when CodeQL reports any finding. Without it CodeQL
    findings are reported but informational, because the driver query suites
    contain checks that can report false positives.

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

.EXAMPLE
    .\build.ps1 -toolset "VS2022" -codeql -codeqlSuite recommended -dvl
    Rebuilds the project or solution in the current directory, runs the CodeQL
    driver "recommended" query suite over it, writes the SARIF results under
    ./logs/codeql, and creates a driver verification log from them.

.NOTES
    - Ensure that the required Visual Studio toolset is installed and accessible.
    - The script assumes it is located in its repository directory, and uses, at minimum buildfuncs.psm1.
    - Configuring this repository as a submodule in your project is the simple way to use this script.
    - Specifying the EWDK toolset will use the first mounted EWDK volume found, 
      unless the environment variable EWDKRoot is set. The path set in EWDKRoot will be used instead.
    - This script is intended for use in a Windows environment with Powershell 7 or later. 
      It may or may not work correctly in earlier versions of Powershell.
    - CodeQL databases and SARIF files are written under the log directory. Point
      -codeqlOutputDir somewhere outside the source tree when the logs directory
      is not a good place for large artifacts.
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
    Specify one of "EWDK","VS2026","VS2022","VS2019","VS2017","VS2015".
    Default EWDK.
    #>
    [ValidateSet("EWDK","VS2026","VS2022","VS2019","VS2017","VS2015")]
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
    # don't restore nuget packages.
    [switch]$noNugetRestore,
    # run CodeQL static analysis of the driver source code as part of the build.
    [switch]$codeql,
    # the directory holding the CodeQL CLI, default $env:CODEQL_HOME or C:\codeql-home.
    [string]$codeqlHome=$null,
    # the path to a specific codeql.cmd to use.
    [string]$codeqlCli=$null,
    # the CodeQL CLI version to install with -installCodeQL.
    [string]$codeqlVersion="2.25.5",
    # the driver codeql query pack, 'name@version'.
    [string]$codeqlPack="microsoft/windows-drivers@1.10.0",
    # the codeql query suite to run: recommended, mustrun, mustfix, or a .qls path.
    [string]$codeqlSuite="recommended",
    # the directory for codeql sarif output and driver verification logs, default "$logDir/codeql".
    [string]$codeqlOutputDir=$null,
    # the directory the codeql databases are created in, default "$env:LOCALAPPDATA/hts-codeql".
    [string]$codeqlDbDir=$null,
    # threads for the codeql import and query evaluation, 0 uses one per core.
    [int]$codeqlJobs=0,
    # the driver .vcxproj the analysis belongs to, used for the driver verification log.
    [string]$codeqlProjectFile=$null,
    # the driver name used in the driver verification log, without extension.
    [string]$codeqlDriverName=$null,
    # install the CodeQL CLI and any missing query packs instead of failing.
    [switch]$installCodeQL,
    # also create a driver verification log from the codeql sarif results.
    [switch]$dvl,
    # fail the build when codeql reports any result.
    [switch]$codeqlFailOnResults,
    # invoke help for this script.
    [switch]$help
)
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$buildModule = "$root\buildFuncs.psm1"
Import-Module -Name $buildModule -Force

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
        $platforms = @()
        $match = Get-Content "$projectPath\$projectName" | Select-String -Pattern '|Win32' -SimpleMatch
        if ($match) {
            $platforms += "Win32"
        }
        $match = Get-Content "$projectPath\$projectName" | Select-String -Pattern '|x86' -SimpleMatch
        if ($match) {
            $platforms += "x86"
        }
        $match = Get-Content "$projectPath\$projectName" | Select-String -Pattern '|x64' -SimpleMatch
        if ($match) {
            $platforms += "x64"
        }
        $match = Get-Content "$projectPath\$projectName" | Select-String -Pattern '|ARM64' -SimpleMatch
        if ($match) {
            $platforms += "ARM64"
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

    if ($codeql -and -not $PSBoundParameters.ContainsKey('target')) {
        <#
        The CodeQL extractor only observes compilation that happens while the
        database is created, so an incremental build can produce a database
        that is missing files, or that contains none at all when msbuild
        decides everything is already up to date. Rebuild, and this must
        happen before the msbuild argument line is assembled.
        #>
        $target = "Rebuild"
        log "no -target specified, using Rebuild so that codeql sees every compilation"
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
    $projectFile = "$projectPath\$projectName"
    $err = 0
    $totalRunStart = Get-Date  
    $dashes = "====================="

    #
    # CodeQL setup. The analysis wraps the build rather than following it, so
    # the tooling is resolved once, before the build loop, and all of that lives
    # in buildFuncs.psm1. $codeQlBuild stays $null for a plain build, and nothing
    # below dereferences it unless it is set.
    #
    # not $codeQl: PowerShell variable names are case insensitive, so $codeQl and
    # the -codeql switch parameter above are the same variable, and a hashtable
    # cannot be assigned to a switch.
    #
    $codeQlBuild = $null
    if ($codeql) {
        $codeQlBuild = initializeCodeQl -codeqlHome $codeqlHome -codeqlCli $codeqlCli `
            -codeqlVersion $codeqlVersion -codeqlPack $codeqlPack -codeqlSuite $codeqlSuite `
            -codeqlOutputDir $codeqlOutputDir -codeqlDbDir $codeqlDbDir `
            -codeqlProjectFile $codeqlProjectFile -codeqlDriverName $codeqlDriverName `
            -logDir $logDir -projectPath $projectPath -projectName $projectName `
            -projectRootPath $projectRootPath -configurations $configurations `
            -install:$installCodeQL
    }

    if (-not $noNugetRestore) {
        $packagesConfig = "$projectPath\packages.config"
        if (Test-Path $packagesConfig) {
            log "Restoring NuGet packages from $packagesConfig"
            nuget restore $packagesConfig -PackagesDirectory "$projectPath/packages" 
            if ($LASTEXITCODE -ne 0) {
                Write-Error "NuGet restore failed with exit code $LASTEXITCODE."
                exit $LASTEXITCODE
            }
        }
    }

    foreach ($config in $configurations) {
        foreach ($platform in $platforms) {
            $logPrefix = "$($target.replace(':','-'))_${config}_$($platform.replace(' ','-'))"
            $log = "$logDir\${logPrefix}.log"
            $errlog = "$logDir\${logPrefix}_errors.log"
            $warnlog = "$logDir\${logPrefix}_warnings.log"
            $codeQlPaths = @{}
            $codeQlArgs = @{}
            if ($null -ne $codeQlBuild) {
                $codeQlPaths = getCodeQlPaths -codeQl $codeQlBuild -config $config -platform $platform
                $codeQlArgs = @{
                    codeQlCmd = $codeQlBuild.cli
                    codeQlDb = $codeQlPaths.database
                    codeQlSuite = $codeQlBuild.suite
                    codeQlSarif = $codeQlPaths.sarif
                    codeQlLog = $codeQlPaths.log
                    sourceRoot = $codeQlBuild.sourceRoot
                    codeQlJobs = $codeqlJobs
                }
            }
            $buildArgs = @{
                toolSet = $toolset 
                consoleLog = $consolelog
                config = $config 
                platform = $platform
                msBuild = $msBuild 
                projectFile = $projectFile
                cmdCommon = $msbuildArgs
                log = $log 
                errlog = $errlog 
                warnlog = $warnlog
                projectPath = $projectPath
                buildMod = $buildModule
            } + $codeQlArgs

            $runStart = Get-Date
            log " $dashes Starting $config $platform $target $dashes`n"
            if ($null -ne $codeQlBuild) {
                # the codeql narration is in its own log, so point at it: this is
                # where the live progress of the next ten minutes is.
                log " codeql analysis progress: $($codeQlPaths.log)"
            }
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
            if ($null -ne $codeQlBuild) {
                $findings = publishCodeQlAnalysis -codeQl $codeQlBuild -paths $codeQlPaths `
                    -config $config -platform $platform -dvl:$dvl -failOnResults:$codeqlFailOnResults
                if ($findings -lt 0 -or ($findings -gt 0 -and $codeqlFailOnResults)) {
                    # -1 is an analysis that produced no sarif at all
                    $err = 1
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

