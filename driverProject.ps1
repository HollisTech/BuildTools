<#
.SYNOPSIS
    Create a driver project from an existing 
    sample in a local copy of the github 
    repo https://github.com/microsoft/Windows-driver-samples.
.PARAMETER outputJson
    Outputs a json schema for the parameters to this script.
.PARAMETER sourcePath
    The path to the sample project to copy.
.PARAMETER targetPath
    The path to the directory where the new project will be created.
.PARAMETER targetName
    The name of the new project.
.PARAMETER projectRoot
    The root directory of the project. Defaults to the targetPath.
.PARAMETER classGuid
    The class guid for the driver. If not specified, the guid in the sample inf file will be used.
.PARAMETER className
    The class name for the driver. If not specified, the class name in the sample inf file will be used.
.PARAMETER providerString
    The provider string for the driver. If not specified, the provider string in the sample inf file will be used.  
.PARAMETER JsonFile
    A json file containing the parameters for this script. If specified, the parameters in the json file will be used instead of the command line parameters.    
.NOTES
    the JSON schema output file makes the parameters for this script clearer.
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName="json-schema")]
    [switch] $outputJson,

    [Parameter(Mandatory,
    ParameterSetName="standard")]
    [string] $sourcePath,

    [Parameter(Mandatory,
    ParameterSetName="standard")]
    [string] $targetPath,
    
    [Parameter(Mandatory,
    ParameterSetName="standard")]
    [string] $targetName,

    [string] $projectRoot = $null,
    [string] $classGuid = $null,
    [string] $className = $null,
    [string] $providerString = $null,
    [string] $JsonFile = $null)
    
if ($PSCmdlet.ParameterSetName -eq 'json-schema') {
    if ($outputJson) {
@"
    {
        "classGuid" : "{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}",
        "className" : "aaaaaaaa",
        "providerString" : "company name",
        "createGitRepo" : true,
        "importBuildTools" : true,
        "projectInit" : true,
        "fixSampleInf" : true
    }
"@
    }
}
else {
    Import-Module -Name "$PSScriptRoot\buildFuncs.psm1" -Force 
    
    $importBuildTools = $true
    $createGitRepo = $true
    $projectInit = $true
    $fixSampleInf = $true

    if ($jsonFile -and (test-path($JsonFile))) { 
        log "getting config from $JsonFile"       
        $json = Get-Content $jsonFile | ConvertFrom-Json
        if (!$classGuid) {
            if ( "classGuid" -in $json.PSobject.Properties.Name) {
                $classGuid = $json.classGuid
            }
        }
        if (!$className) {
            if ( "className" -in $json.PSobject.Properties.Name) {
                $className = $json.className
            }
        }
        if (!$providerString) {
            if ( "providerString" -in $json.PSobject.Properties.Name) {
                $providerString = $json.providerString
            }
        }
        if ( "createGitRepo" -in $json.PSobject.Properties.Name) {
            $createGitRepo = $json.createGitRepo
        }
        if ( "importBuildTools" -in $json.PSobject.Properties.Name) {
            $importBuildTools = $json.importBuildTools
        } 
        if ( "projectInit" -in $json.PSobject.Properties.Name) {
            $projectInit = $json.projectInit
        } 
        if ( "fixSampleInf" -in $json.PSobject.Properties.Name) {
            $fixSampleInf = $json.fixSampleInf
        }
    }
    $createdTarget = $false
    try {
        if (!$projectRoot) {
            $projectRoot = $targetPath
        }
        if (!(test-path -Path $targetPath -PathType Container -ErrorAction SilentlyContinue)) {
            log "creating directory $targetPath"
            $null = new-item -ItemType Directory -force -Path $targetPath
            $createdTarget = $true
        }
        $targetPath = $targetPath | Resolve-Path        
        $projectRoot = $projectRoot  | Resolve-Path 
        log "targetPath: $targetPath projectRoot: $projectRoot"
        if ($targetPath -ne $projectRoot) {
            $t = Get-ChildItem -Path $projectRoot -Recurse -Directory 
            if (! $t) {
                log "targetPath: $targetPath must be a child directory of projectRoot $projectRoot"
                throw "bad path"
            }
        }
        Get-ChildItem -Path $sourcePath | Copy-Item -Destination $targetPath -Recurse 
    }
    catch {
        log "exception: $_.Exception"
        if ($createdTarget) {
            remove-item -Path $targetPath -Force
        }
        exit 
    }

    Push-Location $projectRoot
    if ($createGitRepo) {
        if (isGitRepo) {
            log "$projectRoot is an existing git repo, not initiailizing."

        } else {
            log "init git repo"
            git init --initial-branch main > $null
            @"
/bin
/logs
inc/ntverp.h
x64/
.vs/
*.user
.vscode/
*.aps
"@ | Set-Content ".\.gitignore" 
        }

        git add -A
        git commit -m "Initial commit of $targetName after copy from MSFT samples."  -q

        $modified = $false
        if ($importBuildTools) {
            $s = & git submodule status 2> $null | select-string -Pattern 'BuildTools'
            if ($null -eq $s) {
                log "add BuildTools submodule"
                $null = git submodule add "https://github.com/HollisTech/BuildTools.git" 2>&1
                $modified = $true
            } else {
                log "Buildtools already added as submodule."
            }
        }
        if ($projectInit) {
            log "update project files"
            $updateParms = @{
                classGuid   = $classGuid
                className   = $className
                providerString = $providerString
                projectRoot = $projectRoot
                fixSampleInf = $fixSampleInf
            }
            $suffix = ""
            $count = 0
            $projs = Get-ChildItem -File -Path $targetPath -Filter "*.vcxproj" -Recurse 
            log "found $($projs.Count) vcxproj files"
            $projs | ForEach-Object {
                $vc = $($_.FullName)
                log "update $vc"
                & "$PSScriptRoot\updateProject.ps1" -projectFile $vc -targetName "$targetName$suffix" @updateParms
                $count++
                $suffix = "-$count"
            }
            if ($count -gt 0) {                
                $modified = $true
            }

        }
        if ($modified) {
            log "commit results"
            git add -A
            git commit -m "Hollistech modifications for building"  -q
        }

    }
    Pop-Location
}