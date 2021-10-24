param (
    [string[]] $files,
    [string] $configFile = "$($PSScriptRoot)\signing.json",
    [switch] $createJson,
    [switch] $noisy
)
$ErrorActionPreference = 'Stop'
$jsonSchema = 
@"
{
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