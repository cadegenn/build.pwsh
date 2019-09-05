function Out-NullSoftInstallerScriptHeaderFile {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][hashtable]$build,
		[Parameter(Mandatory = $false,ValueFromPipeLine = $false)][string]$Filename
	)
	Begin {
		eenter($MyInvocation.MyCommand)
	}

	Process {
		"" | Set-Content $Filename -Encoding utf8
		foreach ($k in $build.Keys) {
			"!define $($k.ToUpper()) '$($build.$k)'" | Out-File -FilePath $Filename -Encoding utf8 -Append
		}
		# $data = foreach ($k in $build.Keys) {
		# 	"!define $($k.ToUpper()) '$($build.$k)'"
		# }
		# $data | Out-File -FilePath $Filename -Encoding utf8
		# $data | Set-Content $Filename -Encoding utf8
		# # edevel(Get-Content $Filename -Encoding utf8 | ConvertTo-Json)
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
Set-Alias -Name Out-NSISHeader -Value Out-NullSoftInstallerScriptHeaderFile

function New-NullSoftInstallerScriptListFile {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][string]$SourceDirectory,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)][hashtable]$build,
		[Parameter(Mandatory = $false,ValueFromPipeLine = $false)][string]$Filename
	)
	Begin {
		eenter($MyInvocation.MyCommand)
	}

	Process {
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
Set-Alias -Name Out-NSISFiles -Value New-NullSoftInstallerScriptListFile


function Out-CabinetDefinitionFile {
	[CmdletBinding()]Param (
		# [Parameter(Mandatory = $true,ValueFromPipeLine = $true)][string]$SourceDirectory,
		# [Parameter(Mandatory = $true,ValueFromPipeLine = $false)][hashtable]$build,
		# [Parameter(Mandatory = $false,ValueFromPipeLine = $false)][string]$Filename
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][hashtable]$build,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)][string]$Destination
	)
	Begin {
		eenter($MyInvocation.MyCommand)
		if (!(dirExist($Destination))) { New-Item $($Destination) -Force -ItemType Directory }
	}

	Process {
@"
; @url https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/makecab
; @url https://msdn.microsoft.com/en-us/library/bb417343.aspx#dir_file_syntax
; @url https://ss64.com/nt/makecab.html
; to build a cabinet archive using this definition file, you have to provide 3 variables on command line :
; makecab.exe /F "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" /D SourceDir=$($build.root) /D CabinetNameTemplate=$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).cab /D DiskDirectoryTemplate=$($build.releases)
; or
; makecab.exe /F "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf"
.Set SourceDir=$($build.root)
.Set CabinetNameTemplate=$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).cab
.Set DiskDirectoryTemplate=$($build.releases)
.Set DiskLabelTemplate=$($build.PRODUCT_SHORTNAME)
.Set Cabinet=on
.Set Compress=on
.Set UniqueFiles=off
"@ | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append:$false

		# process folders
		foreach ($f in $Script:Folders) {
			# get a list of directories containing files
			(Get-ChildItem $($build.root + [IO.Path]::DirectorySeparatorChar + $f) -Recurse -File).DirectoryName | Sort-Object -Unique | ForEach-Object {
				# process files accordingly
				$(".Set DestinationDir=" + $_.replace($build.root + [IO.Path]::DirectorySeparatorChar, "")) | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append
				# $gci = Get-ChildItem $_ -File
				# $gci2 = ($gci.fullname).replace($build.root + [IO.Path]::DirectorySeparatorChar, "")
				# $gci2 | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append
				((Get-ChildItem $_ -File).fullname).replace($build.root + [IO.Path]::DirectorySeparatorChar, "") | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append
			}
		}

		# process files
		".Set DestinationDir=" | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append
		foreach ($f in $Script:Files) {
			((Get-ChildItem $($build.root + [IO.Path]::DirectorySeparatorChar + $f) -File).fullname).replace($build.root + [IO.Path]::DirectorySeparatorChar, "") | Out-File -FilePath "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf" -Encoding utf8 -Append
		}
		return "$($Destination)/$($build.PRODUCT_SHORTNAME).ddf"
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
