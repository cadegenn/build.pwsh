<#
.SYNOPSIS
Write debian control file

.DESCRIPTION
Output a fully-formated control file based on build configuration

.PARAMETER build
build object read from build.rc

.PARAMETER Destination
destination folder

.OUTPUTS
Full path to control file



.EXAMPLE
$build | Out-DebianCONTROLFile -Destination /tmp/project.build

.NOTES
	2018.x.x -	honor PAckage, Version, Maintainer, Installed-Size and Description fields

.LINK
https://www.debian.org/doc/debian-policy/ch-controlfields.html

#>
function Out-DebCONTROLFile {
	[CmdletBinding()][OutputType([String])]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][hashtable]$build,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)][string]$Destination
	)
	Begin {
		eenter($MyInvocation.MyCommand)
		if (!(dirExist($Destination))) { $rc = New-Item $($Destination) -Force -ItemType Directory}
	}

	Process {
		# @url https://www.debian.org/doc/debian-policy/ch-controlfields.html
		$SIZE = du -sk $build.buildDir | cut -f1
		edevel("SIZE = " + $SIZE + "k")
@"
Package: $($build.PRODUCT_SHORTNAME)
Version: $($build.version).$($build.number)
Architecture: all
Maintainer: $($build.PRODUCT_PUBLISHER) <$($build.PRODUCT_PUBLISHER_EMAIL)>
Section: utils
Priority: optional
Installed-Size: $SIZE
Description: $($build.PRODUCT_DESCRIPTION)
"@ | Set-Content "$($Destination)/control"
		return "$($Destination)/control"
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
