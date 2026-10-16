<#
.SYNOPSIS
common timestamped logger function

.DESCRIPTION
Prefixes the inoput string with a standard M.D.H.M.S timestamp 
and outputs that bew string to either a common logfile or
to the HOST output stream.

.PARAMETER logString
Parameter description

.EXAMPLE
log "a log message."

.NOTES
The internal logfile is not exposed.
#>
function log
{
    param (
        [String]$logString
    )
    $entry = "$(get-date -Uformat  "%m.%d:%H:%M:%S"): $($logString)"
    if ($script:logfile) {
        Add-Content -Path $logfile -Value  $entry   
    } else {
        Write-Host  $entry
    }
} 

<#
.SYNOPSIS
sign files

.DESCRIPTION
if the file signing.json exists then this function will read that file
to find the cert thumbnail and timestamp servers to use to sign the input
list of files.

.PARAMETER files
An array of file pathnames, each file will be signed.

.PARAMETER configFile
The optional json config file to use, default is ./signing.json

.PARAMETER signtool
The optional path to a specific version of signtool.exe to use.
By default this function will find the version of signtool associated 
with the installed version of visual studio build tools.

.PARAMETER index
The optional index in the json file of the thumbprint to use, default is 0.

.PARAMETER createJson
Optionally output a template singing.json and exit.

.PARAMETER noisy
Optional verbose logging.

.EXAMPLE
signobjs "file1","file2","file3"

.NOTES

#>
function signobjects {
    param(
        [string[]] $files,    
        [string] $configFile = "$($PSScriptRoot)\signing.json",
        [string] $signtool = $null,
        [int] $index = 0,
        [switch] $createJson,
        [switch] $noisy
    ) 
    $ErrorActionPreference = 'Stop'
    $jsonSchema = 
    @"
{
    index: 0,
    "certThumbPrint":[
        "cert thumbprint1",
        "cert thumbprint2"
    ],
    "timeservers": [
        "http://timestamp.entrust.net/TSS/RFC3161sha2TS",
        "http://timestamp.digicert.com"
    ]
}
"@
    if ($createJson) {
        $jsonSchema
    }
    else {
        $script:signed = $false
        $spew = ""
        $st = @("$($env:WindowsSdkVerBinPath)\x64\signtool.exe",
            "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\signtool.exe",
            "C:\Program Files (x86)\Windows Kits\8.1\bin\x86\signtool.exe")
        if ([string]::IsNullOrEmpty( $signtool ) -or ($null -eq (test-path $signtool))) {
            $signtool = $null
            foreach ($s in $st) {
                if (test-path $s) {
                    $signtool = $s
                    break
                }
            }
        }
        if (-not [string]::IsNullOrEmpty( $signtool )) {
            $spew += "using $signtool`n"
            $config = get-content $configFile | ConvertFrom-Json
            if ($null -ne $config.index) {
                $index = $config.index
            }
            if ($config.certThumbPrint.count -gt $index) {
                $thumb = $config.certThumbPrint[$index]
                foreach ($ts in $config.timeservers) {
                    $spew += & $signtool sign /sha1 $thumb /fd sha256 /tr "$ts" /td sha256 /v @files | Out-String
                    if ($LASTEXITCODE -eq 0 ) {
                        $script:signed = $true
                        $spew | set-content ".\signing-log.txt"
                        break;
                    }
                    if ($noisy) {
                        log $spew
                    }
                }
            }
        }
        else {
            log "signtool not found"
        }
        $script:signed
    }
}

function currentBranch {
    git branch --show-current 
}

function gitStats {
    $modified = 0
    $commits = 0
    #--ignore-submodules
    $output = git status --porcelain 
    $modified = $output.count
    $branch = currentBranch
    if ($null -eq $branch) {
        $branch = "DETACHED"
        $commits = git rev-list --count HEAD ^origin
    } else {
        $commits = git rev-list --count HEAD ^$branch
    }
    
    return @{"modified" = $modified;
             "branch" = $branch;
             "commits" = $commits}
}

Function isGitRepo
{
    $r = git rev-parse --is-inside-work-tree 2>$null
    $r -eq "true"
}

Function headSha
{
    $sha = ""
    if (isGitRepo) {
        $sha = git rev-parse --short HEAD
    }
    $sha
}

function gitRoot
{
    $r = ""
    if (isGitRepo) {
        $r = git rev-parse --show-toplevel
    }
    $r
}

Function buildNumber
    # json schema:
    # {
    #     "append" : "false",
    #     "regex" : "false"
    #     "protected" : [
    #         "pattern1",
    #         "pattern2",
    #         ...
    #     ]
    # }
{    
    param(
        $repoPath=$(gitRoot),
        $jsonFile=$null,
        [switch]
        $allowModified)

    $n = 0
    if (isGitRepo) {        
        $status = gitStats
        $curBranch = $status["branch"]
        $gitCount = $status["modified"] 
        if ($allowModified) {
            $gitCount = 0
            log "override modified files."
        }
        if ($gitCount -eq 0) {
            $branches = @("main") # default.
            $regex = $false
            $generate = $false
            if ($null -eq $jsonFile) {
                $jsonFile = $repoPath + "/.protected-branches.json"
            }
            if (test-path $jsonFile) {
                $json = Get-Content $jsonFile | ConvertFrom-Json
                $append = $true
                if ( "append" -in $json.PSobject.Properties.Name) {
                    $append = ($json.append -eq $true)
                }
                if ( "regex" -in $json.PSobject.Properties.Name) {
                    $regex = ($json.regex -eq $true)
                }
                if ("protected" -in $json.PSobject.Properties.Name) {
                    $protected = $json.protected
                    if ($protected.count) {
                        if ($append) {
                            $branches = $branches + $protected
                        }
                        else {
                            $branches = $protected
                        }
                    }
                }
            }
           
            if ($regex) {
                $regexString  = $branches -Join "|"
                if ($curBranch -match $regexString) {
                    log "protected branches regex: ''$regexString'' matches branch: $curBranch"
                    $generate = $true
                } else {
                    log "protected branches regex: ''$regexString'' did not match branch: $curBranch"
                }

            } elseif ($branches -contains $curBranch) { 
                log "branch: $curBranch explicitly matched."
                $generate = $true
            } else {
                log "branch: $curBranch in repo $repoPath not in protected branches $($branches -Join ";"), using build number 0"
            }
            if ($generate) {         
                $n = git rev-list --count HEAD
                log "generated git build number is $n"
            }
        } else {
            log "branch: $curBranch in repo $repoPath has modified uncommitted files, using build number $n"
        }
    }
    $n
}

function filterWarnings {
    # Json extension schema:
    # {
    #     "allowedWarnings" : [
    #         "pattern1",
    #         "pattern2",
    #         ...
    #     ]
    # }
    param(
        $warningFile,
        $projectPath,
        $projectRoot)
    $regex = $null
    # customize the allowed warnings here
    # the general pattern for c++ warnings is ':\bwarning [A-Z]+([0-9]{4}):'
    # note you need to escape '\b' in the json file as '\\b'
    $jsonFile = $projectPath + "/allowed-warnings.json"
    if (!(test-path $jsonFile)) {
        $jsonFile = $projectRoot + "/allowed-warnings.json"
        if (!(test-path $jsonFile)) {
            $jsonFile =$null
        }
    }
    if ($jsonFile) {
        log "filtering additional warnings using $jsonFile"
        $allowed = Get-Content $jsonFile | ConvertFrom-Json
        if ( "allowedWarnings" -in $allowed.PSobject.Properties.Name) {
            $allowed.allowedWarnings | ForEach-Object {
                if ($regex) {
                    $regex += "|" + $_
                } else {
                    $regex = $_
                }
            }
        }
    }
    $output = @()
    foreach ($line in Get-Content $warningFile) {
        if (!$regex) {
            $output += $line
        } elseif ($line -notMatch $regex ) {
            $output += $line
        }
    }
    return $output
}

function getVsCmdScripts
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $ToolsVersion)
    
    $toolsPath = $null
    $script:defaultCommunityToolsPath = $null
    $script:defaultProfessionalToolsPath = $null
    $script:defaultEnterpriseToolsPath = $null
    $batName = @()
    switch ($ToolsVersion)
    {
        'EWDK' {
            $batName = @("SetupBuildEnv.cmd", "SetupVSEnv.cmd")
            if ($env:EWDKroot) {
                $ep = "$($env:EWDKroot)\BuildEnv"
                if (Test-Path -Path $ep -PathType Container) {
                    $script:defaultProfessionalToolsPath = $ep
                    log "EWDK assigned at $ep"
                    break
                }
            } else {
                Get-PSDrive -PSProvider 'FileSystem' | ForEach-Object {
                    $drv = "$($_.Name):"
                    "BuildEnv","EWDK\BuildEnv" | ForEach-Object {
                        $ep = "$drv\$_"
                        if (Test-Path -Path $ep -PathType Container) {
                            $script:defaultProfessionalToolsPath = $ep
                            log "EWDK found at $ep"
                            break
                        }
                    }
                    if ($script:defaultProfessionalToolsPath){
                        break
                    }
                }
            }
        }
        'VS2026' {
            $defaultProfessionalToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\18\Professional\Common7\Tools"
            $defaultEnterpriseToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\18\Enterprise\Common7\Tools"
            $defaultCommunityToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\18\Community\Common7\Tools"
            $batName = @("vsdevcmd.bat")
        }
        'VS2022' {
            $defaultProfessionalToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\Common7\Tools"
            $defaultEnterpriseToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\Common7\Tools"
            $defaultCommunityToolsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\Tools"
            $batName = @("vsdevcmd.bat")
        }
        'VS2019' {
            $defaultProfessionalToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\Common7\Tools"
            $defaultEnterpriseToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\Common7\Tools"
            $defaultCommunityToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\Common7\Tools"
            $batName = @("vsdevcmd.bat")
        }
        'VS2017' {
            $defaultProfessionalToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\Common7\Tools"
            $defaultEnterpriseToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio\2017\Enterprise\Common7\Tools"
            $batName = @("vsdevcmd.bat")
        }
        'VS2015' {
            $defaultProfessionalToolsPath = "${ProgramFiles(x86)}\Microsoft Visual Studio 14.0\Common7\Tools"
            $batName = @("vsvars32.bat")
        }
        default {
            Write-Error ("Unknown vs tools version: $ToolsVersion")
        }
    }
    if ($defaultEnterpriseToolsPath -and (Test-Path $defaultEnterpriseToolsPath))
    {
        $toolsPath = $defaultEnterpriseToolsPath
    }
    elseif ($defaultProfessionalToolsPath -and (Test-Path $defaultProfessionalToolsPath)) 
    {
        $toolsPath = $defaultProfessionalToolsPath
    }
    elseif ($defaultCommunityToolsPath -and (Test-Path $defaultCommunityToolsPath))
    {
        $toolsPath = $defaultCommunityToolsPath
    }
    else {
        Write-Error "Build tools for $ToolsVersion not found."
        exit 1
    }
    
    if (!(Test-Path $toolsPath))
    {
        Write-Error ("Cannot find tools path '$toolsPath'. Is version $ToolsVersion installed?")
        exit 1
    }                    		
    $batname = $batname.ForEach( { "$toolsPath" + "\" + $_ } )
    $batName
}
function Invoke-CmdScript {
    # derived from:
    ###############################################################################
    # WintellectPowerShell Module
    # Copyright (c) 2010-2017 - John Robbins/Wintellect
    # 
    # Do whatever you want with this module, but please do give credit.
    ###############################################################################
    param(
        [Parameter(Mandatory = $true)]
        [string] $command,
        ## The arguments to the script
        [string] $ArgumentList
    )
    
    & "${env:COMSPEC}"  /c " `"$command`" $argumentList && set " | Foreach-Object {
        if ($_ -match "^(.*?)=(.*)$")
        {
            $key = $Matches[1]
            $newValue = $Matches[2]
            Set-Content "env:${key}" $newValue
        }
    }
}

function doBuild
{  
    param(
        [string]$toolSet,
        [string]$consoleLog,
        [string]$config,
        [string]$platform,
        [string]$msBuild,
        # the msbuild project or solution file to build, a full path.
        [string]$projectFile,
        [string[]]$cmdCommon,
        [string]$log,
        [string]$errlog,
        [string]$warnlog,
        [string]$projectPath,
        [string]$buildMod,
        <#
        CodeQL options. When codeQlCmd is set the msbuild command line is not
        run directly: it is handed to 'codeql database create' as the build
        command, so that the CodeQL C/C++ extractor observes the compilation,
        and the resulting database is then analyzed with codeQlSuite.
        #>
        [string]$codeQlCmd = $null,
        [string]$codeQlDb = $null,
        [string]$codeQlSuite = $null,
        [string]$codeQlSarif = $null,
        # where the codeql console output goes: it narrates every step, and every
        # query it evaluates, which is noise in a build console.
        [string]$codeQlLog = $null,
        [string]$sourceRoot = $null,
        [int]$codeQlJobs = 0
    )

    $cmd = @($projectFile) + $cmdCommon + @(
        "/p:configuration=$config",
        "/p:platform=$platform",
        "$consolelog",
        "/flp:ShowCommandLine;ShowTimestamp;Verbosity=normal;LogFile=$log",
        "/flp2:ErrorsOnly;LogFile=$errlog",
        "/flp3:WarningsOnly;LogFile=$warnlog"
    )

    $staleLogs = @($log, $errlog, $warnlog)
    if (-not [string]::IsNullOrEmpty($codeQlLog)) {
        # the codeql console log is appended to by both its commands, so start
        # from an empty one rather than mixing runs.
        $staleLogs += $codeQlLog
    }
    $staleLogs | foreach-object {    
        if (test-path $_) {
            remove-item $_
        }
    }

    $initScript = [scriptblock]::Create("Import-Module -Name '$buildMod'")

    $job = Start-Job -InitializationScript $initScript -ScriptBlock {
        $ErrorActionPreference = 'Continue'
        $VerbosePreference = 'SilentlyContinue' 
        
        $ecode = 1
        try {
            set-location $using:projectPath
            log "using toolset $using:toolSet project path $using:projectPath $(get-date)"
            $toolcommands = getVsCmdScripts -ToolsVersion $using:toolSet 
            foreach( $cmdScript in $toolcommands) {
                log "evaluate: $cmdScript"
                Invoke-CmdScript $cmdScript
            }
            $msargs = @()
            $msargs += $using:cmd
            if ($using:codeQlCmd) {
                $buildCommand = "$($using:msBuild) $($msargs -join ' ')"
                $db = $using:codeQlDb
                if (test-path $db) {
                    # 'codeql database create' fails if the database directory exists.
                    remove-item -recurse -force $db
                }
                <#
                codeql narrates every step it takes, and every query it
                evaluates, across stdout and stderr: all of it goes to its own
                log so the build console stays readable. Redirecting here also
                keeps that output out of the job's error stream, which
                Receive-Job would otherwise replay in the caller.
                #>
                $codeQlOutput = $using:codeQlLog
                if ([string]::IsNullOrEmpty($codeQlOutput)) {
                    $codeQlOutput = "$env:TEMP\hts-codeql.log"
                }
                log "codeql database create: $(Split-Path -Leaf $db) (progress in $codeQlOutput)"
                & $using:codeQlCmd database create $db --language=cpp "--source-root=$($using:sourceRoot)" "--command=$buildCommand" -j $using:codeQlJobs *>> $codeQlOutput
                $ecode = $LASTEXITCODE
                if ($ecode -eq 0) {
                    log "codeql database analyze: `"$($using:codeQlSuite)`" (progress in $codeQlOutput)"
                    & $using:codeQlCmd database analyze $db "$($using:codeQlSuite)" --format=sarifv2.1.0 "--output=$($using:codeQlSarif)" -j $using:codeQlJobs --rerun *>> $codeQlOutput
                    $ecode = $LASTEXITCODE
                }
            } else {
                log "$($using:msBuild) $msargs"
                & $using:msBuild @msargs
                $ecode = $LASTEXITCODE
            }
        }
        catch {
            Write-Output $_ | Format-List * -Force | Out-String 
            $ecode = 2
        }
        finally {
            Write-Output -InputObject "${ecode}"
        }
    }

    Wait-Job -Job $Job | Out-Null
    $jobErrors = @()
    $jobOutput = @(Receive-Job -Job $Job -ErrorAction SilentlyContinue -ErrorVariable jobErrors)
    <#
    A native tool that writes progress or diagnostics to stderr produces error
    records in the job's error stream, and Receive-Job replays those in the
    caller. In a caller that has $ErrorActionPreference = 'Stop' - this script -
    that replay is a terminating error, so any tool that is merely chatty on
    stderr aborts the build even though its exit code is zero. (codeql is the
    worst offender and is now redirected to its own log, but nuget and msbuild
    are not.) Collect those records and re-emit them as ordinary output; the
    exit code is what decides success.
    #>
    $lines = @($jobErrors | ForEach-Object { "$_" }) + $jobOutput
    $lines -split "`n"  
}

#=====================================================================
# CodeQL support
#
# Windows driver CodeQL analysis, per
# https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/static-tools-and-codeql
# and
# https://learn.microsoft.com/en-us/windows-hardware/drivers/develop/creating-a-driver-verification-log
#=====================================================================

<#
.SYNOPSIS
    Locate the CodeQL command line toolchain, optionally installing it.

.DESCRIPTION
    Returns the full path to codeql.cmd. The search order is: the -codeqlCli
    path, -codeqlHome, the CODEQL_HOME environment variable, then C:\codeql-home.
    Both the layout produced by unzipping codeql-win64.zip into <home> (which
    gives <home>\codeql\codeql.cmd) and codeql.cmd directly in <home> are
    recognized.

    With -install the release zip for -version is downloaded and expanded into
    -codeqlHome, which is the layout used throughout the Microsoft driver
    CodeQL documentation.

.PARAMETER codeqlHome
    The directory holding the CodeQL CLI, e.g. C:\codeql-home.

.PARAMETER codeqlCli
    The path to a codeql.cmd or codeql.exe to use, overriding -codeqlHome.

.PARAMETER version
    The CodeQL CLI version to download when -install is specified. Default
    2.25.5, the oldest version validated for the 26H1 driver query packs.

.PARAMETER install
    Download and expand the CodeQL CLI if it is not already present.

.EXAMPLE
    $cli = getCodeQlCli -install
#>
function getCodeQlCli {
    param(
        [string] $codeqlHome = $null,
        [string] $codeqlCli = $null,
        [string] $version = "2.25.5",
        [switch] $install
    )
    $ErrorActionPreference = 'Stop'
    if (-not [string]::IsNullOrEmpty($codeqlCli)) {
        if (!(test-path $codeqlCli -PathType Leaf)) {
            Write-Error "codeqlCli: '$codeqlCli' not found."
            exit 1
        }
        return (Convert-Path $codeqlCli)
    }
    if ([string]::IsNullOrEmpty($codeqlHome)) {
        if ($env:CODEQL_HOME) {
            $codeqlHome = $env:CODEQL_HOME
            log "using CODEQL_HOME: $codeqlHome"
        } else {
            $codeqlHome = "C:\codeql-home"
        }
    }
    foreach ($candidate in @("$codeqlHome\codeql\codeql.cmd", "$codeqlHome\codeql.cmd")) {
        if (test-path $candidate -PathType Leaf) {
            return (Convert-Path $candidate)
        }
    }
    if (-not $install) {
        Write-Error (("CodeQL CLI not found under '$codeqlHome'. Run '{0}\codeql.ps1 -install' " +
            "(or pass -installCodeQL) to download it, or set CODEQL_HOME.") -f $PSScriptRoot)
        exit 1
    }
    if (!(test-path $codeqlHome -PathType Container)) {
        $null = mkdir $codeqlHome
    }
    $zip = "$codeqlHome\codeql-win64-$version.zip"
    $url = "https://github.com/github/codeql-cli-binaries/releases/download/v$version/codeql-win64.zip"
    log "downloading CodeQL CLI $version from $url"
    # Invoke-WebRequest with the progress bar enabled is an order of magnitude slower.
    $progress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $codeqlHome -Force
    }
    finally {
        $ProgressPreference = $progress
    }
    if (!(test-path "$codeqlHome\codeql\codeql.cmd" -PathType Leaf)) {
        Write-Error "CodeQL CLI install into '$codeqlHome' failed."
        exit 1
    }
    log "CodeQL CLI $version installed in $codeqlHome"
    Convert-Path "$codeqlHome\codeql\codeql.cmd"
}

<#
.SYNOPSIS
    Report the version of a CodeQL CLI as a string.

.PARAMETER codeqlCli
    The path to codeql.cmd.
#>
function getCodeQlVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $codeqlCli
    )
    $out = & $codeqlCli version 2>$null | Select-Object -First 1
    if ("$out" -match 'release\s+([0-9]+\.[0-9]+\.[0-9]+)') {
        $Matches[1]
    } else {
        "$out"
    }
}

<#
.SYNOPSIS
    Ensure the CodeQL query packs needed for driver analysis are installed.

.DESCRIPTION
    The packs are the driver query pack (microsoft/windows-drivers) and, for
    25H2 and later, the C/C++ query library it depends on
    (microsoft/cpp-queries). The CodeQL CLI installs packs into
    "$env:USERPROFILE\.codeql\packages\<name>\<version>".

.PARAMETER codeqlCli
    The path to codeql.cmd.

.PARAMETER packs
    An array of 'name@version' pack specs, e.g. 'microsoft/windows-drivers@1.10.0'.

.PARAMETER install
    Download any missing pack instead of failing.

.EXAMPLE
    getCodeQlPacks -codeqlCli $cli -packs "microsoft/windows-drivers@1.10.0" -install
#>
function getCodeQlPacks {
    param(
        [Parameter(Mandatory = $true)]
        [string] $codeqlCli,
        [Parameter(Mandatory = $true)]
        [string[]] $packs,
        [switch] $install
    )
    $ErrorActionPreference = 'Stop'
    $packRoot = "$env:USERPROFILE\.codeql\packages"
    foreach ($pack in $packs) {
        $parts = $pack -split '@', 2
        $name = $parts[0]
        $ver = ""
        if ($parts.Count -gt 1) {
            $ver = $parts[1]
        }
        $installed = $false
        if ($ver) {
            $cachePath = Join-Path (Join-Path $packRoot $name) $ver
            if (test-path $cachePath -PathType Container) {
                $installed = $true
            }
        }
        if (-not $installed) {
            # 'codeql resolve packs' prints "    <name>:" followed by "      @<version>:"
            $found = @(& $codeqlCli resolve packs 2>$null | Select-String -Pattern ([regex]::Escape($name) + ":"))
            if ($found.Count) {
                if (!$ver -or ("$found" -match [regex]::Escape("@" + $ver))) {
                    $installed = $true
                }
            }
        }
        if ($installed) {
            log "CodeQL pack $pack is installed"
            continue
        }
        if (-not $install) {
            Write-Error (("CodeQL query pack '$pack' is not installed. Run 'codeql pack download {0}' " +
                "or pass -installCodeQL.") -f $pack)
            exit 1
        }
        log "downloading CodeQL query pack $pack"
        & $codeqlCli pack download $pack
        if ($LASTEXITCODE -ne 0) {
            Write-Error "codeql pack download $pack failed with exit code $LASTEXITCODE."
            exit $LASTEXITCODE
        }
    }
}

<#
.SYNOPSIS
    Turn a CodeQL suite name or path into a query suite specifier.

.DESCRIPTION
    A path to a .qls file is returned unchanged. Otherwise the name is resolved
    against the windows-driver-suites directory of the driver query pack, which
    is how the Microsoft documentation refers to them:
    microsoft/windows-drivers:windows-driver-suites/recommended.qls

    recommended - broad set of driver and C/C++ checks, the default.
    mustrun     - the checks that must be run to pass WHCP certification.
    mustfix     - the subset that must be fixed to pass WHCP certification.

.PARAMETER pack
    The driver query pack spec, e.g. 'microsoft/windows-drivers@1.10.0'.

.PARAMETER suite
    A suite name or the path to a .qls file. Default 'recommended'.

.EXAMPLE
    getCodeQlSuiteSpec -pack "microsoft/windows-drivers@1.10.0" -suite mustfix
#>
function getCodeQlSuiteSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string] $pack,
        [string] $suite = "recommended"
    )
    $ErrorActionPreference = 'Stop'
    if ($suite -match '\.qls$') {
        if (!(test-path $suite -PathType Leaf)) {
            Write-Error "codeql suite file '$suite' not found."
            exit 1
        }
        return (Convert-Path $suite)
    }
    $known = @("recommended", "mustrun", "mustfix", "ported_driver_ca_checks",
        "windows_mustfix_partial", "windows_recommended_partial")
    $name = $suite.ToLower()
    if ($known -notcontains $name) {
        Write-Error ("Unknown codeql suite '$suite'. Use one of " + ($known -join ", ") + ", or the path to a .qls file.")
        exit 1
    }
    "$($pack.Split('@')[0]):windows-driver-suites/$name.qls"
}

<#
.SYNOPSIS
    Summarize the results in a CodeQL SARIF file.

.DESCRIPTION
    Returns an ordered dictionary with the total number of results, the count by
    level (error, warning, note), and a sorted list of 'ruleId (count)' strings.

.PARAMETER sarifFile
    The path to the SARIF file.

.EXAMPLE
    $r = getSarifResults -sarifFile ./logs/codeql/x.sarif
    "$($r.total) findings, $($r.error) of them errors"
#>
function getSarifResults {
    param(
        [Parameter(Mandatory = $true)]
        [string] $sarifFile
    )
    $summary = [ordered]@{ total = 0; error = 0; warning = 0; note = 0; rules = @() }
    if (!(test-path $sarifFile -PathType Leaf)) {
        return $summary
    }
    $counts = @{}
    $sarif = Get-Content -Raw $sarifFile | ConvertFrom-Json
    foreach ($run in @($sarif.runs)) {
        # CodeQL writes the default severity of a rule into the rule metadata;
        # a result only carries its own level when it differs from the default.
        $ruleLevels = @{}
        if ($run.PSObject.Properties.Name -contains 'tool') {
            $rules = @($run.tool.driver.rules)
            for ($i = 0; $i -lt $rules.Count; $i++) {
                $rule = $rules[$i]
                $level = "warning"
                if ($rule.PSObject.Properties.Name -contains 'defaultConfiguration') {
                    if ($rule.defaultConfiguration.PSObject.Properties.Name -contains 'level') {
                        $level = "$($rule.defaultConfiguration.level)"
                    }
                }
                $ruleLevels[$i] = $level
            }
        }
        foreach ($result in @($run.results)) {
            if ($null -eq $result) { continue }
            $summary.total++
            # Set-StrictMode is on in the caller: never touch a property blind.
            $level = ""
            if ($result.PSObject.Properties.Name -contains 'level') {
                $level = "$($result.level)"
            }
            elseif (($result.PSObject.Properties.Name -contains 'ruleIndex') -and
                $ruleLevels.ContainsKey([int]$result.ruleIndex)) {
                $level = $ruleLevels[[int]$result.ruleIndex]
            }
            switch ($level) {
                "error" { $summary.error++ }
                "warning" { $summary.warning++ }
                default { $summary.note++ }
            }
            $ruleId = ""
            if ($result.PSObject.Properties.Name -contains 'ruleId') {
                $ruleId = "$($result.ruleId)"
            }
            if ($ruleId) {
                if ($counts.ContainsKey($ruleId)) {
                    $counts[$ruleId] = $counts[$ruleId] + 1
                } else {
                    $counts[$ruleId] = 1
                }
            }
        }
    }
    $summary.rules = @($counts.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        ForEach-Object { "$($_.Key) ($($_.Value))" })
    $summary
}

<#
.SYNOPSIS
    Create a driver verification log (DVL) from CodeQL SARIF results.

.DESCRIPTION
    dvl.exe consumes the SARIF file and produces the .DVL.XML that the HLK
    Static Tools Logo test parses. dvl.exe is invoked in a staging directory
    holding a copy of the SARIF file and of the project file, because that is
    the layout it expects: the results to be consumed and a vcxproj in the same
    directory. The generated log is then copied to -outputFile.

.PARAMETER sarifFile
    The path to the CodeQL SARIF file.

.PARAMETER driverName
    The driver name, without the .sys or .dll extension.

.PARAMETER architecture
    One of x64, x86, arm, arm64.

.PARAMETER projectFile
    The path to the driver project (.vcxproj) file, copied into the staging
    directory.

.PARAMETER outputFile
    The path of the .DVL.XML file to write.

.PARAMETER dvlExe
    The path to dvl.exe, overriding the search of the installed WDKs.

.EXAMPLE
    newDvl -sarifFile ./logs/codeql/x.sarif -driverName htsVsp -architecture x64 -projectFile ./ComPort/htsvsp.vcxproj -outputFile ./logs/codeql/htsVsp.DVL.XML
#>
function newDvl {
    param(
        [Parameter(Mandatory = $true)]
        [string] $sarifFile,
        [Parameter(Mandatory = $true)]
        [string] $driverName,
        [string] $architecture = "x64",
        [string] $projectFile = $null,
        [string] $outputFile = $null,
        [string] $dvlExe = $null,
        <#
        Where to look for dvl.exe when -dvlExe is not given: the project roots
        whose packages directory may hold the WDK nuget packages. See getDvlExe.
        #>
        [string[]] $projectSearchRoot = @()
    )
    $ErrorActionPreference = 'Stop'
    if (!(test-path $sarifFile -PathType Leaf)) {
        Write-Error "sarifFile: '$sarifFile' not found."
        exit 1
    }
    if ([string]::IsNullOrEmpty($dvlExe)) {
        $dvlExe = getDvlExe -searchRoot @($projectSearchRoot) -architecture $architecture
    }
    if ([string]::IsNullOrEmpty($dvlExe) -or !(test-path $dvlExe -PathType Leaf)) {
        Write-Error ("dvl.exe not found. It ships with the WDK: look in the installed WDK " +
            "(${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl), or in the project's WDK nuget " +
            "packages (<root>\packages\Microsoft.Windows.WDK.<arch>.<version>\c\tools\dvl). " +
            "Pass -dvlExe, or set it in codeql.json.")
        exit 1
    }
    switch ($architecture.ToLower()) {
        "x64" { $arch = "x64" }
        "x86" { $arch = "x86" }
        "win32" { $arch = "x86" }
        "arm" { $arch = "arm" }
        "arm64" { $arch = "arm64" }
        default {
            Write-Error "Unsupported dvl architecture '$architecture'."
            exit 1
        }
    }
    if ([string]::IsNullOrEmpty($outputFile)) {
        $outputFile = "$(Split-Path -Parent (Convert-Path $sarifFile))\$driverName.DVL.XML"
    }
    $staging = Join-Path $env:TEMP "hts-dvl-$driverName-$arch"
    if (test-path $staging) {
        remove-item -recurse -force $staging
    }
    $null = mkdir $staging
    copy-item $sarifFile (Join-Path $staging (Split-Path -Leaf (Convert-Path $sarifFile)))
    if (-not [string]::IsNullOrEmpty($projectFile) -and (test-path $projectFile -PathType Leaf)) {
        copy-item $projectFile $staging
    }
    log "dvl.exe /manualCreate $driverName $arch (in $staging)"
    Push-Location $staging
    try {
        # dvl.exe prints a banner and the resulting path; don't return that to
        # the caller, only the path of the file this function produced.
        & $dvlExe /manualCreate $driverName $arch | Out-Null
        $ecode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($ecode -ne 0) {
        Write-Error "dvl.exe failed with exit code $ecode."
        exit $ecode
    }
    $produced = @(Get-ChildItem $staging -Filter "*.DVL.XML" -Recurse)
    if (!$produced.Count) {
        Write-Error "dvl.exe reported success but produced no DVL.XML in $staging."
        exit 1
    }
    $outDir = Split-Path -Parent $outputFile
    if ($outDir -and !(test-path $outDir)) {
        $null = mkdir $outDir
    }
    copy-item $produced[0].FullName $outputFile -Force
    log "DVL written to $outputFile"
    Convert-Path $outputFile
}

#=====================================================================
# CodeQL build support
#
# The default query packs: the driver pack, and the C/C++ pack its suites
# reference by name. Both must be installed - see readCodeQlJson.
$script:defaultCodeQlPacks = @(
    "microsoft/windows-drivers@1.10.0",
    "microsoft/cpp-queries@0.0.5"
)
#
# The CodeQL equivalent of the build loop itself: build.ps1 asks these to
# resolve the tooling once, to name each configuration's artifacts, and to
# report and log the results. Keeping them here is what keeps build.ps1 the
# thin wrapper around doBuild that the rest of it is.
#=====================================================================

<#
.SYNOPSIS
    Read the CodeQL tooling description from a json file.

.DESCRIPTION
    The three components a driver CodeQL build needs, describing them in one
    place instead of on every command line:

        {
            "cli"   : { "version" : "2.25.5", "home" : null, "path" : null },
            "packs" : [ "microsoft/windows-drivers@1.10.0",
                        "microsoft/cpp-queries@0.0.5" ],
            "dvl"   : { "path" : null }
        }

    Every entry is optional; an absent or null one leaves the corresponding
    parameter to supply the value, falling back to the script default.

    Both packs are needed. microsoft/windows-drivers declares
    microsoft/cpp-queries as a dependency (^0.0.5 in its qlpack.yml), but the
    CLI does not resolve a pack's declared dependencies when it downloads it,
    and its query suites reference the cpp-queries pack by name: with only the
    driver pack installed, resolving any driver suite fails with

        A fatal error occurred: The QL pack 'microsoft/cpp-queries@0.0.5' which
        is referenced from ..../windows-driver-suites/mustfix.qls cannot be found.

    so both are named here and by -codeqlPacks.

    Note the precedence, which is the opposite of a build parameter json file:
    an explicitly passed parameter wins over this file, because the file
    describes the toolchain on the machine and the command line is an operator
    overriding it for one run.

.PARAMETER jsonFile
    The json file to read. An explicitly named file that does not exist is an
    error.

.PARAMETER projectRootPath
    The project root, searched for codeql.json when -jsonFile is not given, so
    a project can pin its own toolchain.

.PARAMETER htsToolsPath
    The build tools directory, searched for codeql.json when the project has
    none: the versions the tools were tested with.

.EXAMPLE
    $tooling = readCodeQlJson -projectRootPath . -htsToolsPath ../BuildTools
#>
function readCodeQlJson {
    param(
        [string] $jsonFile = $null,
        [string] $projectRootPath = $null,
        [string] $htsToolsPath = $null
    )
    $result = @{
        file    = $null
        version = $null
        home    = $null
        cli     = $null
        packs   = $null
        dvlExe  = $null
    }
    $candidates = @()
    if (-not [string]::IsNullOrEmpty($jsonFile)) {
        if (!(test-path $jsonFile -PathType Leaf)) {
            Write-Error "codeql jsonFile: $jsonFile not found."
            exit 1
        }
        $candidates += $jsonFile
    }
    else {
        if (-not [string]::IsNullOrEmpty($projectRootPath)) {
            $candidates += (Join-Path $projectRootPath "codeql.json")
        }
        if (-not [string]::IsNullOrEmpty($htsToolsPath)) {
            $candidates += (Join-Path $htsToolsPath "codeql.json")
        }
        # last resort: the description that ships with these tools, so the
        # versions the tools were tested with are the default everywhere.
        if ($MyInvocation.MyCommand.Module) {
            $candidates += (Join-Path $MyInvocation.MyCommand.Module.ModuleBase "codeql.json")
        }
    }
    $found = @($candidates | Where-Object { test-path $_ -PathType Leaf } | Select-Object -First 1)
    if (!$found.Count) {
        return $result
    }
    $found = Convert-Path $found[0]
    $json = Get-Content -Raw $found | ConvertFrom-Json
    $result.file = $found
    if ($json.PSObject.Properties.Name -contains 'cli') {
        $cli = $json.cli
        if ($cli.PSObject.Properties.Name -contains 'version') { $result.version = $cli.version }
        if ($cli.PSObject.Properties.Name -contains 'home') { $result.home = $cli.home }
        if ($cli.PSObject.Properties.Name -contains 'path') { $result.cli = $cli.path }
    }
    if ($json.PSObject.Properties.Name -contains 'packs') {
        $result.packs = @($json.packs)
    }
    if ($json.PSObject.Properties.Name -contains 'dvl') {
        if ($json.dvl.PSObject.Properties.Name -contains 'path') { $result.dvlExe = $json.dvl.path }
    }
    log "using CodeQL tooling description: $found"
    $result
}

<#
.SYNOPSIS
    Find dvl.exe, which creates the driver verification log.

.DESCRIPTION
    dvl.exe ships with the WDK, and where it lives depends on how the WDK got
    onto the machine:

      * a WDK installed on the machine (Visual Studio + WDK):
        "%ProgramFiles(x86)%\Windows Kits\10\Tools\dvl\dvl.exe"
      * a WDK restored from nuget, which is what a nuget build uses, and what a
        CI runner has instead of an installed WDK:
        "<root>\packages\Microsoft.Windows.WDK.<arch>.<version>\c\tools\dvl\dvl.exe"

    Both are searched, the nuget packages first: a project that restored the WDK
    package built against that WDK, so its dvl.exe is the one that matches the
    driver being logged, while the machine's installed WDK may be any version
    (measured here: 10.0.22621-era installed, 10.0.28000.2526 in the packages).
    Packages are ranked by architecture match when -architecture is given, then
    newest first.

    Returns the path, or $null when nothing is found; a -dvlExe that was given
    but does not exist is an error, because an explicitly configured path being
    wrong is worth failing on.

.PARAMETER dvlExe
    An explicitly configured dvl.exe, which wins over the search.

.PARAMETER searchRoot
    Project roots to search. "<root>\packages" is tried, then "<root>" itself.

.PARAMETER architecture
    x64, x86, arm or arm64, used to prefer the matching WDK package.

.EXAMPLE
    $dvl = getDvlExe -searchRoot . -architecture x64
#>
function getDvlExe {
    param(
        [string] $dvlExe = $null,
        [string[]] $searchRoot = @(),
        [string] $architecture = $null
    )
    $ErrorActionPreference = 'Stop'
    if (-not [string]::IsNullOrEmpty($dvlExe)) {
        if (!(test-path $dvlExe -PathType Leaf)) {
            Write-Error "dvlExe: '$dvlExe' not found."
            exit 1
        }
        return (Convert-Path $dvlExe)
    }

    # the WDK nuget packages, which is what a nuget build and a CI runner has
    foreach ($root in $searchRoot) {
        if ([string]::IsNullOrEmpty($root)) { continue }
        foreach ($packagesDir in @((Join-Path $root "packages"), $root)) {
            if (!(test-path $packagesDir -PathType Container)) { continue }
            $wdkPackages = @(Get-ChildItem $packagesDir -Directory -Filter "Microsoft.Windows.WDK.*" -ErrorAction SilentlyContinue)
            if (!$wdkPackages.Count) { continue }
            $ranked = @($wdkPackages | Sort-Object -Property @{
                    # the package for the architecture being built comes first
                    Expression = { if ($architecture -and $_.Name -match ('\.' + [regex]::Escape($architecture) + '\.')) { 0 } else { 1 } }
                }, @{
                    Expression = { $_.Name }
                    Descending = $true
                })
            foreach ($package in $ranked) {
                $candidate = Join-Path $package.FullName "c\tools\dvl\dvl.exe"
                if (test-path $candidate -PathType Leaf) {
                    log "using dvl.exe from the WDK nuget package $($package.Name)"
                    return (Convert-Path $candidate)
                }
            }
        }
    }

    # a WDK installed on the machine, or an eWDK that exported its content root
    $installed = "${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe"
    if (test-path $installed -PathType Leaf) {
        log "using the installed WDK's dvl.exe"
        return (Convert-Path $installed)
    }
    $null
}

<#
.SYNOPSIS
    Pick the pack that carries the Windows driver query suites.

.DESCRIPTION
    -codeqlPacks holds every pack the analysis needs, in which the driver pack
    is the one whose suites are run. Named by role rather than by position, so
    that the list can be reordered or extended.

.PARAMETER packs
    The pack list, 'name[@version]' entries.

.EXAMPLE
    getCodeQlDriverPack -packs $codeQl.packs
#>
function getCodeQlDriverPack {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $packs
    )
    $driver = @($packs | Where-Object { $_ -match '^microsoft/windows-drivers' })
    if ($driver.Count) {
        return $driver[0]
    }
    # anything else: the suite has to name its own pack, so say what was assumed
    log "no microsoft/windows-drivers pack in the pack list, using the first entry for suite resolution"
    $packs[0]
}

<#
.SYNOPSIS
    Resolve everything a CodeQL build needs, once, before the build loop.

.DESCRIPTION
    Validates the CodeQL CLI and the query packs (installing them when -install
    is specified), resolves the query suite, prepares the output and database
    directories, and works out which project file and driver name the analysis
    belongs to.

    Each toolchain value is taken from an explicitly passed parameter, else from
    the codeql.json tooling description (see readCodeQlJson), else from the
    built in defaults.

    Returns a hashtable that build.ps1 passes on to doBuild for each
    configuration and platform, through getCodeQlPaths.

.PARAMETER codeqlHome
    The directory holding the CodeQL CLI, e.g. C:\codeql-home. Default
    C:\codeql-home, or $env:CODEQL_HOME.

.PARAMETER codeqlCli
    The path to a specific codeql.cmd to use, overriding -codeqlHome.

.PARAMETER codeqlVersion
    The CodeQL CLI version to install with -install. Default 2.25.5, the oldest
    version validated for the 26H1 driver packs.

.PARAMETER codeqlPacks
    Every query pack the analysis needs, as 'name@version': the driver pack and
    the C/C++ query pack its suites reference. Default the pair released with
    the WHCP_26H1 / main branch, microsoft/windows-drivers@1.10.0 and
    microsoft/cpp-queries@0.0.5.

    Both must be named. The driver pack declares microsoft/cpp-queries as a
    dependency, but the CLI does not resolve a pack's declared dependencies when
    it downloads it, and the driver suites reference the cpp-queries pack by
    name, so a machine with only the driver pack installed fails to resolve any
    driver suite.

.PARAMETER codeqlDvlExe
    The path to dvl.exe for the driver verification log. Default is to search
    the installed WDK.

.PARAMETER jsonFile
    The codeql.json tooling description to read. Default: <projectRootPath>\
    codeql.json if it exists, else <htsToolsPath>\codeql.json.

.PARAMETER htsToolsPath
    The build tools directory, searched for the codeql.json that ships with the
    tools when the project has none.

.PARAMETER codeqlSuite
    A suite name, or the path to a .qls file.

.PARAMETER codeqlOutputDir
    Where the SARIF files and driver verification logs go. Default "$logDir\codeql".

.PARAMETER codeqlDbDir
    Where the databases go. Default "$env:LOCALAPPDATA\hts-codeql", which is
    outside the source tree because a database per configuration and platform is
    several hundred MB of artifact rather than source.

.PARAMETER codeqlProjectFile
    The driver project the analysis belongs to, used for the verification log.
    Default is -projectName when that is a .vcxproj, otherwise the first
    .vcxproj with a sibling .inf or .inx under -projectPath.

.PARAMETER codeqlDriverName
    The driver name for the verification log. Default is the TargetName of the
    resolved project file.

.PARAMETER logDir
    The build log directory, where the CodeQL console output goes.

.PARAMETER projectPath
    The directory holding the msbuild project being built.

.PARAMETER projectName
    The msbuild project file name.

.PARAMETER projectRootPath
    The project root: the CodeQL source root, the checkout root.

.PARAMETER configurations
    The configurations about to be built, used only for a Debug warning.

.PARAMETER install
    Download the CLI and any missing query packs rather than failing.

.EXAMPLE
    $codeQl = initializeCodeQl -codeqlSuite mustrun -logDir ./logs -projectPath . -projectName my.sln
#>
function initializeCodeQl {
    param(
        [string] $codeqlHome = $null,
        [string] $codeqlCli = $null,
        [string] $codeqlVersion = $null,
        [string[]] $codeqlPacks = $null,
        [string] $codeqlDvlExe = $null,
        [string] $jsonFile = $null,
        [string] $htsToolsPath = $null,
        [string] $codeqlSuite = "recommended",
        [string] $codeqlOutputDir = $null,
        [string] $codeqlDbDir = $null,
        [string] $codeqlProjectFile = $null,
        [string] $codeqlDriverName = $null,
        [string] $logDir = ".",
        [string] $projectPath = ".",
        [string] $projectName = $null,
        [string] $projectRootPath = $null,
        [string[]] $configurations = @(),
        [switch] $dvl,
        [switch] $install
    )
    $ErrorActionPreference = 'Stop'
    # each toolchain value: an explicitly passed parameter wins, else the
    # codeql.json description, else the built in default.
    $tooling = readCodeQlJson -jsonFile $jsonFile -projectRootPath $projectRootPath -htsToolsPath $htsToolsPath
    if ([string]::IsNullOrEmpty($codeqlVersion) -and -not [string]::IsNullOrEmpty($tooling.version)) {
        $codeqlVersion = $tooling.version
    }
    if ([string]::IsNullOrEmpty($codeqlHome) -and -not [string]::IsNullOrEmpty($tooling.home)) {
        $codeqlHome = $tooling.home
    }
    if ([string]::IsNullOrEmpty($codeqlCli) -and -not [string]::IsNullOrEmpty($tooling.cli)) {
        $codeqlCli = $tooling.cli
    }
    if ([string]::IsNullOrEmpty($codeqlDvlExe) -and -not [string]::IsNullOrEmpty($tooling.dvlExe)) {
        $codeqlDvlExe = $tooling.dvlExe
    }
    if (!$codeqlPacks -or !$codeqlPacks.Count) {
        if ($tooling.packs -and $tooling.packs.Count) {
            $codeqlPacks = $tooling.packs
        }
        else {
            $codeqlPacks = $script:defaultCodeQlPacks
        }
    }
    if ([string]::IsNullOrEmpty($codeqlVersion)) {
        $codeqlVersion = "2.25.5"
    }

    $cli = getCodeQlCli -codeqlHome $codeqlHome -codeqlCli $codeqlCli -version $codeqlVersion -install:$install
    log "using CodeQL CLI $(getCodeQlVersion -codeqlCli $cli) at $cli"
    log "codeql query packs: $($codeqlPacks -join ', ')"
    getCodeQlPacks -codeqlCli $cli -packs $codeqlPacks -install:$install
    $driverPack = getCodeQlDriverPack -packs $codeqlPacks
    $suite = getCodeQlSuiteSpec -pack $driverPack -suite $codeqlSuite

    if ([string]::IsNullOrEmpty($codeqlOutputDir)) {
        $codeqlOutputDir = "$logDir\codeql"
    }
    if (!(test-path $codeqlOutputDir)) {
        $null = mkdir $codeqlOutputDir
    }
    $output = Convert-Path $codeqlOutputDir

    if ([string]::IsNullOrEmpty($codeqlDbDir)) {
        # outside the source tree: a database per configuration and platform is
        # several hundred MB of artifact, not source.
        $codeqlDbDir = "$env:LOCALAPPDATA\hts-codeql"
    }
    if (!(test-path $codeqlDbDir)) {
        $null = mkdir $codeqlDbDir
    }
    $dbRoot = Convert-Path $codeqlDbDir

    log "codeql databases will be created in $dbRoot"
    log "codeql sarif results and dvls will be written to $output"
    if ($configurations -contains "Debug") {
        log "note: codeql analysis of the Debug configuration is slow, Release is recommended."
    }

    # the driver project, and the driver name, for the verification log
    if ([string]::IsNullOrEmpty($codeqlProjectFile)) {
        if ($projectName -match '\.vcxproj$') {
            $codeqlProjectFile = Join-Path $projectPath $projectName
        }
        else {
            # prefer a project that looks like a driver, ie one with a sibling
            # inf/inx file.
            $candidates = @(Get-ChildItem $projectPath -Recurse -Filter "*.vcxproj" -ErrorAction SilentlyContinue)
            $driverProj = @($candidates | Where-Object {
                    @(Get-ChildItem $_.DirectoryName -Filter "*.inf" -ErrorAction SilentlyContinue).Count -gt 0 -or
                    @(Get-ChildItem $_.DirectoryName -Filter "*.inx" -ErrorAction SilentlyContinue).Count -gt 0
                })
            if ($driverProj.Count) {
                $codeqlProjectFile = $driverProj[0].FullName
            }
            elseif ($candidates.Count) {
                $codeqlProjectFile = $candidates[0].FullName
            }
        }
    }
    if ([string]::IsNullOrEmpty($codeqlDriverName)) {
        if (-not [string]::IsNullOrEmpty($codeqlProjectFile) -and (test-path $codeqlProjectFile)) {
            $codeqlDriverName = [System.IO.Path]::GetFileNameWithoutExtension($codeqlProjectFile)
            $projText = Get-Content -Raw $codeqlProjectFile
            if ($projText -match '<TargetName>\s*([^<\s]+)') {
                $codeqlDriverName = $Matches[1]
            }
        }
        else {
            $codeqlDriverName = [System.IO.Path]::GetFileNameWithoutExtension($projectName)
        }
    }

    # the source root is the checkout root: the primary source files live inside
    # it, everything outside it is treated as a library, which is what the
    # driver query suites expect.
    if ([string]::IsNullOrEmpty($projectRootPath)) {
        $sourceRoot = $projectPath
    }
    else {
        $sourceRoot = $projectRootPath
    }
    log "codeql source root: $sourceRoot, driver project: $codeqlProjectFile, driver name: $codeqlDriverName"

    <#
    The driver verification log needs dvl.exe. Check for it now, rather than
    after a fifteen minute analysis, but resolve it per configuration and
    platform later: the package to use depends on the architecture being built.
    #>
    $dvlSearchRoot = @($projectPath, $projectRootPath) | Where-Object { -not [string]::IsNullOrEmpty($_) }
    $dvlAvailable = getDvlExe -dvlExe $codeqlDvlExe -searchRoot $dvlSearchRoot
    if ([string]::IsNullOrEmpty($dvlAvailable)) {
        if ($dvl) {
            Write-Error ("dvl.exe not found, and -dvl was specified. It ships with the WDK: the " +
                "installed WDK's Tools\dvl, or the project's WDK nuget packages under " +
                "<root>\packages\Microsoft.Windows.WDK.<arch>.<version>\c\tools\dvl. Pass -codeqlDvlExe, " +
                "or set dvl.path in codeql.json.")
            exit 1
        }
        log "dvl.exe not found; -dvl will fail unless a WDK is installed or restored"
    }
    else {
        log "dvl.exe available: $dvlAvailable"
    }

    @{
        cli         = $cli
        version     = $codeqlVersion
        packs       = $codeqlPacks
        driverPack  = $driverPack
        suite       = $suite
        output      = $output
        dbRoot      = $dbRoot
        logDir      = (Convert-Path $logDir)
        dvlExe      = $codeqlDvlExe
        searchRoot  = $dvlSearchRoot
        toolingFile = $tooling.file
        projectFile = $codeqlProjectFile
        driverName  = $codeqlDriverName
        sourceRoot  = $sourceRoot
    }
}

<#
.SYNOPSIS
    Name the CodeQL artifacts for one configuration and platform.

.DESCRIPTION
    The database, SARIF file, driver verification log and console log for a
    single pass of the build loop, so that build.ps1 doesn't assemble paths.

.PARAMETER codeQl
    The hashtable returned by initializeCodeQl.

.PARAMETER config
    The build configuration, e.g. Release.

.PARAMETER platform
    The build platform, e.g. x64.

.EXAMPLE
    $paths = getCodeQlPaths -codeQl $codeQl -config Release -platform x64
    $paths.sarif
#>
function getCodeQlPaths {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $codeQl,
        [Parameter(Mandatory = $true)]
        [string] $config,
        [Parameter(Mandatory = $true)]
        [string] $platform
    )
    $suffix = "$($config)_$($platform.replace(' ', '-'))"
    $name = "$($codeQl.driverName)_$suffix"
    @{
        name     = $name
        database = "$($codeQl.dbRoot)\${name}_db"
        sarif    = "$($codeQl.output)\$name.sarif"
        dvl      = "$($codeQl.output)\$name.DVL.XML"
        log      = "$($codeQl.logDir)\CodeQL_$suffix.log"
    }
}

<#
.SYNOPSIS
    Report a CodeQL analysis, and turn its results into a driver verification log.

.DESCRIPTION
    Summarizes the SARIF file of one configuration and platform: the finding
    count by severity, and the rules with the most findings, then creates the
    driver verification log when -dvl is specified. The full CodeQL narration
    stays in the console log that doBuild wrote.

    Returns the number of findings, or -1 when the analysis produced no SARIF
    file at all, which is a failure of the analysis rather than of the driver
    source. The report itself goes to the host, not to the output stream: the
    caller captures the output stream to get that count, so anything written
    there would be swallowed by the assignment instead of reaching the console.

.PARAMETER codeQl
    The hashtable returned by initializeCodeQl.

.PARAMETER paths
    The hashtable returned by getCodeQlPaths.

.PARAMETER config
    The build configuration, for the report only.

.PARAMETER platform
    The build platform, for the report and the verification log architecture.

.PARAMETER dvl
    Also create the driver verification log.

.PARAMETER failOnResults
    Report that findings should fail the build.

.PARAMETER maxRules
    How many rules to list before deferring to the SARIF file. Default 15.

.EXAMPLE
    $findings = publishCodeQlAnalysis -codeQl $codeQl -paths $paths -config Release -platform x64 -dvl
#>
function publishCodeQlAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $codeQl,
        [Parameter(Mandatory = $true)]
        [hashtable] $paths,
        [string] $config = "",
        [string] $platform = "",
        [switch] $dvl,
        [switch] $failOnResults,
        [int] $maxRules = 15
    )
    $ErrorActionPreference = 'Stop'
    if (!(test-path $paths.sarif -PathType Leaf)) {
        Write-Host " CodeQL $config $platform did not produce $($paths.sarif)"
        return -1
    }
    $results = getSarifResults -sarifFile $paths.sarif
    Write-Host " CodeQL $config $platform results: $($results.total) findings ($($results.error) error, $($results.warning) warning, $($results.note) note)"
    Write-Host " CodeQL sarif: $($paths.sarif)"
    $shown = 0
    foreach ($rule in $results.rules) {
        if ($shown -ge $maxRules) {
            Write-Host "  ... $($results.rules.Count - $shown) more rules, see the sarif file"
            break
        }
        Write-Host "  $rule"
        $shown++
    }
    if ($dvl) {
        $null = newDvl -sarifFile $paths.sarif -driverName $codeQl.driverName `
            -architecture $platform -projectFile $codeQl.projectFile `
            -outputFile $paths.dvl -dvlExe $codeQl.dvlExe -projectSearchRoot $codeQl.searchRoot
        Write-Host " driver verification log: $($paths.dvl)"
    }
    if ($results.total -gt 0 -and $failOnResults) {
        Write-Host " CodeQL reported $($results.total) findings and -codeqlFailOnResults was specified."
    }
    Write-Host " CodeQL console output: $($paths.log)"
    $results.total
}

Export-ModuleMember -Function filterWarnings
Export-ModuleMember -function getCodeQlCli
Export-ModuleMember -function getCodeQlVersion
Export-ModuleMember -function getCodeQlPacks
Export-ModuleMember -function getCodeQlSuiteSpec
Export-ModuleMember -function getSarifResults
Export-ModuleMember -function newDvl
Export-ModuleMember -function initializeCodeQl
Export-ModuleMember -function getCodeQlPaths
Export-ModuleMember -function publishCodeQlAnalysis
Export-ModuleMember -function readCodeQlJson
Export-ModuleMember -function getCodeQlDriverPack
Export-ModuleMember -function getDvlExe
Export-ModuleMember -function Invoke-CmdScript
Export-ModuleMember -function getVsCmdScripts
Export-ModuleMember -function doBuild
Export-ModuleMember -function log
Export-ModuleMember -function buildNumber
Export-ModuleMember -function headSha
Export-ModuleMember -function isGitRepo