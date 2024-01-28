using namespace 'System.IO'

Filter Get-ModuleInstallationRoot {
    [CmdletBinding()]
    Param(
        [string] $ModuleName = 'WindowsPath'
    )
    @((Get-Module -Name $ModuleName -ListAvailable)?.ModuleBase)[0]
}

Filter Get-ModuleInstallationVersion {
    [CmdletBinding()]
    Param(
        [string] $ModuleName = 'WindowsPath'
    )
    @((Get-Module -Name $ModuleName -ListAvailable)?.Version)[0]
}

Filter New-ModuleInstallationManifest {
    [CmdletBinding()]
    Param(
        [string] $Path = $PSScriptRoot,
        [string] $ProjectUri = (git ls-remote --get-url) -replace '\.git$',
        [string] $ModuleName = 'WindowsPath'
    )
    $VerboseFlag = $VerbosePreference -ine 'SilentlyContinue'
    Try {
        # Read the latest version and the release notes from the latest.json file
        $LatestJson = Get-Content "$Path\latest.json" -Raw -ErrorAction Stop -Verbose:$VerboseFlag | ConvertFrom-Json
        @{
            # Arguments built for New-ModuleManifest
            Path = "$Path\$ModuleName.psd1"
            RootModule = "$ModuleName.psm1"
            ModuleVersion = $LatestJson.version
            GUID = '75cebe01-d18c-4d4c-9e00-c65c6821ad07'
            Author = 'Fabrice Sanga'
            CompanyName = 'sangafabrice'
            Copyright = "© $((Get-Date).Year) SangaFabrice. All rights reserved."
            Description = @"
The WindowsPath type performs operations on string instances that contain valid Windows File System path information. The specified path or file name string may point to a nonexistent file system object that is nonetheless valid and may carry information about locally or network shared files and directories.
The module also provides two validation attributes ValidateWindowsPath and ValidateWindowsFileName.
→ To support this project, please visit and like: $ProjectUri
"@
            PowerShellVersion = '7.0'
            PowerShellHostVersion = '7.0'
            FunctionsToExport = @()
            CmdletsToExport = @()
            VariablesToExport = @()
            AliasesToExport = @()
            FileList = "$ModuleName.psd1","$ModuleName.psm1"
            Tags = @('windows-path','type','file-name','validator')
            LicenseUri = "$ProjectUri/blob/module/LICENSE.md"
            ProjectUri = $ProjectUri
            IconUri = 'https://gistcdn.githack.com/sangafabrice/a8c75d6031a491c0907d5ca5eb5587e0/raw/406120be7a900c3998e33d7302772827f20539f0/automation.svg'
            ReleaseNotes = $LatestJson.releaseNotes -join "`n"
        }.ForEach{
            New-ModuleManifest @_ -ErrorAction Stop -Verbose:$VerboseFlag
            [Path]::GetFullPath($_.Path)
        }
    }
    Catch { }
}

@{
    Name = 'ModuleBuilder'
    Scriptblock = ([scriptblock]::Create((Invoke-RestMethod 'https://api.github.com/gists/387cc6063e148917a2fe5503e57b823c').files.'ModuleBuilder.psm1'.content)).GetNewClosure()
} | ForEach-Object { New-Module @_ } | Import-Module -Force