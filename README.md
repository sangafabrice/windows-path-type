# **The WindowsPath Type** 
![Module Version](https://img.shields.io/badge/version-0.0.2-teal) ![Test Coverage](https://img.shields.io/badge/coverage-100%25-teal)
[![CD of WindowsPath](https://github.com/sangafabrice/windows-path-type/actions/workflows/publish-module.yaml/badge.svg)](https://github.com/sangafabrice/windows-path-type/actions/workflows/publish-module.yaml)

Author: Fabrice Sanga

The `WindowsPath` type performs operations on string instances that contain valid Windows File System path information. The specified path or file name string may point to a nonexistent file system object that is nonetheless valid and may carry information about locally or network shared files and directories.

The module also provides two validation attributes `ValidateWindowsPath` and `ValidateWindowsFileName`.

The most probable use case is to ensure that file name and path strings are validated before being used in a method or property. This can be useful for instance when validation of the file system object occurs before its creation.

<img src="https://gistcdn.githack.com/sangafabrice/a8c75d6031a491c0907d5ca5eb5587e0/raw/406120be7a900c3998e33d7302772827f20539f0/automation.svg" alt="Custom Powershell Module Icon" width="3%"> [![Downloads](https://img.shields.io/powershellgallery/dt/WindowsPath?color=blue&label=PSGallery%20%E2%AC%87%EF%B8%8F)](https://www.powershellgallery.com/packages/WindowsPath)
<br>

## Constructor

|||
|:---|---|
|[WindowsPath(String)]()|Initializes a new instance of the WindowsPath class on the specified path string.|

## Property

|||
|-|-|
|[Path]()|Represents the validated fully qualified path string.|

## Method

|||
|-|-|
|[GetFullPath(String)]()|Class method that returns the and absolute and simplified version of the specified path string when it is valid by removing unnecessary characters. Otherwise, it returns a null-value.| 

## Use cases

### Example 1:

The `PSProvider` is a shortcut to a subdirectory in the file system hierarchy, such as `Temp` that expands to the `$Env:TEMP` folder path.

```powershell
PS> using module WindowsPath
PS> Get-PSProvider FileSystem | Select-Object -ExpandProperty Drives | Where-Object Name -iLike ??* | Select-Object Name,Root

Name Root                                  CurrentLocation
---- ----                                  ---------------
Temp C:\Users\username\AppData\Local\Temp\ NewFolder\NewA\NewB

PS> [WindowsPath] "Temp:\sub\e1f8a7c2.tmp"

Path
----
C:\Users\username\AppData\Local\Temp\sub\e1f8a7c2.tmp

PS> [WindowsPath] "Temp:sub\e1f8a7c2.tmp"

Path
----
C:\Users\username\AppData\Local\Temp\NewFolder\NewA\NewB\sub\e1f8a7c2.tmp

PS> Set-Location Temp:
PS> $PWD.Path
Temp:\NewFolder\NewA\NewB
PS> [WindowsPath] "\sub\e1f8a7c2.tmp"

Path
----
C:\Users\username\AppData\Local\Temp\sub\e1f8a7c2.tmp

PS> [WindowsPath] "sub\e1f8a7c2.tmp"

Path
----
C:\Users\username\AppData\Local\Temp\NewFolder\NewA\NewB\sub\e1f8a7c2.tmp

PS> Get-Item @('Temp:\sub\e1f8a7c23.tmp','Temp:\NewFolder\NewA\NewB\sub\e1f8a7c2.tmp')
Get-Item: Cannot find path 'Temp:\sub\e1f8a7c23.tmp' because it does not exist.
Get-Item: Cannot find path 'Temp:\NewFolder\NewA\NewB\sub\e1f8a7c2.tmp' because it does not exist.
```

### Example 2:

The file system provider or drive does not exist.

```powershell
PS> using module WindowsPath
PS> @(Get-PsProvider FileSystem | Select-Object -ExpandProperty Drives | Where-Object Name -IEQ A).Count
0
PS> Test-Path "B:sub\e1f8a7c2.tmp" -IsValid
False
PS> [WindowsPath]::new("B:sub\e1f8a7c2.tmp")
Exception: The string "B:sub\e1f8a7c2.tmp" is not a valid Windows path string.
PS> [WindowsPath]::new("B:\sub\e1f8a7c2.tmp")
Exception: The string "B:\sub\e1f8a7c2.tmp" is not a valid Windows path string.
```

### Example 3:

The `PSProvider` is a network share. The IPv4 address of the server of the share is `192.168.0.5` and its is `nwshare`.

```powershell
PS> using module WindowsPath
PS> Get-SmbShare | Where-Object Name -INotLike '*$' | Select-Object Name,Path

Name Path
---- ----
test C:\Batch\testdir

PS> [WindowsPath] "\\$Env:COMPUTERNAME\test\sub\e1f8a7c2.tmp"

Path
----
\\nwshare\test\sub\e1f8a7c2.tmp

PS> [WindowsPath] "\\192.168.0.5\test\sub\e1f8a7c2.tmp"

Path
----
\\192.168.0.5\test\sub\e1f8a7c2.tmp

PS> Set-Location '\\nwshare\test\dist'
PS> $PWD.Path
Microsoft.PowerShell.Core\FileSystem::\\nwshare\test\dist
PS> [WindowsPath] "\sub\e1f8a7c2.tmp"

Path
----
\\nwshare\test\sub\e1f8a7c2.tmp
```

Note that IPv6 is also supported.

### Example 4:

The network does not exist.

```powershell
PS> using module WindowsPath
PS> Test-Path "\\server\test\"
False
PS> Test-Path "\\192.168.0.10\test\"
False
PS> Test-Path "\\nwshare\xtest\"
False
PS> $PWD.Path
C:\Batch\testdir
Name Path
---- ----
test C:\Batch\testdir

PS> [WindowsPath] "\\server\test\sub\e1f8a7c2.tmp"

Path
----
C:\server\test\sub\e1f8a7c2.tmp

PS> [WindowsPath] "\\192.168.0.10\test\sub\e1f8a7c2.tmp"

Path
----
C:\192.168.0.10\test\sub\e1f8a7c2.tmp

PS> [WindowsPath] "\\nwshare\xtest\sub\e1f8a7c2.tmp"

Path
----
C:\nwshare\xtest\sub\e1f8a7c2.tmp
```

### Example 5:

The path contains invalid characters.

```powershell
PS> using module WindowsPath
PS> [WindowsPath]::new("C:\Batch\test\sub\e1f8a7c2.tmp")

Path
----
C:\Batch\test\sub\e1f8a7c2.tmp

PS> # There is a whitespace at the end of a path segment (sub).
PS> [WindowsPath]::new("C:\Batch\test\sub  \e1f8a7c2.tmp")
Exception: The string "C:\Batch\test\sub  \e1f8a7c2.tmp" is not a valid Windows path string.
PS> # The file path string has a wildcard character.
PS> [WindowsPath]::new("C:\Batch\test\sub\e1f8a7c2?.tmp")
Exception: The string "C:\Batch\test\sub\e1f8a7c2?.tmp" is not a valid Windows path string.
PS> # The file path string has a > sign.
PS> [WindowsPath]::new("C:\Batch\te>st\sub\e1f8a7c2.tmp")
Exception: The string "C:\Batch\te>st\sub\e1f8a7c2.tmp" is not a valid Windows path string.
```

Compare the result to `Test-Path` bound with the `IsValid` parameter.

```powershell
PS> Test-Path "C:\Batch\test\sub  \e1f8a7c2.tmp" -IsValid
True
PS> Test-Path "C:\Batch\test\sub\e1f8a7c2?.tmp" -IsValid
True
PS> Test-Path "C:\Batch\test\sub>\e1f8a7c2.tmp" -IsValid
True
```

