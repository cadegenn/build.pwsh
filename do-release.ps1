<#

	.SYNOPSIS
	Trigger a release os Tiny {PowerShell} Framework

	.DESCRIPTION
	This script automate everything to get a new release.
	Its workflow is :
	- checks: git, CHANGELOG, appveyor, travis
	- commit everything
	- start a new git flow release
	- remove debugging messages in all scripts
	- commit everything
	- finish git flow release
	- push everything <-- this will trigger a build in various CI online services
	- get back debugging messages

	.PARAMETER h
	display help screen. Use Get-Help instead.

	.PARAMETER d
	debug mode

	.PARAMETER dev
	devel mode

	.PARAMETER ask
	ask for each action

	.PARAMETER log
	log calls to e*() functions into specified logfile.
	If used in conjunction with -trace, it will use PowerShell Start-Transcript to log everything, including output of commands.
	Useful if you can't see the output of script for whatever reason. In this case, Write-ToLog() is deactivated.

	.NOTES
	Author: Charles-Antoine Degennes <cadegenn@gmail.com>

	.EXAMPLE
	./do-release.ps1 -d -dev -api .

	.LINK
		https://github.com/cadegenn/pwsh_fw
#>

[CmdletBinding(DefaultParameterSetName = "DRAFT")]Param(
	[switch]$h = $false,
	[switch]$v = $false,
	[switch]$d = $false,
	[switch]$dev = $false,
	[switch]$trace = $false,
	[switch]$ask = $false,
	[ValidateScript({
		Test-Path -Path $_ -PathType container
	})][string]$api = $null,
	# if you want each invocation to overwrite logfile
	[ValidateScript({New-Item $_ -ItemType file -force})][string]$log = "",
	# if you want each invocation to NOT overwrite logfile
	# [ValidateScript({
	# 	New-Item $_ -ItemType file -ErrorAction:SilentlyContinue
	# 	Test-Path -Path $_ -PathType leaf
	# })][string]$log = "",
	# [ValidateScript({
	# 	Test-Path -Path $_ -PathType leaf
	# })][string]$configFile = "",
	[switch]$Force = $false
	# [Parameter(ParameterSetName = "DRAFT", Mandatory = $true)][switch]$Draft,
	# [Parameter(ParameterSetName = "PRERELEASE", Mandatory = $true)][switch]$Prerelease,
	# [Parameter(ParameterSetName = "RELEASE", Mandatory = $true)][switch]$Release
)



$Global:DIRNAME = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Global:BASENAME = Split-Path -Leaf $MyInvocation.MyCommand.Definition
# search for real PWSHFW_PATH
switch ($PSVersionTable.PSVersion.Major) {
	{$_ -le 4} {
		$Global:PWSHFW_PATH = (Get-ItemProperty 'HKLM:/SOFTWARE/pwshfw' 'InstallDir' -ErrorAction:SilentlyContinue).InstallDir
	}
	5 {
		$Global:PWSHFW_PATH = Get-ItemPropertyValue 'HKLM:/SOFTWARE/pwshfw' 'InstallDir' -ErrorAction:SilentlyContinue
	}
	6 {
		switch ($PSVersionTable.Platform) {
			"Unix" {
				# on Linux
				$fileExist = Test-Path -Path /etc/profile.d/pwshfw.ps1
				if ($fileExist) {
					. /etc/profile.d/pwshfw.ps1
				}
				# on macOS
				# installed Pkg
				$fileExist = Test-Path -Path /etc/defaults/pwshfw.ps1
				if ($fileExist) {
					. /etc/defaults/pwshfw.ps1
				} else {
					# installed App
					if (Test-Path -Path "/Applications/Tiny {PowerShell} Framework.app/Contents/MacOS") { [string]$Global:PWSHFW_PATH = "/Applications/pwshfw.app/Contents/MacOS" }
					if (Test-Path -Path "/Applications/Utilities/Tiny {PowerShell} Framework.app/Contents/MacOS") { [string]$Global:PWSHFW_PATH = "/Applications/Utilities/Tiny {PowerShell} Framework.app/Contents/MacOS" }
				}
			}
			"Win32NT" {
				$Global:PWSHFW_PATH = Get-ItemPropertyValue 'HKLM:/SOFTWARE/pwshfw' 'InstallDir' -ErrorAction:SilentlyContinue
			}
		}
	}
}
# if -api is specified, override PWSHFW_PATH, but check if provided path contains a minimum set of PWSHFW
if ($api) {
	$rc1 = Test-Path -Path $($api + "/lib/api.psm1") -PathType Leaf
	if ($rc1) {
		[string]$Global:PWSHFW_PATH = Resolve-Path $api
	} else {
		Write-Error -Message "You ask to use a custom path ('$api') to load PWSHFW but we can't find it there."
		exit
	}
}
# if PwShFw is not installed, abort and quit
if ($null -eq $Global:PWSHFW_PATH) { Write-Error -Message "Tiny {PowerShell} Framework not found. Aborting."; exit }
Import-Module -DisableNameChecking $($Global:PWSHFW_PATH + "/lib/api.psd1") -Force:$Force
# Write-Output ">>>> $($MyInvocation.MyCommand.Definition) <<<<"
Write-Output $(">>>> $DIRNAME" + [IO.Path]::DirectorySeparatorChar + "$BASENAME <<<<")
Write-Output "Using api from '$($Global:PWSHFW_PATH)'"
Set-PSModulePath
if (dirExist $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "Modules")) { Add-PSModulePath -Path $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "Modules") }

$Global:VERBOSE = $v
$Global:DEBUG = $d
$Global:DEVEL = $dev
$Global:TRACE = $trace
$Global:ASK = $ask
$Global:LOG = $log
$modules = @()

if ($h) {
	Get-Help $MyInvocation.MyCommand.Definition
	Exit
}

# keep the order as-is please !
if ($ASK)   { Set-PSDebug -Step }
if ($TRACE) {
	# Set-PSDebug -Trace 1
	$Global:DEVEL = $true
}
if ($DEVEL) {
	$Global:DEBUG = $true;
}
if ($DEBUG) {
	$DebugPreference="Continue"
	$Global:VERBOSE = $true
}
if ($VERBOSE) {
	$VerbosePreference="Continue"
}

if ($log) {
	if ($TRACE) {
		Start-Transcript -Path $log
	# } else {
	# 	# add -Append:$false to overwrite logfile
	# 	# Write-ToLogFile -Message "Initialize log" -Append:$false
	# 	Write-ToLogFile -Message "Initialize log"
	}
	$modules += "PwSh.Log"
}

# write-output "Language mode :"
# $ExecutionContext.SessionState.LanguageMode

#
# Load Everything
#
everbose("Loading modules")
# $modules += "PsIni"
# $modules += "PwSh.ConfigFile"
# $modules += "Microsoft.PowerShell.Archive"
# USER MODULES HERE

$ERRORFOUND = $false
ForEach ($m in $modules) {
	$rc = Load-Module -Name $m -Force:$Force
	if ($rc -eq $false) { $ERRORFOUND = $true }
}
if ($ERRORFOUND) { efatal("At least one module could not be loaded.") }

# # Support for configuration file
# # At this time, supported configuration files are
# # .txt	containing a list of "key = value" pair
# # .ini	containing a list of "key = value" pair under the [General] section
# # For the moment, you have to bind your variables one-by-one
# if (($configFile -ne $null) -and ($configFile -ne "")) {
# 	# if your config file is a flat .txt file containing only key=value pair
# 	$conf = ConvertFrom-ConfigFile $configFile
# 	# then bind your variables
# 	$TestString = [System.String]$conf.TestString
# 	$TestBool = [System.Boolean](Resolve-Boolean $conf.TestBool)
# 	$TestSwitch = [switch](Resolve-Boolean $conf.TestSwitch)
# 	$TestInt = [int]$conf.TestInt
# 	# debug them if you want
# 	edevel("TestString = " + $TestString)
# 	edevel("TestBool = " + $TestBool)
# 	edevel("TestSwitch = " + $TestSwitch)
# 	edevel("TestInt = " + $TestInt)
# 	# if your config file is an .ini file with a [General] section
# 	$ini = (ConvertFrom-ConfigFile "./config.ini")['General']
# 	# $ini = ConvertFrom-ConfigFile "./config.ini"
# 	$ini
# 	$TestString = [System.String]$ini.TestString
# 	$TestBool = [System.Boolean](Resolve-Boolean $ini.TestBool)
# 	$TestSwitch = [switch](Resolve-Boolean $ini.TestSwitch)
# 	$TestInt = [int]$ini.TestInt
# 	# debug them if you want
# 	edevel("TestString = " + $TestString)
# 	edevel("TestBool = " + $TestBool)
# 	edevel("TestSwitch = " + $TestSwitch)
# 	edevel("TestInt = " + $TestInt)

# }

#############################
## YOUR SCRIPT BEGINS HERE ##
#############################

$ErrorActionPreference = "Stop"
function Set-AppVeyorConfig {
	[CmdletBinding(SupportsShouldProcess = $true)]Param (
		[Parameter(Mandatory = $true, ValueFromPipeLine = $true)][string]$File,
		[Parameter(Mandatory = $true, ValueFromPipeLine = $false)][string]$Version
	)
	Begin {
		eenter($Script:NS + '\' + $MyInvocation.MyCommand)
	}

	Process {
		if ($PSCmdlet.ShouldProcess($File, "Set version")) {
			(Get-Content $File) -replace "^version: .*", "version: $TAG.{build}" | Out-File $File
		} else {
			Write-Output "Write version $Version to file $File"
		}
		return $?
	}

	End {
		eleave($Script:NS + '\' + $MyInvocation.MyCommand)
	}
}

function Set-TravisConfig {
	[CmdletBinding(SupportsShouldProcess = $true)]Param (
		[Parameter(Mandatory = $true, ValueFromPipeLine = $true)][string]$File,
		[Parameter(Mandatory = $true, ValueFromPipeLine = $false)][string]$Version
	)
	Begin {
		eenter($Script:NS + '\' + $MyInvocation.MyCommand)
	}

	Process {
		# nothing to do for the moment
		if ($PSCmdlet.ShouldProcess($File, "Set version")) {
		} else {
			Write-Output "Write version $Version to file $File"
		}
		return $true
	}

	End {
		eleave($Script:NS + '\' + $MyInvocation.MyCommand)
	}
}

function Set-GitlabConfig {
	[CmdletBinding(SupportsShouldProcess = $true)]Param (
		[Parameter(Mandatory = $true, ValueFromPipeLine = $true)][string]$File,
		[Parameter(Mandatory = $true, ValueFromPipeLine = $false)][string]$Version
	)
	Begin {
		eenter($Script:NS + '\' + $MyInvocation.MyCommand)
	}

	Process {
		# nothing to do for the moment
		if ($PSCmdlet.ShouldProcess($File, "Set version")) {
		} else {
			Write-Output "Write version $Version to file $File"
		}
		return $true
	}

	End {
		eleave($Script:NS + '\' + $MyInvocation.MyCommand)
	}
}

# WORKFLOW

# Force DEBUG and DEVEL as it may be dangerous to go blind
$Global:DEBUG = $true
$Global:DEVEL = $true

	# some checks
	$rc = eexec git status
	if ($rc -eq $False) {
		ewarn("'git status' did not return well. Either install git, or make it available in PATH environment variable.")
		efatal("Something went wrong with 'git status' command.")
	}

	# README is present
	$README = Resolve-Path "$Global:DIRNAME/README.md"
	if (-not(fileExist $README)) { efatal("This project lacks a README.md file.") }
	edevel("README = " + $README)
	# CHANGELOG is present
	$CHANGELOG = Resolve-Path "$Global:DIRNAME/CHANGELOG.md"
	if (-not(fileExist $CHANGELOG)) { efatal("This project lacks a CHANGELOG.md file. See https://keepachangelog.com/en/1.0.0/ to begin.") }
	edevel("CHANGELOG = " + $CHANGELOG)
	# VERSION is present
	$VERSION = Get-Content (Resolve-Path "$Global:DIRNAME/VERSION")
	if ($null -eq $VERSION) { efatal("This project lacks a VERSION file.") }
	edevel("VERSION = " + $VERSION)
	# current branch
	$CURRENT_BRANCH = ((git branch | Where-Object { $_ -match "^\*" }) -split ' ')[1]

	# edevel("CURRENT_BRANCH = " + $CURRENT_BRANCH)
	# edevel("APPVEYOR_RC = " + $APPVEYOR_RC)
	# edevel("APPVEYOR_YML = " + $APPVEYOR_YML)
	# edevel("TRAVIS_YML = " + $TRAVIS_YML)
	# edevel("ACCOUNTNAME = " + $ACCOUNTNAME)
	# edevel("PROJECT = " + $PROJECT)
	# edevel("APIKEY = " + $APIKEY)
	# edevel

	# compute release number
	# parse CHANGELOG.md
	$TAG = Get-Content $CHANGELOG | Select-String -Pattern "^##\s\\\[([\d\.]*)\]" | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1
	if ($null -eq $TAG ) { efatal("TAG is empty.") }
	# add current date to CHANGELOG
	(Get-Content $CHANGELOG) -replace "^##\s\\\[$($TAG)\\\].*", "## \[$($TAG)\] - $(Get-Date -UFormat "%Y.%m.%d")" | Out-File $CHANGELOG
	edevel("TAG = " + $TAG)

	if ($VERSION -ne $TAG) {
		efatal ("VERSION ($VERSION) and TAG ($TAG) does not match. Have you filled an entry in CHANGELOG ?")
	}

	# appveyor.yml config file
	$APPVEYOR_YML = Resolve-Path "$Global:DIRNAME/appveyor.yml" -ErrorAction SilentlyContinue
	if (fileExist $APPVEYOR_YML) { Set-AppVeyorConfig -File $APPVEYOR_YML -Version $TAG }
	# travis.yml config file
	$TRAVIS_YML = Resolve-Path "$Global:DIRNAME/.travis.yml" -ErrorAction SilentlyContinue
	if (fileExist $TRAVIS_YML) { Set-TravisConfig -File $TRAVIS_YML -Version $TAG }
	# gitlab.yml config file
	$GITLAB_YML = Resolve-Path "$Global:DIRNAME/.gitlab-ci.yml" -ErrorAction SilentlyContinue
	if (fileExist $GITLAB_YML) { Set-GitlabConfig -File $GITLAB_YML -Version $TAG }

	# get changelog about release number
	# parse CHANGELOG.md
	# below command line explained :
	# Get-Content $CHANGELOG | Select-String -NotMatch -Pattern '(?ms)^$'		--> get CHANGELOG content without empty lines
	# -replace "^## ", "`n##  "													--> add empty lines only before h2 title level (## in markdown). This way, we got proper paragraph from ## tag to next empty line
	$TMP = [system.io.path]::GetTempPath()
	(Get-Content $CHANGELOG | Select-String -NotMatch -Pattern '(?ms)^$') -replace "^## ", "`n##  " | Out-File $TMP/changelog.tmp
	# To extract correct §, we need to read the file with -Raw parameter
	# (?ms) sets regex options m (treats ^ and $ as line anchors) and s (makes . match \n (newlines) too`.
	# ^## .*? matches any line starting with ##  and any subsequent characters *non-greedily* (non-greedy is '.*?' set of characters at the end of pattern).
	# -AllMatches to get... well... all mathes
	# [1] because the last changelog is allways [1] from array of matches. [0] is ## [Unreleased]
	$MESSAGES = Get-Content -Raw $TMP/changelog.tmp | Select-String -Pattern '(?ms)^## .*?^$' -AllMatches
	edevel("MESSAGES = " + $MESSAGES.Matches[1])
	# check if MESSAGE match VERSION number
	if (-not($MESSAGES.Matches[1] -match $TAG)) { efatal("The last CHANGELOG entry do not seem to match last TAG version number.")}
	# reduce title level to render more readable in github release page
	$MESSAGE = ($MESSAGES.Matches[1]) -replace "# ", "## " -replace "'", "``"
	edevel("MESSAGE = " + $MESSAGE)

# switch to branch develop
# $rc = eexec git checkout develop

# remove *.bak files
Get-ChildItem "*.bak" -Recurse | remove-item -Confirm:$false

# commit everything
# $rc = eexec git commit -am "'$MESSAGE'"
$rc = eexec git commit -am "'general commit before tag $TAG'"
# if ($rc -eq $false) { efatal("Unable to commit changes.") }

# start a new release
if (git branch | where-object { $_ -eq "  release/v$TAG" }) {
	$rc = eexec git checkout release/v$TAG
	if ($rc -eq $false) { efatal("Release branch 'release/v$TAG' found, but unable to move into it. Please clean current branch before doing a release.") }
	$rc = eexec git "merge develop -m '$($TAG): merge from develop'"
	if ($rc -eq $false) { efatal("Unable to merge from develop branch. Are there any conflict ?") }
}
if ($CURRENT_BRANCH -eq "release/v$TAG") {
	ewarn("We already are in release branch. Is something went wrong before ?")
} else {
	$rc = eexec git flow release start "v$TAG"
	if ($rc -eq $false) { efatal("Unable to create new release 'release/v$TAG'.") }
}

# update modules manifests
everbose "Update modules manifests"
foreach ($psd in (get-childitem -path "$($Global:DIRNAME)/lib","$($Global:DIRNAME)/Dictionaries","$($Global:DIRNAME)/Includes","$($Global:DIRNAME)/Modules" "*.psd1" -recurse)) {
	# eenter $psd.Name
	Import-Module $psd.FullName -force -DisableNameChecking
	$rc = $?
	# foreach ($cmd in (Get-Command -Module $psd.BaseName)) {
	# 	edebug $cmd
	# }
	if ($rc -eq $true) {
		$module = Get-Module -ListAvailable -FullyQualifiedName $psd.FullName
		edevel ("Functions list :")
		$functionsList = Get-Command -Module $module.Name
		$functionsList.Name | ForEach-Object { edevel $_}
		edevel ("Aliases list :")
		$aliasesList = Get-Alias | Where-Object { $_.ModuleName -eq $module.Name }
		$aliasesList.Name | ForEach-Object { edevel $_}
		if ($aliasesList.count -eq 0) { $aliasesList = '' }

		Update-ModuleManifest -Path $psd.FullName -FunctionsToExport $functionsList -CmdletsToExport '' -AliasesToExport $aliasesList -ModuleVersion $TAG
		# trim triling spaces
		$content = Get-Content $psd.FullName
		$content | ForEach-Object {$_.TrimEnd()} | Set-Content $psd.FullName
	}
	# eoutdent
}
eexec git commit -am "'Update all module manifests'"

# trim triling spaces
foreach ($f in (Get-ChildItem -Path "$($Global:DIRNAME)" -include "*.ps1", "*.psd1", "*.psm1", "*.md" -recurse)) {
	$content = Get-Content $f
	$content | ForEach-Object {$_.TrimEnd()} | Set-Content $f
}
$rc = eexec -exe git -args "diff --exit-code" -AsInt
if ($rc -ne 0) {
	$rc = eexec git commit -am "'Remove trailing spaces'"
	if ($rc -eq $false) { efatal("Unable to commit changes.") }
	$rc = eexec git push --set-upstream origin release/v${TAG}
	if ($rc -eq $false) { efatal("Unable to push upstream.") }
}

# comment every edebug(), edevel(), eenter() and eeleave() calls in every single file
everbose "Comment out debug messages"
ForEach ($f in (Get-ChildItem -Path $Global:DIRNAME -Recurse -Include "*.psm1")) {
	(Get-Content $f.FullName) -replace "^(\s+)edebug", '$1# edebug' | Set-Content -Encoding UTF8 $f.FullName
	(Get-Content $f.FullName) -replace "^(\s+)edevel", '$1# edevel' | Set-Content -Encoding UTF8 $f.FullName
	(Get-Content $f.FullName) -replace "^(\s+)eenter", '$1# eenter' | Set-Content -Encoding UTF8 $f.FullName
	(Get-Content $f.FullName) -replace "^(\s+)eleave", '$1# eleave' | Set-Content -Encoding UTF8 $f.FullName
}

# change branch to master for README's badges
everbose "Change branch reference in README"
(Get-Content $README) -replace '\bdevelop\b', 'master' | Out-File $README

# commit everything
everbose "Commit everything"
$rc = eexec -exe git -args "diff --exit-code" -AsInt
if ($rc -ne 0) {
	$rc = eexec git commit -am "'removed debugging messages'"
	if ($rc -eq $false) { efatal("Unable to commit changes.") }
	$rc = eexec git push --set-upstream origin release/v${TAG}
	if ($rc -eq $false) { efatal("Unable to push upstream.") }
}

# push (it will generate a draft release by appveyor/travis)
# $rc = eexec git tag "v$CURRENT_RELEASE_TAG"
# invoke git flow release
$rc = eexec -exe git "flow release finish -m '$MESSAGE' 'v$TAG'"
if ($rc -eq $false) { efatal("Unable to finish release.") }
# $rc = eexec git push origin --tags
# @see @url https://stackoverflow.com/questions/3745135/push-git-commits-tags-simultaneously
$rc = eexec git push --follow-tags
if ($rc -eq $false) { efatal("Unable to push tags.") }
# push master branch
eexec git checkout master
$rc = eexec git push
if ($rc -eq $false) { efatal("Unable to push master branch.") }
# switch bask to branch develop
eexec git checkout develop

# # uncomment every edebug(), edevel(), eenter() and eeleave() calls in every single file
# ForEach ($f in (Get-ChildItem -Path $Global:DIRNAME -Recurse -Include "*.psm1")) {
# 	(Get-Content $f.FullName) -replace "^(\s+)# edebug", '$1edebug' | Set-Content -Encoding UTF8 $f.FullName
# 	(Get-Content $f.FullName) -replace "^(\s+)# edevel", '$1edevel' | Set-Content -Encoding UTF8 $f.FullName
# 	(Get-Content $f.FullName) -replace "^(\s+)# eenter", '$1eenter' | Set-Content -Encoding UTF8 $f.FullName
# 	(Get-Content $f.FullName) -replace "^(\s+)# eleave", '$1eleave' | Set-Content -Encoding UTF8 $f.FullName
# }

# $rc = eexec -exe git -args "diff --exit-code" -AsInt
# if ($rc -ne 0) {
# 	$rc = eexec git commit -am "'get back debugging messages'"
# 	if ($rc -eq $false) { efatal("Unable to commit changes.") }
# 	$rc = eexec git push
# 	if ($rc -eq $false) { efatal("Unable to push upstream.") }
# }

# change branch to master for README's badges
everbose "Change branch reference in README"
(Get-Content $README) -replace '\bmaster\b', 'develop' | Out-File $README

$rc = eexec -exe git -args "diff --exit-code" -AsInt
if ($rc -ne 0) {
	$rc = eexec git commit -am "'update branch name'"
	if ($rc -eq $false) { efatal("Unable to commit changes.") }
	$rc = eexec git push
	if ($rc -eq $false) { efatal("Unable to push upstream.") }
}

#############################
## YOUR SCRIPT ENDS   HERE ##
#############################

if ($log) {
	if ($TRACE) {
		Stop-Transcript
	} else {
		Write-ToLogFile -Message "------------------------------------------"
	}
}

# reinit values
$Global:DebugPreference = "SilentlyContinue"
Set-PSDebug -Off
$Script:indent = ""
