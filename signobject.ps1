<#
.SYNOPSIS
    Signs a list of files using signtool.exe and a certificate specified in a json config file.
.DESCRIPTION
    This script signs a list of files using signtool.exe and a certificate specified in a json config file. 
    The json config file should contain the certificate thumbprint and a list of time servers to use for timestamping.
.PARAMETER files
An array of files to sign.
.PARAMETER configFile
The path to the json config file.
.PARAMETER createJson
Creates a sample json config file.
.PARAMETER noisy
Displays the output of signtool.exe.

.EXAMPLE
    .\signobject.ps1 -files "file1.dll","file2.sys" -configFile "C:\path\to\signing.json"
    Signs the specified files using the certificate and time servers specified in the signing.json file.
.EXAMPLE
    signobject.ps1 -createJson
    Creates a sample json config file for signing.
#>
param (
    [string[]] $files,
    [string] $configFile = "$($PSScriptRoot)\signing.json",
    [switch] $createJson,
    [switch] $noisy
)
$ErrorActionPreference = 'Stop'
$jsonSchema = 
@"
    "certThumbPrint": "cert thumbprint",
    "timeservers": [
        "ts-url1",
        "ts-url2"
    ]
}
"@
if ($createJson) {
    $jsonSchema
} else {
    $signtool = Get-Command -Name 'signtool.exe'
    $config = get-content $configFile | ConvertFrom-Json
    $script:signed = $false
    # $fileList = $files -join " "
    foreach ($ts in $config.timeservers) {
        $spew = & $signtool sign /sha1 "$($config.certThumbPrint)" /fd sha256 /tr "$ts" /td sha256 /v @files
        if ($LASTEXITCODE -eq 0 ) {
            $script:signed = $true
            break;
        }
    }
    if ($noisy) {
        Write-Host $spew
    }
    $script:signed
}