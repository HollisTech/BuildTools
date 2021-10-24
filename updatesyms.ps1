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

