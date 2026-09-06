<#

.SYNOPSIS
    Creates a CAB file from a list of files.

.DESCRIPTION
    This script creates a CAB file using the makecab command.

.PARAMETER name
    The name of the CAB file to create.

.PARAMETER path
    The directory where the CAB file will be created.

.PARAMETER files
    An array of files to include in the CAB file.

.PARAMETER keepFiles
    A switch to keep the temporary files used in the CAB creation process.

#>
param(
    [string] $name,
    [string] $path,
    [string[]] $files,
    [switch] $keepFiles
)
$ErrorActionPreference = 'Stop'
$ret = 0
$pushValue = $null
try {
    if (-Not (test-path $path)) {
        throw "$path not found"
    }
     
    $pushValue = Push-Location $path
    $tempFiles = @(".\setup.inf",".\setup.rpt",".\$($name).ddf")

    $t = @"
.OPTION EXPLICIT     ; Generate errors
.Set CabinetFileCountThreshold=0
.Set FolderFileCountThreshold=0
.Set FolderSizeThreshold=0
.Set MaxCabinetSize=0
.Set MaxDiskFileCount=0
.Set MaxDiskSize=0
.Set CompressionType=MSZIP
.Set Cabinet=on
.Set Compress=on
.Set CabinetNameTemplate=$($name).cab
.Set DiskDirectoryTemplate=$((resolve-path $path).Path)
.Set DestinationDir=Driver
"@
    foreach  ($file in $files) {
        if (-Not (test-path $file)) {
            throw "$file not found"
        }
        $t += "`r`n$((resolve-path $file).Path)"
    }
    $t += "`r`n"
    $t | set-content -path "$path\$($name).ddf" -Force
    if ($verbose) {
        & makecab /f "$path\$($name).ddf" -V3
    } else {
        $null = & makecab /f "$path\$($name).ddf"
    }
    $ret = $LastExitCode

    if (!$keepFiles) {
        $tempFiles | foreach-Object {
            if (Test-Path $_ ) {
                Remove-Item -Path $_ -Force
            }
        }
    }
}
catch {
    "Exception: $($Error[0])"
    $ret = 1
} 
finally {
    if ($pushValue) {
        pop-location
    }
    exit $ret
}
