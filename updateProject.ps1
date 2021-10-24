<#
    Add HTS extensions to msbuild project file
#>
param(
    [Parameter(Mandatory=$true)]    
    [string] $projectFile,
    [string] $classGuid,
    [string] $className,
    [string] $providerString,
    [string] $targetName,
    [string] $projectRoot,
    [switch] $fixSampleInf
)

Function Format-XMLText {
    Param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [xml[]]
        $xmlText
    )
    Process {
        # Use a StringWriter, an XMLWriter and an XMLWriterSettings to format XML
        $stringWriter = New-Object System.IO.StringWriter
        $stringWriterSettings = New-Object System.Xml.XmlWriterSettings
 
        # Turn on indentation
        $stringWriterSettings.Indent = $true
 
        # Turn off XML declaration
        $stringWriterSettings.OmitXmlDeclaration = $true
 
        # Create the XMLWriter from the StringWriter
        $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter,$stringWriterSettings)
 
        # Write the XML using the XMLWriter
        $xmlText.WriteContentTo($xmlWriter)
 
        # Don't forget to flush!
        $xmlWriter.Flush()
        $stringWriter.Flush()
 
        # Output the text
        $stringWriter.ToString()
        # This works in a remote session, when [Console]::Out doesn't
        }
    }

Import-Module -Name "$PSScriptRoot\buildFuncs.psm1" 
# fix up the project file
$hts1 = @"
  <PropertyGroup Condition="'`$(ProjectRootPath)' ==''">
    <ProjectRootPath>`$([MSBuild]::GetDirectoryNameOfFileAbove('`$(MSBuildThisFileDirectory)','BuildTools\build.ps1'))</ProjectRootPath>
  </PropertyGroup>
  <PropertyGroup Condition="'`$(HtsToolsDir)' == ''">
    <HtsToolsDir>`$(ProjectRootPath)/BuildTools</HtsToolsDir>
  </PropertyGroup>
  <Import Project="`$(HtsToolsDir)\htsCommon.props" />  
"@

$hts2 = @"
  <Import Project="`$(HtsToolsDir)\htsCommon.targets" />
"@

log "updating project $projectfile with targetname $targetname"
$txt = get-content $projectFile
$origTarget = $null
$out = @()
foreach ($line in $txt) {
  if ($line -like  "*Microsoft.Cpp.targets*") {
        $out += $hts1
        $out += $line
        $out += $hts2
    } else {        
        $out += $line
    }
}
if ($fixSampleInf) {
    $xml = [xml]$out
    $els = $xml.GetElementsByTagName("TargetName")
    if ($els.Count) {
        $origTarget = $els[0].InnerText
    }
    $els | ForEach-Object { $_.InnerText = $targetName }
    $out = $xml | Format-XMLText     
}

$out | Set-Content $projectFile

if ($origTarget -and ($fixSampleInf)) {
    #  update inx (or inf) files
    $projPath = (get-item $projectFile).DirectoryName
    $infs = Get-ChildItem -File -Path "$projPath\*.in[fx]"    
    log "origTarget $origTarget project path $projPath "
    $infs | foreach-object {
        log "modify inf $($_.FullName) replace $origTarget with $targetName"
        $txt = get-content $_.FullName
        $txt = $txt -replace $origTarget,$targetName
        $txt = $txt -replace "Class=Sample","Class=$className"
        $txt = $txt -replace "{78A1C341-4539-11d3-B88D-00C04FAD5171}",$classGuid
        if ($providerString ) {
            log "replace provideString with $providerString"
            $pattern = '(^ProviderString\s*=\s*)(".*").*$'
            $txt = $txt -replace $pattern, "`$1`"$providerString`""
        }
        $txt | Set-Content $_.FullName
    }
}
  
# generate the version properties
$incPath = "$projectRoot\inc"
if (!(Test-Path -PathType Container $incPath)) {
    log "creating include directory $incPath"
    $null = New-Item -ItemType Directory -Path $incPath
}
& "$PSScriptRoot\versionFiles.ps1" -incPath $incPath -generateProps

# add vscode tasks for building
$vscodedir = "$projectRoot/.vscode"
$tasksFile =  "$vscodedir/tasks.json"
if (!(test-path -PathType Leaf -Path $tasksFile)) {
    log "creating $tasksfile"
    if (!(test-path "$vscodedir")) {
        $null = mkdir $vscodedir
    }
    @'
    {
        "version": "2.0.0",
        "tasks": [
          {
            "label": "build all",
            "type": "shell",
            "command": "${workspaceFolder}/BuildTools/build.ps1 -configuration All -platform ALL",
            "problemMatcher": [
              "$msCompile"
            ],
            "group": {
              "kind": "build",
              "isDefault": false
            }
          },
          {
            "label": "build debug ",
            "type": "shell",
            "command": "${workspaceFolder}/BuildTools/build.ps1  -configuration Debug -platform x64",
            "problemMatcher": [
              "$msCompile"
            ],
            "group": {
              "kind": "build",
              "isDefault": false
            }
          },
          {
            "label": "build release ",
            "type": "shell",
            "command": "${workspaceFolder}/BuildTools/build.ps1  -configuration Release -platform x64",
            "problemMatcher": [
              "$msCompile"
            ],
            "group": {
              "kind": "build",
              "isDefault": true
            }
          }
        ]
      }
'@ | set-content $tasksFile
}