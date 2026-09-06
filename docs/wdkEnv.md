# wdkEnv

Sets up the development environment for the Windows Driver Kit (WDK). 

## Syntax
```PowerShell
wdkEnv.ps1 [[-toolset] <String>] [-noSession] [<CommonParameters>]
```
## Description

This script sets up a powershell session for the development environment 
for the Windows Driver Kit (WDK) by initializing the necessary environment variables and paths.
Supports the same set of toolsets as documented for build.ps1.
Does not support nuget based WDK/SDK builds.

## Paramaters

### `-toolset`


The toolset to use for the development environment.


| | |
|---|---|
| Type: | String |
| DefaultValue: | EWDK |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | false |


### `-noSession`


Specifies whether to create a new PowerShell session.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


