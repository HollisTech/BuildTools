# codeql

Run CodeQL static analysis of Windows driver source code as part of the build, and optionally create a driver verification log (DVL) from the results.

```PowerShell
build.ps1 -codeql [-codeqlSuite <String>] [-codeqlPack <String>] [-codeqlHome <String>] [-codeqlCli <String>] [-codeqlVersion <String>] [-codeqlOutputDir <String>] [-codeqlDbDir <String>] [-codeqlJobs <Int32>] [-codeqlProjectFile <String>] [-codeqlDriverName <String>] [-installCodeQL] [-dvl] [-codeqlFailOnResults] [...common build parameters]
```

## Description

The `-codeql` switch makes CodeQL a *build option* rather than a separate
workflow: the same msbuild invocation, on the same toolset, is handed to
`codeql database create` as its build command, so the CodeQL C/C++ extractor
observes the compilation, and the resulting database is then analyzed into a
SARIF file. The build itself is unchanged, and its logs are written exactly as
for a normal build.

Because the extractor only sees compilation that happens while the database is
being created:

- the build target defaults to `Rebuild` when `-codeql` is used (pass `-target`
  explicitly to override),
- `Release` is strongly preferred over `Debug`; a `Debug` analysis is several
  times slower and is only logged as a warning.

Analysis results are informational by default. The Microsoft driver suites
contain checks that can report false positives, and only the *Must-Fix* subset
is graded by WHCP, so findings do not fail the build unless
`-codeqlFailOnResults` is passed.

## Tooling

Three pieces are needed, none of which is part of a Visual Studio or WDK
install. `codeql.ps1` reports on, and can install, all of them:

```PowerShell
.\codeql.ps1              # report what is present, non-zero exit if incomplete
.\codeql.ps1 -install     # download the CLI and any missing query packs
```

| piece | where it comes from | where it goes |
|---|---|---|
| CodeQL CLI | `github/codeql-cli-binaries` release zip | `C:\codeql-home\codeql` (`CODEQL_HOME`, `-codeqlHome`, `-codeqlCli`) |
| driver query pack | `microsoft/windows-drivers@<version>` via `codeql pack download` | `%USERPROFILE%\.codeql\packages` |
| `dvl.exe` | the WDK / eWDK | `C:\Program Files (x86)\Windows Kits\10\Tools\dvl\` |

The CLI version and the query pack version must be a pair from the Microsoft
version matrix, *Select the appropriate CodeQL version for your driver*
(<https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/static-tools-and-codeql>).
The defaults here are the current general-use pair: CodeQL CLI `2.25.5` with
`microsoft/windows-drivers@1.10.0` (the `main` / WHCP_26H1 branch pack).

## Query suites

`-codeqlSuite` takes a suite name or the path to a `.qls` file.

| suite | contents |
|---|---|
| `recommended` | broad set of driver and C/C++ checks. The default. |
| `mustrun` | the checks that must be run to pass WHCP certification. For 26H1 identical to `recommended`. |
| `mustfix` | the subset that must be clean for WHCP certification to pass. |

Named suites are resolved against the driver pack, for example
`microsoft/windows-drivers:windows-driver-suites/mustfix.qls`. Other suites in
the pack (`ported_driver_ca_checks`, `windows_mustfix_partial`,
`windows_recommended_partial`) can be named too.

## Outputs

The SARIF file and the driver verification log land in `-codeqlOutputDir`,
default `$logDir/codeql` (`./logs/codeql` for a default invocation):

- `<driver>_<config>_<platform>.sarif` - the analysis results, the file to
  review and the file the HLK test is built from.
- `<driver>_<config>_<platform>.DVL.XML` - the driver verification log, with
  `-dvl`.

CodeQL's own console output - every step it takes, and every query it
evaluates - goes to `$logDir/CodeQL_<config>_<platform>.log` instead of the
build console, which then shows only the tooling it resolved and the finding
summary. The build prints that path when the analysis starts, so there is
somewhere to watch while it runs, and again in the summary. Read it when an
analysis fails; it holds the command line, the extraction and the per-query
results.

The database lands in `-codeqlDbDir`, default `%LOCALAPPDATA%\hts-codeql`,
which is outside the source tree because a database per configuration and
platform is several hundred MB of artifact rather than source:

- `<driver>_<config>_<platform>_db/` the CodeQL database, needed only to re-run
  queries without rebuilding.

## The msbuild Clean warning, from the second Rebuild on

`-codeql` defaults the target to `Rebuild`, and Rebuild starts with msbuild's
`Clean`. The CodeQL compiler tracer records its own log as a file the build
wrote, so the *next* Rebuild's Clean tries to delete the previous run's
`build-tracer.log` - while the extractor running the current Rebuild holds that
same path open. It fails, once per project:

```
Microsoft.CppClean.targets(77,5): warning : The process cannot access the file
'...\HtsVsp_Release_x64_db\log\build-tracer.log' because it is being used by another process.
```

`build.ps1` fails a build on unexpected warnings, so allow this one in the
project's `allowed-warnings.json` - the supported hook, and the one the logs
already point at:

```json
{
    "allowedWarnings": [
        "Microsoft\\.CppClean\\.targets.*build-tracer\\.log.*being used by another process"
    ]
}
```

It appears once per driver project in the solution, on every Rebuild after the
first CodeQL build. Moving the database does not avoid it, and neither does any
other database path: it is the tracer's own log being traced.

The build output also reports the finding count per configuration and platform,
and the top rules by number of findings.

The SARIF file can be opened with the Microsoft SARIF Viewer for Visual Studio,
the SARIF extension for Visual Studio Code, or the web viewer at
<https://microsoft.github.io/sarif-web-component/>. Results are suppressed in
the usual ways: `#pragma(suppress:<rule id>)` above the violation, or an
`lgtm[<rule id>]` comment, when `microsoft/windows-drivers:windows-driver-suites/...`
is run together with the driver alert suppression query.

## Driver verification log

`-dvl` turns the SARIF results into `<driver>.DVL.XML`, which is what the HLK
Static Tools Logo test parses and what a WHCP submission requires. The DVL is
produced by the `dvl.exe` shipped in `Windows Kits\10\Tools\dvl`, invoked as

```Console
dvl.exe /manualCreate <driverName> <architecture>
```

in a directory holding the SARIF file and a `.vcxproj`. `-codeqlProjectFile`
defaults to the project with a sibling `.inf`/`.inx` file under `-projectPath`,
and `-codeqlDriverName` defaults to that project's `TargetName`.

Note that a DVL built this way contains the CodeQL results only. A complete
WHCP submission may also need the Code Analysis and Static Driver Verifier
results; those are produced by `msbuild /target:dvl` from a developer command
prompt instead.

## Examples

Analyze a driver with the default suite and write a DVL:

```PowerShell
.\build.ps1 -toolset VS2022 -codeql -dvl
```

Check only the checks that must be clean for certification, and fail the build
if any of them report:

```PowerShell
.\build.ps1 -toolset VS2022 -codeql -codeqlSuite mustfix -codeqlFailOnResults
```

Bootstrap a machine that has never run CodeQL, then analyze, keeping everything
on a scratch drive:

```PowerShell
.\codeql.ps1 -install
.\build.ps1 -toolset VS2022 -codeql -codeqlOutputDir D:\codeql\htsVsp\results -codeqlDbDir D:\codeql\htsVsp\databases
```

From a build JSON file, the same options, using the parameter names as keys:

```json
{
    "toolset": "VS2022",
    "codeql": true,
    "codeqlSuite": "recommended",
    "dvl": true
}
```
