using namespace 'System'

BeforeDiscovery {
    Import-Module WindowsPath -Force
}

Describe 'Test local paths [string] casting to [WindowsPath]' {
    #Region: Random path string generators (Arrange).
    Function Script:Get-RandomFilename {
        <#
        .SYNOPSIS
            Generate a valid random file name of at most 20 characters.
        .NOTES
            A file name is valid if:
            - all its characters are not invalid file name characters ('\', '/', ':', '*', '?', '"', '<', '>', '|'),
            - it does not end with space character,
            - it is not '.' and '..' cause they are special file names.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        Param()
        Do {
            $FileName = ((([char[]](32..126 + 160..255)).
            Where{ $_ -notin @('\','/',':','*','?','"','<','>','|') } |
            Get-Random -Count (Get-Random -Minimum 1 -Maximum 21)) -join '').TrimEnd()
        } while ([string]::IsNullOrEmpty($FileName) -or $FileName -eq '.' -or $FileName -eq '..')
        Return $FileName
    }
    Function Script:Get-RandomFalseFilename {
        <#
        .SYNOPSIS
            Generate an invalid random file name of at most 20 characters.
        .NOTES
            A file name is invalid if:
            - at least one character is an invalid file name character (':', '*', '?', '"', '<', '>', '|') excluded ('\', '/') since they are used to delimit segment,
            - it ends with at least one space character.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        Param([switch] $EndsWithSpace)
        $Filename = Get-RandomFilename
        If ($EndsWithSpace) { Return $Filename.Replace($Filename[-1], ' ') }
        Return $Filename.Replace($Filename[(Get-Random -Minimum 0 -Maximum $Filename.Length)], (Get-Random ':','*','?','"','<','>','|'))
    }
    Function Script:Get-RandomPath {
        <#
        .SYNOPSIS
            Generate a valid and clean Windows path string with no drive letter nor share name.
        .NOTES
            A Windows path string is clean when:
            - 2 segments are separated by only one '\',
            - it does not end with '\',
            - it does not contain '.' nor '..' special folders,
            - it does not start '~' segment.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        Param()
        Return (1..$(Get-Random -Minimum 1 -Maximum 5)).ForEach{Get-RandomFilename} -join '\'
    }
    Function Script:Get-RandomPSDriveName {
        <#
        .SYNOPSIS
            Generate a valid random PS drive name of at most 5 characters.
        .NOTES
            A drive name is valid if all its characters are not invalid drive name characters (';', '~', '/', '\', '.', ':').
            For the tests, since Drive Letters are already generated, exclude them from the list of possible one letter drive name.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        Param()
        $LetterCount = Get-Random -Minimum 1 -Maximum 6
        Return (($LetterCount -eq 1 ? ([char[]](32..64 + 91..96 + 123..126 + 160..255)):([char[]](32..126 + 160..255))).
        Where{ $_ -notin @(';', '~', '/', '\', '.', ':') } | Get-Random -Count $LetterCount) -join ''
    }
    Function Script:Get-RandomRootedPath {
        <#
        .SYNOPSIS
            Generate a random rooted path string.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        Param(
            # The list of PS drives.
            [char[]] $Root,
            # The number of rooted path to generate.
            [int] $Count
        )
        (1..$Count).ForEach{ $Root | Get-Random }.ForEach{ "${_}:\$(Get-RandomPath)" }
    }
    $Script:TruePSDrive = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' -and (Test-Path $_.Root) } | Select-Object -Unique).Root
    $Script:TrueExistingLogicalDrive = $Script:TruePSDrive[0]
    $Script:TrueNonExistingLogicalDrive = "$(('A'..'Z').Where({ "${_}:\" -notin $Script:TruePSDrive }, 'First')):\"
    $Script:ExistingLogicalDriveList = [char[]] ('H'..'K')
    $Script:NonExistingLogicalDriveList = [char[]] ('L'..'O')
    $Script:ExistingLogicalDriveListWithCurrentLocation = [char[]](([int[]]($ExistingLogicalDriveList)) -ge 74)
    $Script:ExistingLogicalDriveListWithNoCurrentLocation = [char[]](([int[]]($ExistingLogicalDriveList)) -lt 74)
    #EndRegion
    InModuleScope 'WindowsPath' {
        BeforeAll {
            # The list of PS drive names that are not letters.
            $SpecialDriveNameList = @()
            Function Get-RandomUniqueDrivename {
                <#
                .SYNOPSIS
                    Generate random PS drive name that is unique in the session.
                #>
                [CmdletBinding()]
                [OutputType([string])]
                Param()
                Do { $DriveName = Get-RandomPSDriveName } While ($DriveName -in $Script:SpecialDriveNameList)
                $Script:SpecialDriveNameList += $DriveName
                $DriveName
            }
            # The list of Mocked PS drive info objects: only set the Name, Root and CurrentLocation properties.
            # The current location is always a randomized non-rooted path when specified.
            # The list below is the list of existent roots. Meaning that Test-Path will return true if applied on it.
            $PSDriveList = @($ExistingLogicalDriveList.ForEach{
                $Root = "${_}:\"
                $ToInt = [int] $_
                # PS drive names consisting of a letter matching its root.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = $_
                    Root = $Root
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # PS drive names consisting of special words with roots that match drive folders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = $Root
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # PS drive names consisting of special words with roots that are not drive folders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = "$Root$(Get-RandomPath)"
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # The same as the previous one but only with '\' at the end of the drive subfolders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = "$Root$(Get-RandomPath)\"
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # PS drive names consisting of a letter not matching its root.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = [char]($ToInt - 4)
                    Root = $Root
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # PS drive names consisting of a letter not matching its root drive letter.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = [char]($ToInt + 4)
                    Root = "$Root$(Get-RandomPath)"
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # The same as the previous one but only with '\' at the end of the drive subfolders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = [char]($ToInt + 8)
                    Root = "$Root$(Get-RandomPath)\"
                } + ($ToInt -ge 74 ? @{ CurrentLocation = Get-RandomPath }:@{}))
            })
            # The list below is the list of non existent roots. Meaning that Test-Path will return false if applied on it.
            $PSDriveList += @($NonExistingLogicalDriveList.ForEach{
                $Root = "${_}:\"
                $ToInt = [int] $_
                # PS drive names consisting of special words with roots that are root drive folders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = $Root
                } + ($ToInt -ge 78 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # PS drive names consisting of special words with roots that are not root drive folders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = "$Root$(Get-RandomPath)"
                } + ($ToInt -ge 78 ? @{ CurrentLocation = Get-RandomPath }:@{}))
                # The same as the previous one but only with '\' at the end of the drive subfolders.
                New-MockObject -Type 'System.Management.Automation.PSDriveInfo' -Properties (@{
                    Name = Get-RandomUniqueDrivename
                    Root = "$Root$(Get-RandomPath)\"
                } + ($ToInt -ge 78 ? @{ CurrentLocation = Get-RandomPath }:@{}))
            })
            Mock -CommandName 'Get-PSDrive' -MockWith {
                <#
                .SYNOPSIS
                    Get mocked PS drives.
                #>
                [CmdletBinding()]
                [OutputType([PSDriveInfo[]])]
                Param(
                    # Specifies name or names of PS drives to retrieve.
                    [string[]] $Name,
                    # PSProvider parameter is default to FileSystem to filter to the specified type of PS providers.
                    [string[]] $PSProvider = 'FileSystem'
                )
                # When name is defined, only return the PS drives with the specified names. Otherwise returns all. 
                @(If ($PSBoundParameters.ContainsKey('Name')) { $Script:PSDriveList.Where{ $_.Name -in $Name } }
                Else { $Script:PSDriveList }) | Sort-Object Name
            }.GetNewClosure()
            Mock -CommandName 'Join-Path' -MockWith {
                <#
                .SYNOPSIS
                    Concatenate parts of a path string.
                #>
                [CmdletBinding()]
                [OutputType([string])]
                Param(
                    # Specifies the parent path.
                    [string[]] $Path,
                    # Specifies the child path.
                    [string] $ChildPath
                )
                If ($Path[0] -match '(?<LogicalDrive>^[A-Z]:\\)') {
                    $Private:__path = $Matches.LogicalDrive
                    Switch ($Matches.LogicalDrive) {
                        { $_ -in $ExistingLogicalDriveList.ForEach{ "${_}:\" } } { $Path = @($TrueExistingLogicalDrive) }
                        { $_ -in $NonExistingLogicalDriveList.ForEach{ "${_}:\" } } { $Path = @($NonExistingLogicalDriveList) }
                    }
                }
                $Result = Microsoft.PowerShell.Management\Join-Path $Path[0] $ChildPath
                If ($Private:__path) { $Result = $Result -replace '^[A-Z]:\\',$__path }
                Return $Result
            }.GetNewClosure()
            Filter Get-ExpectedParentFolder { Return $Args[0] -replace '\\[^\\]+$' -replace ':$',':\' }
        }
        Context 'Path or file name string input is a whitespace or is empty' {
            It 'Whitespace character #<_>' -TestCases @(1..9) {
                $(Switch ($_) {
                    1 { [WindowsPath]::GetFullPath($Null) }
                    2 { [WindowsPath]::GetFullPath('') }
                    3 { [WindowsPath]::GetFullPath(' ') }
                    4 { [WindowsPath]::GetFullPath([Environment]::NewLine) }
                    5 { [WindowsPath]::GetFullPath("`n") }
                    6 { [WindowsPath]::GetFullPath("`r") }
                    7 { [WindowsPath]::GetFullPath("`t") }
                    8 { [WindowsPath]::GetFullPath("`v") }
                    9 { [WindowsPath]::GetFullPath("`f") }
                }) | Should -BeNullOrEmpty
                @($Null, '', ' ', [Environment]::NewLine, "`n", "`r", "`t", "`v", "`f").
                ForEach{
                    $(Try { ([ValidateWindowsFileName()] $Local:PathItem1 = $_) } Catch { }) | Should -BeNullOrEmpty
                    $(Try { ([ValidateWindowsPath()] $Local:PathItem2 = $_) } Catch { }) | Should -BeNullOrEmpty
                }
            }
        }
        Context 'Path string rooted with an existing logical drive' {
            It '"<_>":' -TestCases @(Get-RandomRootedPath $ExistingLogicalDriveList 5) {
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $_
                "$([WindowsPath] "$_\..")" | Should -BeExactly (Get-ExpectedParentFolder $_)
                @($_, "$_\", "$_\.", ($_ -replace '\\','/')).ForEach{ ([ValidateWindowsPath()] $Local:PathItem = $_) | Should -BeExactly $_ }
                $PathSegments = $_ -split '\\'
                $PathSegments[(Get-Random -Minimum 1 -Maximum $PathSegments.Count)] = Get-RandomFalseFilename
                ($PathSegments -join '\').ForEach{
                    $ExpectedPath = $_
                    $ErrorMessage = "The string `"$ExpectedPath`" is not a valid Windows path string."
                    $(Try { [WindowsPath]::New($ExpectedPath) } Catch { $_.Exception.Message }) | Should -BeExactly $ErrorMessage
                    $ErrorMessage = "The string `"$ExpectedPath\`" is not a valid Windows path string."
                    $(Try { [WindowsPath]::New("$ExpectedPath\") } Catch { $_.Exception.Message }) | Should -BeExactly $ErrorMessage
                }
                $IndexList = @($i = -1; Do { ($i = $_.IndexOf('\', $i + 1)) } While ($i -ge 0)).Where({ $_ -lt 0 }, 'Until')
                $UpdatedPath = $_[0..($_.Length-1)]
                $UpdatedPath[(Get-Random -InputObject $IndexList)] = '/'
                "$([WindowsPath] ($UpdatedPath -join ''))" | Should -BeExactly $_
                $UpdatedPath = $_[0..($_.Length-1)]
                $UpdatedPath[(Get-Random -InputObject $IndexList)] = '\.\'
                "$([WindowsPath] ($UpdatedPath -join ''))" | Should -BeExactly $_
                $UpdatedPath = $_[0..($_.Length-1)]
                $UpdatedPath[(Get-Random -InputObject $IndexList)] = '  \'
                { "$([WindowsPath] ($UpdatedPath -join ''))" } | Should -Throw
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath $ExistingLogicalDriveListWithCurrentLocation 5).ForEach{ $_ -replace ':\\',':' }) {
                $CurrentPSDrive = $PSDriveList | Where-Object Name -EQ @($_ -split ':')[0] | Select-Object Name,Root,CurrentLocation
                $ExpectedPath = $_ -replace ':',":\$($CurrentPSDrive.CurrentLocation.ForEach{ "${_}\" })"
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                "$([WindowsPath] "$_\..")" | Should -BeExactly  (Get-ExpectedParentFolder $ExpectedPath)
            }
        }
        Context 'Relative path string from a local folder' {
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:\\' }) {
                $ExpectedPath = "$PWD\$_"
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                "$([WindowsPath] "$_\..")" | Should -BeExactly  (Get-ExpectedParentFolder $ExpectedPath)
                $ExpectedPath = "$HOME\$_"
                ([WindowsPath[]] @("~\$_", "~\$_\", "~\$_\.", ("~\$_" -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                "$([WindowsPath] "~\$_\..")" | Should -BeExactly  (Get-ExpectedParentFolder $ExpectedPath)
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:' }) {
                $ExpectedPath = "$($PWD.Drive):$_"
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                "$([WindowsPath] "$_\..")" | Should -BeExactly  (Get-ExpectedParentFolder $ExpectedPath)
            }
        }
        Context 'Network share path string' {
            BeforeAll {
                Try {
                    New-SmbShare -Name share -Path (New-Item -Path "$Env:TEMP\share" -ItemType Directory -Force).FullName -FullAccess "$env:COMPUTERNAME\$env:USERNAME" -Temporary -ErrorAction SilentlyContinue
                }
                Catch { }
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:\\',"\\$env:COMPUTERNAME\share\" }) {
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $_
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:\\',"\\$env:COMPUTERNAME\offshare\" }) {
                $ExpectedPath = "$($PWD.Drive):$($_.Substring(1))"
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:\\' }) {
                Push-Location "\\$env:COMPUTERNAME\share\"
                $ExpectedPath = "\\$env:COMPUTERNAME\share\$_"
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                Pop-Location
            }
            It '"<_>":' -TestCases @('\') {
                $ExpectedPath = "\\$env:COMPUTERNAME\share\"
                Push-Location $ExpectedPath
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                Pop-Location
            }
            It '"<_>":' -TestCases @((Get-RandomRootedPath 'A' 10).ForEach{ $_ -replace 'A:' }) {
                $ExpectedPath = "\\$env:COMPUTERNAME\share\"
                Push-Location $ExpectedPath
                $ExpectedPath += $_.Substring(1)
                ([WindowsPath[]] @($_, "$_\", "$_\.", ($_ -replace '\\','/'))).ForEach{ "$_" } | Select-Object -Unique | Should -BeExactly $ExpectedPath
                Pop-Location
            }
        }
    }
}

AfterAll {
    Remove-Module -Name WindowsPath -Force
}