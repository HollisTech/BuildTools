
# Build Tools

## Powershell scripts and modules for building Visual Studio based msbuild C/C++ projects, focused on Windows driver projects.

### Basic Usage
1. Add this repo as a submodule to a visual studio driver project. 
1. From powershell optionally add HTS extensions to the project .vxcproj file using [updateProject](docs/updateProject.md).
1. Use [build](docs/build.md) to build the project.

# Scripts

## [build](docs/build.md)
Build a Visual Studio solution or project using the specified environment.

The build can optionally run [CodeQL](docs/codeql.md) static analysis of the
driver source code (`-codeql`), and create a driver verification log from the
results (`-dvl`).

## [codeql](docs/codeql.md)
Install, and report on, the three CodeQL components used for Windows driver
analysis: the CLI, the query packs the driver suites need, and dvl.exe.

[codeql.json](codeql.json) describes those three, so a project pins its
toolchain in one place and otherwise inherits the versions these tools were
tested with.

## [createCab](docs/createCab.md)
Creates a CAB file from a list of files.

## [driverProject](docs/driverProject.md)
Create a driver project from an existing 
sample in a local copy of the github 
repo https://github.com/microsoft/Windows-driver-samples.

## [signobject](docs/signobject.md)
Signs a list of files using signtool.exe and a certificate specified in a json config file.

## [updateProject](docs/updateProject.md)
Add HTS extensions to msbuild project file

## [updatesyms](docs/updatesyms.md)
Update symbol store with binary files

## [versionfiles](docs/versionfiles.md)
Generate version files for the project.

## [wdkEnv](docs/wdkEnv.md)
Sets up the development environment for the Windows Driver Kit (WDK).
