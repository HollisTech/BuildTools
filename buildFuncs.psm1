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
        $projectPath)
    $regex = $null
    # customize the allowed warnings here
    # the general pattern for c++ warnings is ':\bwarning [A-Z]+([0-9]{4}):'
    # note you need to escape '\b' in the json file as '\\b'
    $jsonFile = $projectPath + "/allowed-warnings.json"
    if (test-path $jsonFile) {
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

    $log,$errlog,$warnlog | foreach-object {    
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
                log "codeql database create `"$db`" --language=cpp --source-root `"$($using:sourceRoot)`" --command `"$buildCommand`""
                & $using:codeQlCmd database create $db --language=cpp "--source-root=$($using:sourceRoot)" "--command=$buildCommand" -j $using:codeQlJobs
                $ecode = $LASTEXITCODE
                if ($ecode -eq 0) {
                    log "codeql database analyze `"$db`" `"$($using:codeQlSuite)`" --format=sarifv2.1.0 --output `"$($using:codeQlSarif)`""
                    & $using:codeQlCmd database analyze $db "$($using:codeQlSuite)" --format=sarifv2.1.0 "--output=$($using:codeQlSarif)" -j $using:codeQlJobs --rerun
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
    that replay is a terminating error, so a merely chatty tool (codeql prints
    "Initializing database at ..." to stderr) aborts the build even though its
    exit code is zero. Collect those records and re-emit them as ordinary
    output; the exit code is what decides success.
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
        [string] $dvlExe = $null
    )
    $ErrorActionPreference = 'Stop'
    if (!(test-path $sarifFile -PathType Leaf)) {
        Write-Error "sarifFile: '$sarifFile' not found."
        exit 1
    }
    if ([string]::IsNullOrEmpty($dvlExe)) {
        # dvl.exe ships with the WDK / eWDK
        $candidates = @()
        if ($env:WDKContentRoot) {
            $candidates += "$($env:WDKContentRoot)Tools\dvl\dvl.exe"
        }
        $candidates += @("${env:ProgramFiles(x86)}\Windows Kits\10\Tools\dvl\dvl.exe")
        foreach ($candidate in $candidates) {
            if (test-path $candidate -PathType Leaf) {
                $dvlExe = $candidate
                break
            }
        }
    }
    if ([string]::IsNullOrEmpty($dvlExe) -or !(test-path $dvlExe -PathType Leaf)) {
        Write-Error "dvl.exe not found. Install the WDK, mount an eWDK, or pass -dvlExe."
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

Export-ModuleMember -Function filterWarnings
Export-ModuleMember -function getCodeQlCli
Export-ModuleMember -function getCodeQlVersion
Export-ModuleMember -function getCodeQlPacks
Export-ModuleMember -function getCodeQlSuiteSpec
Export-ModuleMember -function getSarifResults
Export-ModuleMember -function newDvl
Export-ModuleMember -function Invoke-CmdScript
Export-ModuleMember -function getVsCmdScripts
Export-ModuleMember -function doBuild
Export-ModuleMember -function log
Export-ModuleMember -function buildNumber
Export-ModuleMember -function headSha
Export-ModuleMember -function isGitRepo