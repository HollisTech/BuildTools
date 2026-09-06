# updatesyms

Update symbol store with binary files 

## Syntax
```PowerShell
updatesyms.ps1 [-binaryPath] <String> [[-configFile] <String>] [[-symstore] <String>] [[-comment] <String>] [[-version] <String>] [-createJson] [-WhatIf] [-v] [<CommonParameters>]
```
## Description

This script updates the symbol store with the specified binary files.

## Paramaters

### `-binaryPath`


The path to the binary files to add to the symbol store.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | true |


### `-configFile`


The path to the configuration file.


| | |
|---|---|
| Type: | String |
| DefaultValue: | .\sympath.json |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-symstore`


The path to the symstore executable.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 3 |
| Required: | false |


### `-comment`


A comment to add to the symbol store entry.


| | |
|---|---|
| Type: | String |
| DefaultValue: | local builds |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 4 |
| Required: | false |


### `-version`


The version of the binary files to add to the symbol store.


| | |
|---|---|
| Type: | String |
| DefaultValue: | (Get-Date).ToString("yyyy:MM:DD:HH:MM") |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 5 |
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


### `-WhatIf`


Displays the command that would be executed without actually executing it.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-v`


Displays the output of symstore.exe.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


