<#
.SYNOPSIS
    Update symbol store with binary files
.DESCRIPTION
    This script updates the symbol store with the specified binary files.
.PARAMETER binaryPath
    The path to the binary files to add to the symbol store.
.PARAMETER configFile
    The path to the configuration file.
.PARAMETER symstore
    The path to the symstore executable.
.PARAMETER comment
	A comment to add to the symbol store entry.
.PARAMETER version
	The version of the binary files to add to the symbol store.	
.PARAMETER createJson
	Creates a sample json config file.
.PARAMETER WhatIf
	Displays the command that would be executed without actually executing it.
.PARAMETER v
	Displays the output of symstore.exe.
#>
param(
	[Parameter(Mandatory= $true)]
	[string]$binaryPath,
	[string]$configFile=".\sympath.json",
	[string]$symstore,
	[string]$comment="local builds",
	[string]$version=(Get-Date).ToString("yyyy:MM:DD:HH:MM"),
    [switch]$createJson,
	[switch]$WhatIf=$false,
	[switch]$v=$false
)
$ErrorActionPreference = 'Stop'
$jsonSchema = 
@"
{
	"symServer": "local symbol server uri",
	"product": "product name"
}
"@
if ($createJson) {
    $jsonSchema
} else {
	if (test-path $configFile) {
		$config =  get-content $configFile | ConvertFrom-Json
		if ([string]::IsNullOrEmpty($symstore)) {
			$symstore="$env:WindowsSdkDir\Debuggers\x64\symstore.exe"
		}
		if (test-path $symstore) {
			$commandArgs = "add","/r","/f",$binaryPath,"/s",$config.symServer,"/v",$version,"/t",$config.product,"/c",$comment
			if ($v) {
				$commandArgs += "/o"
			}
			if ($WhatIf) {
				write-host $symstore @commandArgs
			} else {
				& $symstore @commandArgs
			}
			exit $LASTEXITCODE 
		} else {
			log "sysmtore.exe: $($symstore) not found, no symbols are stored."
		}
	} else {
		log "Config: $($configFile) not found, no symbols are stored."
	}
}

