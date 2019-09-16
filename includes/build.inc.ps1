<#
.SYNOPSIS
Read a resource file and return a hastable

.DESCRIPTION
Read a resource file, convert values to format them, trim, and return a hastable.
Resource file must be filled with "KEY=Value" pair, one per line.

.PARAMETER From
Filename to read

.EXAMPLE
$build = Get-BuildRC -From /path/to/build.rc

.NOTES

#>

function Get-BuildRC {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][string]$From
	)
	Begin {
		eenter($MyInvocation.MyCommand)
	}

	Process {
		if (!(fileExist $From)) { efatal "$From not found." }

		$build = (Get-Content $From -Encoding utf8) | ConvertFrom-StringData
		if ($null -eq $build) { efatal "Cannot read $From." }
		# trim double quotes
		$build = $build.Keys | ForEach-Object { $b = @{} } { $b[$_] = $build.$_.Trim('"') } { $b }
		$build.buildDir = $([system.io.path]::GetTempPath() + $build.PRODUCT_SHORTNAME + ".build")
		$rc = New-Item $build.buildDir -ItemType Directory -ErrorAction SilentlyContinue
		edevel($build | ConvertTo-Json)

		return $build
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}

<#
.SYNOPSIS
Guess everything that can be guessed to configure build environment

.DESCRIPTION
Build environments follow same logic. Get-BuildEnvironment can guess near everything.

.EXAMPLE
$buildEnv = Get-BuildEnvironment

.NOTES

#>

function Get-BuildEnvironment {
	[CmdletBinding()][OutputType([hashtable])]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][string]$ProjectPath
	)
	Begin {
		eenter($MyInvocation.MyCommand)
	}

	Process {
		$b = @{}
		# $b.root = (Resolve-Path $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "..")).Path
		$b.root = ($ProjectPath | Resolve-Path).ProviderPath.TrimEnd([IO.Path]::DirectorySeparatorChar)
		$b.GUID = New-Guid
		$b.releases = $($b.root + [IO.Path]::DirectorySeparatorChar + "releases")
		if (!(fileExist $($b.root + [IO.Path]::DirectorySeparatorChar + "VERSION"))) { "1.0.0" | Set-Content -Path $($b.root + [IO.Path]::DirectorySeparatorChar + "VERSION") }
		[string]$b.version = Get-Content $($b.root + [IO.Path]::DirectorySeparatorChar + "VERSION")

		if (!(fileExist $($b.root + [IO.Path]::DirectorySeparatorChar + "BUILD"))) { 0 | Set-Content -Path $($b.root + [IO.Path]::DirectorySeparatorChar + "BUILD") }
		[uint16]$b.number = Get-Content $($b.root + [IO.Path]::DirectorySeparatorChar + "BUILD")
		$b.number++
		$rc = $b.number | Set-Content $($b.root + [IO.Path]::DirectorySeparatorChar + "BUILD")
		# APPVEYOR: honor appveyor build number
		if ($null -ne $env:APPVEYOR_BUILD_NUMBER) { $b.number = $env:APPVEYOR_BUILD_NUMBER}
		# TRAVIS: honor travis-ci build number
		if ($null -ne $env:TRAVIS_BUILD_NUMBER) { $b.number = $env:TRAVIS_BUILD_NUMBER}
		# GITLAB: honor gitlab-ci pipeline project's build number
		if ($null -ne $env:CI_PIPELINE_IID) { $b.number = $env:CI_PIPELINE_IID}

		# $b.number | Set-Content $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "BUILD")
		# it seems $b.root is readonly
		# $b.number | Set-Content $($b.root + [IO.Path]::DirectorySeparatorChar + "BUILD")

		return $b
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}

<#
.SYNOPSIS
Check is everything is ok before launching build

.DESCRIPTION
Approve-BuildEnvironment check if $build object have no $null member. It checks if every paths defined exists.

.PARAMETER InputObject
Build object previously built with Get-BuildEnvironment

.EXAMPLE
$build = Get-BuildEnvironment
$build.buildDir = "/some/where"
Approve-BuildEnvironment

.NOTES
General notes
#>

function Approve-BuildEnvironment {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)]$InputObject
	)
	Begin {
		eenter($MyInvocation.MyCommand)
	}

	Process {
		# ROOT
		$rc1 = $null -ne $InputObject.root
		$rc2 = $rc1 -and (dirExist $InputObject.root)
		ebegin("Check project's root (" + $InputObject.root + ")")
		eend ($rc1 -and $rc2)

		# ROOT's BUILD CONF FILES
		$rc11 = (fileExist "$($InputObject.root)/build/build.rc")
		ebegin("Check project's build.rc conf file ($($InputObject.root)/build/build.rc)")
		eend $rc11
		$rc12 = (fileExist "$($InputObject.root)/build/build.conf.ps1")
		ebegin("Check project's build.conf.ps1 conf file ($($InputObject.root)/build/build.conf.ps1)")
		eend $rc11

		# LICENSE
		$rc13 = (fileExist "$($InputObject.root)/LICENSE")
		ebegin("Check project's LICENSE file ($($InputObject.root)/LICENSE)")
		eend $rc13

		# BUILD_DIR
		$rc5 = $null -ne $InputObject.buildDir
		# $rc6 = $rc5 -and (dirExist $InputObject.buildDir)
		$rc6 = ($InputObject.buildDir -ne $Global:DIRNAME)
		$rc10 = ($InputObject.buildDir -ne $InputObject.root)
		$rc9 = dirExist $InputObject.buildDir
		ebegin("Check build directory (" + $InputObject.buildDir + ")")
		eend ($rc5 -and $rc6 -and $rc9 -and $rc10)

		# RELEASES
		$rc3 = $null -ne $InputObject.releases
		$rc4 = $rc3 -and (dirExist $InputObject.releases)
		ebegin("Check releases directory (" + $InputObject.releases + ")")
		eend ($rc3 -and $rc4)

		# VERSION
		$rc7 = $null -ne $InputObject.version
		ebegin("Check version (" + $InputObject.version + ")")
		eend ($rc7)

		# BUILD_NUMBER
		$rc8 = $null -ne $InputObject.number
		ebegin("Check build number (" + $InputObject.number + ")")
		eend ($rc8)

		return ($rc1 -and $rc2 -and $rc3 -and $rc4 -and $rc5 -and $rc6 -and $rc7 -and $rc8 -and $rc9 -and $rc10 -and $rc11 -and $rc12 -and $rc13)
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}



function New-BuildDirectory {
	[CmdletBinding()][OutputType([String], [boolean])]Param (
		[Alias('Template')]
		[Parameter(Mandatory = $false,ValueFromPipeLine = $false)][string]$TemplateDirectory = $null,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)]
		[AllowNull()][hashtable]$build,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][string]$Destination
		# [Parameter(Mandatory = $false,ValueFromPipeLine = $false)][string]$DefaultInstallDir
	)
	Begin {
		eenter($MyInvocation.MyCommand)
		if (!(dirExist($Destination))) { $rc = New-Item $($Destination) -Force -ItemType Directory -ErrorAction SilentlyContinue }
	}

	Process {
		# copy template directory
		if (!([string]::IsNullOrEmpty($TemplateDirectory))) {
			if (dirExist($TemplateDirectory)) {
				ebegin "Copy Template folder"
				$rc = eexec Copy-Item $TemplateDirectory/* -Destination $Destination -Recurse -Container -Force
				eend $rc
			}
		}
		# populate build directory
		if ($null -ne $build) {
			$build.number | Set-Content "$Destination/BUILD"
			# copy files
			ebegin "Copy folders"
			# Copy-Item -Include $folders -Path "$ROOT/*" -Destination "$BUILD_DIR/" -Recurse
			foreach ($f in $Script:folders) {
				$rc = eexec Copy-Item $($build.root + "/" + $f) -Destination $($Destination) -Recurse -Container -Force
				# $rc = eexec rsync "$RSYNC_OPTIONS '$($build.root + "/" + $f)' '$($Destination + "/")'"
			}
			eend $?
			ebegin "Copy files"
			# Copy-Item -Include $files -Path "$ROOT/*.ps1" -Destination "$BUILD_DIR/"
			foreach ($f in $Script:files) {
				$rc = eexec Copy-Item $($build.root + "/" + $f) -Destination $($Destination) -Force
				# $rc = eexec rsync "$RSYNC_OPTIONS '$($build.root + "/" + $f)' '$($Destination + "/")'"
			}
			eend $?
		}

		if (dirExist($Destination)) {
			return $Destination
		}  else {
			return $false
		}
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
