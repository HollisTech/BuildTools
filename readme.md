
# NAME
    C:\Users\markr\Documents\docker\echo\BuildTools\build.ps1
## SYNTAX
```powershell
C:\Users\markr\Documents\docker\echo\BuildTools\build.ps1 [[-toolset] <String>] [[-projectPath] <String>] [[-projectName] <String>] [[-target] <String>] [[-configurations] <String[]>] [[-platforms] <String[]>] [[-properties] <String[]>] [[-logDir] <String>] [[-consoleLogLevel] <String>] [[-buildNumber] <Int32>] [[-wrapper] <String>] [-detailedSummary] [-help] [<CommonParameters>]
```
## DESCRIPTION
Build a visual studio solution or project using the correct environment.
## PARAMETERS
### -toolset &lt;String&gt;
Which visual studio tools to use. 
Specify one of "EWDK","VS2022","VS2019","VS2017","VS2015".
Default EWDK.
```
Required?                    false
Position?                    1
Default value                EWDK
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -projectPath &lt;String&gt;
the directory where the msbuild project file to be built is located
```
Required?                    false
Position?                    2
Default value                .
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -projectName &lt;String&gt;
the name of the msbuild project file to be built
```
Required?                    false
Position?                    3
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -target &lt;String&gt;
the build target
```
Required?                    false
Position?                    4
Default value                Build
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -configurations &lt;String[]&gt;
an array of build configurations to be built.
```
Required?                    false
Position?                    5
Default value                Release
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -platforms &lt;String[]&gt;
an array of build platforms to be built
```
Required?                    false
Position?                    6
Default value                x64
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -properties &lt;String[]&gt;
an array of arbitrary build property (name=value) strings that should be passed to the build
```
Required?                    false
Position?                    7
Default value                @()
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -logDir &lt;String&gt;
the directory path for build log files
```
Required?                    false
Position?                    8
Default value                .\logs
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -consoleLogLevel &lt;String&gt;
Verbosity of the console log from msbuild, one of "Quiet","Normal","Verbose".
Default: "Quiet".
```
Required?                    false
Position?                    9
Default value                Quiet
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -buildNumber &lt;Int32&gt;
the build number for this build, set as a msbuild property named 'buildNumber'.
```
Required?                    false
Position?                    10
Default value                0
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -wrapper &lt;String&gt;
a wrapper command or script, it will be passed the msbuild command line.
```
Required?                    false
Position?                    11
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -detailedSummary &lt;SwitchParameter&gt;
generate an msbuild detailed summary
```
Required?                    false
Position?                    named
Default value                False
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -help &lt;SwitchParameter&gt;
invoke help for this script.
```
Required?                    false
Position?                    named
Default value                False
Accept pipeline input?       false
Accept wildcard characters?  false
```

## INPUTS


## OUTPUTS

## NOTES
Powershell 7 is assumed. These scripts may or may not work correctly with earlier versions of powershell.


## EXAMPLES
