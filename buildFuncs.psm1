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
    $commits = git rev-list --count HEAD ^$branch
    
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
            log "branch: $curBranch in repo $repoPath has modified uncommitted files, using build number 0"
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
        [string[]]$cmdCommon,
        [string]$log,
        [string]$errlog,
        [string]$warnlog,
        [string]$projectPath,
        [string]$buildMod
    )

    $cmd = $cmdCommon + @(
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
            log "$($using:msBuild) $msargs"
            & $using:msBuild @msargs
            $ecode = $LASTEXITCODE
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
    (Receive-Job -Job $Job) -split "`n"  
}

function ObjectProperty {
    param(
        [PSCustomObject] $obj,
        [string] $key
    )
    $val = $null
    if ($obj.Properties.Name -contains $key) {
        $val = $obj.$key
    }
    $val
}
Export-ModuleMember -Function filterWarnings
Export-ModuleMember -function Invoke-CmdScript
Export-ModuleMember -function getVsCmdScripts
Export-ModuleMember -function doBuild
Export-ModuleMember -function log
Export-ModuleMember -function buildNumber
Export-ModuleMember -function headSha
Export-ModuleMember -function isGitRepo
Export-ModuleMember -function ObjectProperty