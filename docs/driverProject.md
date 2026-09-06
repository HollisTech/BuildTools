# driverProject

Create a driver project from an existing 
sample in a local copy of the github 
repo https://github.com/microsoft/Windows-driver-samples. 

## Syntax
```PowerShell
driverProject.ps1 [-outputJson] [-projectRoot <String>] [-classGuid <String>] [-className <String>] [-providerString <String>] [-JsonFile <String>] [<CommonParameters>]

driverProject.ps1 -sourcePath <String> -targetPath <String> -targetName <String> [-projectRoot <String>] [-classGuid <String>] [-className <String>] [-providerString <String>] [-JsonFile <String>] [<CommonParameters>]
```
## Paramaters

### `-outputJson`


Outputs a json schema for the parameters to this script.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-sourcePath`


The path to the sample project to copy.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | true |


### `-targetPath`


The path to the directory where the new project will be created.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | true |


### `-targetName`


The name of the new project.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | true |


### `-projectRoot`


The root directory of the project. Defaults to the targetPath.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-classGuid`


The class guid for the driver. If not specified, the guid in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-className`


The class name for the driver. If not specified, the class name in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-providerString`


The provider string for the driver. If not specified, the provider string in the sample inf file will be used.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-JsonFile`


A json file containing the parameters for this script. If specified, the parameters in the json file will be used instead of the command line parameters.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


