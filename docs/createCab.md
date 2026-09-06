# createCab

Creates a CAB file from a list of files. 

## Syntax
```PowerShell
createCab.ps1 [[-name] <String>] [[-path] <String>] [[-files] <String[]>] [-keepFiles] [<CommonParameters>]
```
## Description

This script creates a CAB file using the makecab command.

## Paramaters

### `-name`


The name of the CAB file to create.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | false |


### `-path`


The directory where the CAB file will be created.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-files`


An array of files to include in the CAB file.


| | |
|---|---|
| Type: | String[] |
| ParameterValue: | String[] |
| PipelineInput: | false |
| Position: | 3 |
| Required: | false |


### `-keepFiles`


A switch to keep the temporary files used in the CAB creation process.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


