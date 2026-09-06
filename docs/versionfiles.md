# versionfiles

Generate version files for the project. 

## Syntax
```PowerShell
versionfiles.ps1 [[-verMajor] <String>] [[-verMinor] <String>] [[-verRev] <String>] [[-BuildNumber] <String>] [[-BuildString] <String>] [-incPath] <String> [-generateProps] [<CommonParameters>]
```
## Description

This script generates the version files for the project, including the version.props and buildnumber.props files.

## Paramaters

### `-verMajor`


The major version number.


| | |
|---|---|
| Type: | String |
| DefaultValue: | 1 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | false |


### `-verMinor`


The minor version number.


| | |
|---|---|
| Type: | String |
| DefaultValue: | 0 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-verRev`


The revision version number.


| | |
|---|---|
| Type: | String |
| DefaultValue: | 0 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 3 |
| Required: | false |


### `-BuildNumber`


The build number.


| | |
|---|---|
| Type: | String |
| DefaultValue: | 0 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 4 |
| Required: | false |


### `-BuildString`


The build string. Uses the current git sha for HEAD if not specified.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 5 |
| Required: | false |


### `-incPath`


The path to the include files where the version files will be generated.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 6 |
| Required: | true |


### `-generateProps`


Whether to generate the property files.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


