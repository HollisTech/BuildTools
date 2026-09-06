# signobject

Signs a list of files using signtool.exe and a certificate specified in a json config file. 

## Syntax
```PowerShell
signobject.ps1 [[-files] <String[]>] [[-configFile] <String>] [-createJson] [-noisy] [<CommonParameters>]
```
## Description

This script signs a list of files using signtool.exe and a certificate specified in a json config file. 
The json config file should contain the certificate thumbprint and a list of time servers to use for timestamping.

## Examples


###  Example 1 
```PowerShell
.\signobject.ps1 -files "file1.dll","file2.sys" -configFile "C:\path\to\signing.json"
Signs the specified files using the certificate and time servers specified in the signing.json file.
```













###  Example 2 
```PowerShell
signobject.ps1 -createJson
Creates a sample json config file for signing.
```












## Paramaters

### `-files`


An array of files to sign.


| | |
|---|---|
| Type: | String[] |
| ParameterValue: | String[] |
| PipelineInput: | false |
| Position: | 1 |
| Required: | false |


### `-configFile`


The path to the json config file.


| | |
|---|---|
| Type: | String |
| DefaultValue: | "$($PSScriptRoot)\signing.json" |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-createJson`


Creates a sample json config file.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-noisy`


Displays the output of signtool.exe.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


