# build

Build a Visual Studio solution or project using the specified environment. 

## Syntax
```PowerShell
build.ps1 [[-jsonFile] <String>] [[-projectRootPath] <String>] [[-htsToolsPath] <String>] [[-toolset] <String>] [[-projectPath] <String>] [[-projectName] <String>] [[-target] <String>] [[-configurations] <String[]>] [[-platforms] <String[]>] [[-properties] <String[]>] [[-logDir] <String>] [[-consoleLogLevel] <String>] [[-buildNumber] <Int32>] [[-wrapper] <String>] [-detailedSummary] [-noNugetRestore] [-help] [<CommonParameters>]
```
## Description

This script automates the process of building Visual Studio solutions or projects.
It supports multiple Visual Studio versions, build configurations, and platforms.
The script can also read parameters from a JSON file. All build output is logged.

## Examples


###  Example 1 
```PowerShell
.\build.ps1 
Builds the project or solution located in the current directory using the default toolset (EWDK), 
with the "Release" configuration and "x64" platform.
```













###  Example 2 
```PowerShell
.\build.ps1 -toolset "VS2022" 
Builds the project or solution located in the current directory using Visual Studio 2022, 
with the "Release" configuration and "x64" platform.
```













###  Example 3 
```PowerShell
.\build.ps1 -jsonFile "buildParams.json"
Builds the project using parameters specified in the "buildParams.json" file.
The json file format expected is a simple key-value pair structure. 
The keys should match the parameter names of this script.
```












## Paramaters

### `-jsonFile`


Path to a JSON file containing parameter values. If provided, the script will
use the values from the JSON file to override default or explicitly set parameters.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 1 |
| Required: | false |


### `-projectRootPath`


The root directory of the project. This is used to determine the location of
build tools and logs if not explicitly specified.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 2 |
| Required: | false |


### `-htsToolsPath`


The path to the build tools directory. If not specified, it defaults to 
"$projectRootPath/BuildTools".


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 3 |
| Required: | false |


### `-toolset`


Specifies the Visual Studio toolset to use for the build. Valid options are:
"EWDK", "VS2026" "VS2022", "VS2019", "VS2017", "VS2015". Default is "EWDK".


| | |
|---|---|
| Type: | String |
| DefaultValue: | EWDK |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 4 |
| Required: | false |


### `-projectPath`


The directory where the MSBuild project file to be built is located. Defaults to the current directory.


| | |
|---|---|
| Type: | String |
| DefaultValue: | . |
| ParameterValue: | String |
| PipelineInput: | true (ByValue) |
| Position: | 5 |
| Required: | false |


### `-projectName`


The name of the MSBuild project file to be built. If not specified, the script
will attempt to find the first MSBuild-compatible project file in the projectPath.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 6 |
| Required: | false |


### `-target`


The build target to execute. Default is "Build".


| | |
|---|---|
| Type: | String |
| DefaultValue: | Build |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 7 |
| Required: | false |


### `-configurations`


An array of build configurations to be built (e.g., "Release", "Debug"). 
Default is "Release". Use "all" to build both "Release" and "Debug".


| | |
|---|---|
| Type: | String[] |
| DefaultValue: | Release |
| ParameterValue: | String[] |
| PipelineInput: | false |
| Position: | 8 |
| Required: | false |


### `-platforms`


An array of build platforms to be built (e.g., "x64", "x86"). Default is "x64".
Use "all" to build for all supported platforms.


| | |
|---|---|
| Type: | String[] |
| DefaultValue: | x64 |
| ParameterValue: | String[] |
| PipelineInput: | false |
| Position: | 9 |
| Required: | false |


### `-properties`


An array of arbitrary build properties in the format "name=value" to be passed to MSBuild.


| | |
|---|---|
| Type: | String[] |
| DefaultValue: | @() |
| ParameterValue: | String[] |
| PipelineInput: | false |
| Position: | 10 |
| Required: | false |


### `-logDir`


The directory path where build log files will be stored. If not specified, it defaults to
"$projectRootPath/logs" or "./logs" if projectRootPath is not set.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 11 |
| Required: | false |


### `-consoleLogLevel`


Specifies the verbosity of the console log output from MSBuild. Valid options are:
"Quiet", "Normal", "Verbose". Default is "Quiet".


| | |
|---|---|
| Type: | String |
| DefaultValue: | Quiet |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 12 |
| Required: | false |


### `-buildNumber`


The build number for this build. This is passed as an MSBuild property named 'BuildNumber'.
Default is 0.


| | |
|---|---|
| Type: | Int32 |
| DefaultValue: | -1 |
| ParameterValue: | Int32 |
| PipelineInput: | false |
| Position: | 13 |
| Required: | false |


### `-wrapper`


A wrapper command or script to be used. The wrapper will be passed the MSBuild command line.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | 14 |
| Required: | false |


### `-detailedSummary`


Switch to generate a detailed summary of the MSBuild process.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-noNugetRestore`


Switch to skip the NuGet package restore step. 
If not specified, NuGet packages will be restored if a packages.config file is found in the projectPath.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-help`


Switch to display detailed help for this script.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


