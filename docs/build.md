# build

Build a Visual Studio solution or project using the specified environment. 

## Syntax
```PowerShell
build.ps1 [[-jsonFile] <String>] [[-projectRootPath] <String>] [[-htsToolsPath] <String>] [[-toolset] <String>] [[-projectPath] <String>] [[-projectName] <String>] [[-target] <String>] [[-configurations] <String[]>] [[-platforms] <String[]>] [[-properties] <String[]>] [[-logDir] <String>] [[-consoleLogLevel] <String>] [[-buildNumber] <Int32>] [[-wrapper] <String>] [[-codeqlHome] <String>] [[-codeqlCli] <String>] [[-codeqlVersion] <String>] [[-codeqlPack] <String>] [[-codeqlSuite] <String>] [[-codeqlOutputDir] <String>] [[-codeqlJobs] <Int32>] [[-codeqlProjectFile] <String>] [[-codeqlDriverName] <String>] [-codeql] [-installCodeQL] [-dvl] [-codeqlFailOnResults] [-detailedSummary] [-noNugetRestore] [-help] [<CommonParameters>]
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




###  Example 4 
```PowerShell
.\build.ps1 -toolset "VS2022" -codeql -codeqlSuite recommended -dvl
Rebuilds the project or solution in the current directory, runs the CodeQL
driver "recommended" query suite over it, writes the SARIF results under
./logs/codeql, and creates a driver verification log from them.
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


### `-codeql`



Switch to run CodeQL static analysis of the driver source code as part of the
build. The build is handed to 'codeql database create' as the build command,
so the CodeQL C/C++ extractor observes the compilation, and the resulting
database is then analyzed into a SARIF file under the log directory.

The toolset (and so the compiler) is unchanged: this is a build option, not
a separate build. Because the extractor only sees compilation that happens
while the database is created, the target defaults to Rebuild when this
switch is used, and Release is strongly preferred over Debug.

The CodeQL CLI is looked for in -codeqlCli, then -codeqlHome, then the
CODEQL_HOME environment variable, then C:\codeql-home. Use -installCodeQL to
download the CLI and the driver query packs if they aren't present yet.
See [codeql](codeql.md), and
https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/static-tools-and-codeql.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlHome`



The directory holding the CodeQL CLI, for example C:\codeql-home.
Default is $env:CODEQL_HOME, or C:\codeql-home.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlCli`



The path to a specific codeql.cmd to use, overriding -codeqlHome.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlVersion`



The CodeQL CLI version to download when -installCodeQL is used. Default
2.25.5.


| | |
|---|---|
| Type: | String |
| DefaultValue: | 2.25.5 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlPack`



The driver CodeQL query pack, as 'name@version'. Default
"microsoft/windows-drivers@1.10.0", the pack released with the WHCP_26H1 /
main branch. The version must be one paired with -codeqlVersion in the
Microsoft version matrix.


| | |
|---|---|
| Type: | String |
| DefaultValue: | microsoft/windows-drivers@1.10.0 |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlSuite`



The query suite to run: "recommended" (default), "mustrun", "mustfix", or
the path to a .qls file. mustrun is the suite WHCP certification requires;
mustfix is the subset that must be clean to pass. Because the queries can
produce false positives, failures do not fail the build unless
-codeqlFailOnResults is specified.


| | |
|---|---|
| Type: | String |
| DefaultValue: | recommended |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlOutputDir`



The directory for the CodeQL SARIF files and driver verification logs.
Default "$logDir/codeql".


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlDbDir`



The directory the CodeQL databases are created in. Default
"$env:LOCALAPPDATA/hts-codeql", outside the source tree, because a database
per configuration and platform is several hundred MB and is an artifact
rather than source. Note this does not avoid the msbuild Clean warning below:
the CodeQL compiler tracer records its own build-tracer.log as a build
output, so a later Rebuild's Clean tries to delete that file while the
running extractor holds it open, wherever the database lives. Add

    "Microsoft\\.CppClean\\.targets.*build-tracer\\.log.*being used by another process"

to allowedWarnings in the project's allowed-warnings.json, which is the
supported way to keep a known-benign warning from failing the build.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlJobs`



The number of threads for the CodeQL import and query evaluation, passed to
the CodeQL CLI as -j. Default 0, which uses one thread per core.


| | |
|---|---|
| Type: | Int32 |
| DefaultValue: | 0 |
| ParameterValue: | Int32 |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlProjectFile`



The driver project (.vcxproj) that the analysis belongs to, used when
generating a driver verification log. Default is the project file when
-projectName is a .vcxproj, otherwise the first .vcxproj with a sibling
.inf or .inx file under -projectPath.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlDriverName`



The driver name used in the driver verification log, without the .sys or
.dll extension. Default is the TargetName of -codeqlProjectFile.


| | |
|---|---|
| Type: | String |
| ParameterValue: | String |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-installCodeQL`



Switch to download and install the CodeQL CLI and any missing query packs
instead of failing when they are not present.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-dvl`



Switch to also create a driver verification log (DVL) from the SARIF
results, using the dvl.exe shipped with the WDK/eWDK. The DVL is what the
HLK Static Tools Logo test parses, and is required for WHCP certification.
Only meaningful with -codeql.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
| Required: | false |


### `-codeqlFailOnResults`



Switch to fail the build when CodeQL reports any finding. Without it CodeQL
findings are reported but informational, because the driver query suites
contain checks that can report false positives.


| | |
|---|---|
| Type: | SwitchParameter |
| DefaultValue: | False |
| ParameterValue: | SwitchParameter |
| PipelineInput: | false |
| Position: | named |
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


