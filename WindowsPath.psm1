#Requires -Version 7.0
using namespace 'System'
using namespace 'System.IO'
using namespace 'System.Management.Automation'

Class WindowsPath {
	# Performs operations on string instances that contain Windows file system path information.
	# The specified path or file name string may be pointing to a nonexistent file system object.
	# The file system object is either pointing to a local or a network share file, or directory.

	WindowsPath([string] $Path) {
		# Constructor that instantiates a windows path object.
		# It allows conversion from string to [WindowsPath] object.

		# Path is a read-only accessor property to get the absolute path string to a file system object.
		# Path is only set when the specified path string is a valid windows path string.
		# If the path string is invalid, then throw an error.
		If (!!($WinPath = [WindowsPath]::GetFullPath($Path))) { $This | Add-Member ScriptProperty 'Path' { [CmdletBinding()][OutputType([string])] Param () $Script:WinPath }.GetNewClosure() }
		Else { Throw 'The string "{0}" is not a valid Windows path string.' -f $Path }
	}

	Static [string] GetFullPath([string] $PathToValidate) {
		# Returns the validated Windows absolute path of the specified path string.
		# Returns an empty string if the path string contains invalid characters, a nonexistent root drive or share server.

		# If the specified path to validate is a whitespace string, the method returns a $null value.
		If ([string]::IsNullOrWhiteSpace($PathToValidate) -or (& { $args[0] -imatch '[^ ]\s+([/\\]|$)' } $PathToValidate)) { Return $Null }
		# The set of sub regexp that will be included in the final RegExp.
		$IPv6RegExp = '((([a-f\d]{1,4}:){7,7}[a-f\d]{1,4}|([a-f\d]{1,4}:){1,7}:|([a-f\d]{1,4}:){1,6}:[a-f\d]{1,4}|([a-f\d]{1,4}:){1,5}(:[a-f\d]{1,4}){1,2}|([a-f\d]{1,4}:){1,4}(:[a-f\d]{1,4}){1,3}|([a-f\d]{1,4}:){1,3}(:[a-f\d]{1,4}){1,4}|([a-f\d]{1,4}:){1,2}(:[a-f\d]{1,4}){1,5}|[a-f\d]{1,4}:((:[a-f\d]{1,4}){1,6})|:((:[a-f\d]{1,4}){1,7}|:)|fe80:(:[a-f\d]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([a-f\d]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])))'
		$IPv4RegExp = '((\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})'
		$HostNameRegExp = '([a-z\d\-]+(\.[a-z\d\-]+)*)'
		$ShareNameRegExp = '([^"/\\\[\]:\|\<\>\+=;,\?\*]+)'
		$DriveRegExp = '([^;~/\\\.:]+:)'
		$RelativeElmtRegExp = '(~|\.{1,2}|[^"/\\:\|\<\>\?\*]+)'
		$PathRegExp = '(([/\\]+[^"/\\:\|\<\>\?\*]*)*)'
		# The general regexp that matches path strings and returns:
		# Share: the network share part of the path string.
		# Drive: the drive name part of the path string.
		# Cwd: the relative path segment after the drive part.
		# Relative: the relative elements '~', '.', '..' or a path segment.
		# Path: the path segments.
		$RegExp = '(((?<Share>^(/{{2}}|\\{{2}})({0}|{1}|{2})[/\\]+{3})|((?<Drive>^{4})(?<Cwd>[^"/\\:\|\<\>\?\*]*))|(?<Relative>^{5}))(?<Path>{6}$))|(?<Path>^{6}$)' -f @($IPv6RegExp,$IPv4RegExp,$HostNameRegExp,$ShareNameRegExp,$DriveRegExp,$RelativeElmtRegExp,$PathRegExp)
		# Boolean value to signify that the path string to validate does not contain segments ending with space character.
		# Test the path to validate with the RegExp and because negative RegExp is not available, there is an AND expression
		# that completes the regular expression by specifying that the string does not match white space at the end of a file
		# or directory name. The test is kept in scriptblock to make the automatic variable $Matches available during the execution
		# of the method.
		If ($PathToValidate -imatch $RegExp) {
			# Function to remove matches that are specified not to be one of the key set by argument 1.
			# Argument 0 is the reference object pointing to the $Matches hashtable.
			${Function:Remove-MatchIntKeys} = { ForEach ($key in @($args[0].Value.keys)) { If ($key -inotin $args[1]) { $args[0].Value.Remove($key) } } }
			# Remove any index that are not either one of the elements specified in the set ['Share','Drive','Cwd','Relative','Path']
			Remove-MatchIntKeys ([ref] $Matches) @('Share','Drive','Cwd','Relative','Path')
			# If the path to validate matches a network share, verify whether the specified network share can be found by the local system.
			$Matches.Where{ 'Share' -in $_.keys }.ForEach{
				# If the network share can be found by the system, then set the absolute path as the combination of the 
				# network share name and the path to the file system object identified by the path string.
				# Else verify if the network share can be considered as a path segment and set the context to the current directory.
				# Remove the Share key to signify that the path does not point to a network share and may be a relative path.
				If ([Directory]::Exists($_.Share)) { $_.FullPath = Join-Path $_.Share $_.Path }
				ElseIf (& { $args[0] -imatch ('(?<Path>^{0}$)' -f $PathRegExp) } $_.Share) {
					$_.Path = Join-Path $_.Share $_.Path
					$_.Remove('Share')
				}
			}
			Switch ($Matches) {
				# If the path to validate matches a local drive, verify whether the PSDrive is defined and can be retrieved by Get-PSDrive.
				# When the PSDrive exists, join its root to the path to the resource. If the drive delimiter ':' is followed immediatetly by a file name,
				# or if the path to the resource is empty, join the root of PSDrive, or optionally the PSDrive Current location, the working dirctory child item. 
				{ 'Drive' -in $_.keys } {
					If (($PSDrive = Get-PSDrive -Name ($_.Drive -replace ':$') -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
						$_.FullPath = Join-Path $PSDrive.Root ((($_.Cwd -or !$_.Path ? ($PSDrive.CurrentLocation ? (@($PSDrive.CurrentLocation,$_.Cwd) -join '\'):($_.Cwd)):'') -replace '[/\\]+$') + (($_.Path = $_.Path -replace '[/\\]+$') ? ('\' + $_.Path):$Null))
					}
				}
				# If the path to validate matches a relative path starting with '~','.','..' or a file/folder name,
				# then resolve '~','.','..' and append the path segment to the the resolved path string. 
				# If the starting characters are defining a file or folder name, join both the current path to the file name and the path string.
				# The split operator is to ensure that the provider is not output with the file path. This occurs when the path is network share.
				{ 'Relative' -in $_.keys } {
					If ($_.Relative -in @('~','.','..')) { $_.FullPath = Join-Path ("$(Resolve-Path $_.Relative -ErrorAction Stop)" -split '::',2)[-1] $_.Path }
					Else { $_.FullPath = Join-Path $PWD.ProviderPath (Join-Path $_.Relative $_.Path) }
				}
			}
			# If FullPath key is defined then remove all the other keys from $Matches.
			If ('FullPath' -in @($Matches.keys)) { Remove-MatchIntKeys ([ref] $Matches) @('FullPath') }
		}
		# Skip if a path segment ends with space or the full path is already defined.
		# If there is already a Path from the previous if statement, then use it or get a new match.
		If (!$Matches.FullPath -and (($Matches.Share -and $Matches.Path) -or $PathToValidate -imatch ('(?<Path>^{0}$)' -f $PathRegExp))) {
			# Resolve '\' or '/' and append the path segment to the the resolved path string. '\' resolution from a network share location throws an error.
			# The split operator is to ensure that the provider is not output with the file path. This occurs when the path is network share.
			$Matches.FullPath = Join-Path "$(Try { ((Resolve-Path '\' -ErrorAction Stop).Drive.Root + '\') -replace '\\\\$','\' } Catch { & {
				[void] ($PWD.ProviderPath -imatch '(?<Share>\\{2}[^/\\]+\\+[^/\\]+(\\|$))')
				$Matches.Share
			} })" $Matches.Path
		}
		If ('FullPath' -in @($Matches.keys)) {
			# If FullPath key is defined.
			# Remove duplicate segment delimiters '/' or '\', and '.' segments.
			$Index0,$Index1,$PathSegmentList = $Matches.FullPath?.Split([char[]](47,92),[StringSplitOptions]::RemoveEmptyEntries).Where{ $_ -ne '.'}
			Switch ($Matches) {
				# Get the network share identifier
				{ $_.FullPath -like '\\*' -or $_.FullPath -like '//*' } { $_.Prefix = '\\{0}\{1}\' -f $Index0,$Index1 }
				# Get the local root drive identifier and add the immediate FS object to the root to the segments of the path without drive.
				Default {
					$_.Prefix = "$Index0\"
					$PathSegmentList = @($Index1) + $PathSegmentList
				}
			}
			# Remove '..' segments. When '..' segment is matched and the previous segment is a valid file name such as '\batch\..\'.
			$CurrentSegmentIndex = 1
			While ($CurrentSegmentIndex -lt $PathSegmentList.Count) {
				If ($CurrentSegmentIndex -gt 0 -and $PathSegmentList[$CurrentSegmentIndex] -eq '..' -and $PathSegmentList[$CurrentSegmentIndex - 1] -ne '..') {
					$PathSegmentList[$CurrentSegmentIndex - 1] = $PathSegmentList[$CurrentSegmentIndex] = $Null
					$PathSegmentList = $PathSegmentList.Where{ $_ }
					$CurrentSegmentIndex--
				}
				Else { $CurrentSegmentIndex++ }
			}
			# Removes the leading '..' segments and join it too the prefix which is a drive root or a network share.
			$Matches.FullPath = Join-Path $Matches.Prefix (($PathSegmentList.Where({ $_ -ne '..' }, 'SkipUntil') -Join '\') -replace '[/\\]+$')
		}
		Return $Matches.FullPath
    }

	# Allow to convert the windows path object to its full path string.
    [string] ToString() { Return $This.Path }
}

Class ValidateWindowsPathAttribute : ValidateArgumentsAttribute {
	# Type defining the validation attribute to ensure that a path string is a valid Windows path.

	[void] Validate([object] $PathToValidate, [EngineIntrinsics] $EngineIntrinsics) {
		# Throw an error when the specified path is not a valid Windows path.

		[WindowsPath]::New($PathToValidate)
	}
}

Class ValidateWindowsFileNameAttribute : ValidateArgumentsAttribute {
	# Type defining the validation attribute to ensure that a file name string is a valid Windows file name.

	[void] Validate([object] $FileNameToValidate, [EngineIntrinsics] $EngineIntrinsics) {
		# Throw an error when the specified file name is not a valid Windows file name.

		If (!("$FileNameToValidate" -imatch '^[^"/\\:\|\<\>\?\*]+[^"/\\:\|\<\>\?\*\s]+$' -and $Matches[0] -inotmatch '^\.{1,2}$'))
		{ Throw 'The string "{0}" is not a valid Windows file name string.' -f $FileNameToValidate }
	}
}