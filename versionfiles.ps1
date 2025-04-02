param(
    [string] $verMajor=1,
    [string] $verMinor=0,
    [string] $verRev=0,
    [string] $BuildNumber=0,
    [string] $BuildString,
    [Parameter(Mandatory = $true)]
    [string] $incPath,
    [switch] $generateProps
)
$ErrorActionPreference = 'Stop'
Import-Module -Name "$PSScriptRoot\buildFuncs.psm1"
if ($buildNumber -eq "0") {
    $BuildNumber = buildNumber
    log "Using generated build number $buildNumber"
}
$verBuildString = "#define VER_BUILD_STRING"
if ([string]::IsNullOrEmpty($BuildString)) {
    $BuildString = headSha
    log "build string $BuildString"
}
if (! [string]::IsNullOrEmpty($BuildString)) {
    $verBuildString += " `"-$BuildString`""
}

$contents=@"
#pragma once
//
// Generated file: DO NOT EDIT!
//
// You must explicitly add a '#include "ntverp.h"' to either the '.rc' file or
// the resource.h file.
//
// Each component including this generated file should also define its own 
// component level include file named "version.h" that defines values for
// VER_PRODUCTNAME, VER_LEGALCOPYRIGHT_STR, VER_INTERNALNAME_STR, and VER_INTERNAL_FILEDESCRIPTION_STR
//
// for example:
// #define VER_COMPANYNAME_STR "Hollis Technology Solutions"
// #define VER_LEGALCOPYRIGHT_STR "(C) " VER_COMPANYNAME_STR
// #define VER_PRODUCTNAME "HTS Build Samples"
// #define VER_INTERNAL_FILEDESCRIPTION_STR "echo autosync sample"
// #define VER_INTERNALNAME_STR "echo.sys"
//
// Note that one could separate VER_PRODUCTNAME, VER_COMPANYNAME_STR, and VER_LEGALCOPYRIGHT_STR 
// into their own include file, as those are frequently common across components. 
// Version.h would then only define the component specific values for VER_INTERNAL_FILEDESCRIPTION_STR and
// VER_INTERNALNAME_STR.
//
// Note also that you can define your own values for VER_FILETYPE and VER_FILESUBTYPE if needed. 
// These can be defined in your version.h file.
//
// Buildstring is anything you want to add to the end of VER_PRODUCTNAME_STR, and will be prefixed with a '-'.
// For example if BuildString is 'abcdef' and VER_PRODUCTNAME is 'Foo' and the version numbers
// are '1.0.0.3' VER_PRODUCTNAME_STR will be "Foo 1.0.0.3-abcdef". 
//
// Using the current git sha for HEAD is a typical use for BuildString.
//
#include "version.h"
#include <winver.h>

#define STRINGER(w, x, y, z) #w "." #x "." #y "." #z
#define XSTRINGER(w, x, y, z) STRINGER(w, x, y, z)

#define VER_PRODUCTMAJORVERSION $verMajor
#define VER_PRODUCTMINORVERSION $verMinor
#define VER_PRODUCTBUILD $verRev
#define VER_PRODUCTBUILD_QFE $BuildNumber
#define VER_PACKAGEBUILD_QFE $BuildNumber
$verBuildString

#define VER_PRODUCTVERSION VER_PRODUCTMAJORVERSION,VER_PRODUCTMINORVERSION,VER_PRODUCTBUILD,VER_PRODUCTBUILD_QFE
#define VER_PRODUCTVERSION_STR XSTRINGER(VER_PRODUCTMAJORVERSION,VER_PRODUCTMINORVERSION,VER_PRODUCTBUILD,VER_PRODUCTBUILD_QFE)
#define VER_PRODUCTVERSION_NUMBER (\
    ((VER_PRODUCTMAJORVERSION & 0xf) << 27) + \
    ((VER_PRODUCTMINORVERSION & 0xf) << 23) + \
    ((VER_PRODUCTBUILD & 0xff) << 15) + \
    (VER_PRODUCTBUILD_QFE & 0xffff))

#define VER_FILEVERSION_STR VER_PRODUCTVERSION_STR VER_BUILD_STRING
#define VER_PRODUCTNAME_STR VER_PRODUCTNAME " " VER_PRODUCTVERSION_STR VER_BUILD_STRING



#define VER_FILEFLAGSMASK VS_FFI_FILEFLAGSMASK
#define VER_FILEFLAGS 0
#define VER_FILEOS VOS_NT_WINDOWS32
#define VER_OEM VER_PRODUCTBUILD
#define VER_BUILD VER_PRODUCTBUILD_QFE

#if DBG
#define VER_DEBUG VS_FF_DEBUG
#else
#define VER_DEBUG 0
#endif

#define VER_FILEDESCRIPTION_STR VER_INTERNAL_FILEDESCRIPTION_STR

#define VER_PRERELEASE 0
#ifndef VER_FILETYPE
#define	VER_FILETYPE	  VFT_DRV
#endif
#ifndef VER_FILESUBTYPE
#define VER_FILESUBTYPE VFT2_DRV_INSTALLABLE
#endif

#include "common.ver"
"@

$verprops = @"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
<!-- 
    GENERATED Versions Property File. You should:
        remove this comment block,
        set the version properties appropriately, 
        add and commit this file into your repo. 
    You can leave the next comment block.
-->
<!--
    To change Major.minor.rev edit (and commit) this file.
-->
<PropertyGroup>
	<verMajor>$verMajor</verMajor>
	<verMinor>$verMinor</verMinor>
	<verRev>$verRev</verRev>
</PropertyGroup>
</Project>
"@

$buildNumberProps = @"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
<!-- 
    GENERATED buildnumber Property File. 
    This file should be included in .gitignore to avoid it being checked in.
    It is recreated for each build.
-->
<PropertyGroup>
    <BuildNumber>$BuildNumber</BuildNumber>
</PropertyGroup>
</Project>
"@

log "include file directory is $incpath"
if (!(test-path -path $incPath)) {
    $null = mkdir $incPath 
}
$verpropfile = "$($incPath)\version.props"
$buildpropfile = "$($incPath)\buildnumber.props"
[bool] $createdMutex = $false
[bool] $mutexHeld = $false
$mutexName = ($incPath -replace "\\","-") -replace ":",""
$lock = new-object System.Threading.Mutex($false, $mutexName, [ref] $createdMutex);
try {
    $mutexHeld = $lock.WaitOne()
    if ($generateProps -and !(test-path $verpropfile)) {
        $verprops | Set-Content $verpropfile
    }
    [string] $current = ""
    if (test-path "$($incPath)\ntverp.h") {
        $current = (get-content "$($incPath)\ntverp.h" -raw)
        if ($current.Length) {
            $current = $current.Trim()
        }
    }
    $tempContents = $contents.Trim()
    if (($current.Length -ne $tempContents.Length) -or ($current -cne $tempContents)) {
        log "creating $($incPath)\ntverp.h"
        $contents | set-content "$($incPath)\ntverp.h"
    }
    if (!(test-path $buildpropfile)) {
        log "creating $buildpropfile"
        $buildNumberProps | Set-Content $buildpropfile
    } else {
        log "updating $buildpropfile"
        $buildNumberProps | Set-Content $buildpropfile -Force
    }
    $mutexHeld = $false
    $lock.ReleaseMutex()
}
catch {
}
finally {
    if ($mutexHeld) {
        $lock.ReleaseMutex();
    }
}
$verfile = "$incPath\version.h"
if (!(test-path $verfile)) {
    log "creating $verFile"
    @"
#pragma once
#ifndef VERSION_H
#define VERSION_H
#define VER_COMPANYNAME_STR "Hollis Technology Solutions"
#define VER_LEGALCOPYRIGHT_STR "(C) " VER_COMPANYNAME_STR
#define VER_PRODUCTNAME "HTS Build Samples"
#define VER_INTERNAL_FILEDESCRIPTION_STR VER_PRODUCTNAME
#define VER_INTERNALNAME_STR VER_PRODUCTNAME
#endif
"@ | set-content $verfile 
}


