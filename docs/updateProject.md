# updateProject

Add HTS extensions to msbuild project file 

## Syntax
```PowerShell
updateProject.ps1 [-projectFile] <String> [[-classGuid] <String>] [[-className] <String>] [[-providerString] <String>] [[-targetName] <String>] [[-projectRoot] <String>] [-fixSampleInf] [<CommonParameters>]
```
## Description

This script adds the HTS extensions to an msbuild project file. 
It adds the htsCommon.props and htsCommon.targets imports to the project file. 
It also adds a PropertyGroup for ProjectRootPath and HtsToolsDir if they are not already defined in the project file.

## Paramaters

### `-projectFile`


The path to the msbuild project file to update.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | true |


### `-classGuid`


The class guid for the driver. If not specified, the guid in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-className`


The class name for the driver. If not specified, the class name in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 3 |
| Required: | false |


### `-providerString`


The provider string for the driver. If not specified, the provider string in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 4 |
| Required: | false |


### `-targetName`


The target name for the driver. If not specified, the target name in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 5 |
| Required: | false |


### `-projectRoot`


The root directory of the project. If not specified, the root directory of the project file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 6 |
| Required: | false |


### `-fixSampleInf`


If specified, the script will update the sample inf file with the class guid, 
class name, provider string, and target name specified in the parameters.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


