<#

	.SYNOPSIS
	Skeleton script for my tiny powershell framework

	.DESCRIPTION
	Tiny powershell framework.

	To ease programming here is debugging levels :
	    -v :     display VERBOSE level messages
		-d :	 display DEBUG level messages
		-dev :   display DEVEL level messages (including DEBUG ones)
		-trace : display the line of script currently executed as well as DEVEL and DEBUG level messages
		-ask :   ask user before each execution

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

	.LINK
		https://github.com/cadegenn/pwsh_fw
#>

[CmdletBinding()]Param(
	[switch]$h = $false,
	[switch]$v = $false,
	[switch]$d = $false,
	[switch]$dev = $false,
	[switch]$trace = $false,
	[switch]$ask = $false,
	[string]$api = $null,
	# if you want each invocation to overwrite logfile
	#[ValidateScript({New-Item $_ -ItemType file -force})][string]$log = ""
	# if you want each invocation to NOT overwrite logfile
	[ValidateScript({
		New-Item $_ -ItemType file -ErrorAction:SilentlyContinue
		Test-Path -Path $_ -PathType leaf
	})][string]$log = "",
	[ValidateScript({
		Test-Path -Path $_ -PathType leaf
	})][string]$configFile = "",
	[switch]$Force = $false,
	[Alias('Setup')]
	[switch]$Exe = $true,
	[switch]$Cab = $true
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
		}
	}
}
# if -api is specified, override PWSHFW_PATH, but check if provided path contains a minimum set of PWSHFW
if ($api) {
	$rc1 = Test-Path -Path $($api + "/lib/api.psm1") -PathType Leaf
	if ($rc1) {
		[string]$Global:PWSHFW_PATH = Resolve-Path $api
	} else {
		efatal("You ask to use a custom path ('" + $api + "') to load PWSHFW but we can't find it there.")
	}
}
# if PwShFw is not installed, abort and quit
if ($null -eq $Global:PWSHFW_PATH) { Write-Error "Tiny {PowerShell} Framework not found. Aborting."; exit }
Import-Module -DisableNameChecking $($Global:PWSHFW_PATH + "/lib/api.psd1") -Force:$Force
edevel(">>>> " + $MyInvocation.MyCommand.Definition + " <<<<")
edevel("Using api from '" + $Global:PWSHFW_PATH + "'")
$env:PSModulePath = $($Global:PWSHFW_PATH + [IO.Path]::DirectorySeparatorChar + "Modules") + [IO.Path]::PathSeparator + $env:PSModulePath

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

#
# Load Everything
#
everbose("Loading modules")
if (dirExist($($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "Modules"))) {
    $env:PSModulePath = $env:PSModulePath -replace (([IO.Path]::PathSeparator + $Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "Modules") -replace "\\", "\\")
    $env:PSModulePath = $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "Modules") + [IO.Path]::PathSeparator + $env:PSModulePath
    # edevel("env:PSModulePath = " + $env:PSModulePath)
}
# $modules += "PsIni"
# $modules += "PwSh.ConfigFile"
# $modules += "Microsoft.PowerShell.Archive"
# USER MODULES HERE
$modules += "PwSh.OS"

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

# load common resources
if (!(fileExist $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "build.conf.ps1"))) { efatal "build.conf.ps1 not found." }
. $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "build.conf.ps1")
if (!(fileExist $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "build.inc.ps1"))) { efatal "build.inc.ps1 not found." }
. $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "build.inc.ps1")
# include build-os.inc.ps1 if exists
$item = Get-Item $MyInvocation.MyCommand.Definition
if (fileExist $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + $($item.BaseName) + ".inc.ps1")) {
	. $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + $($item.BaseName) + ".inc.ps1")
}

# build and check build environment
$build = Get-BuildRC -From $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "build.rc")
$build += Get-BuildEnvironment
$rc = Approve-BuildEnvironment -InputObject $build
edevel($build | ConvertTo-Json)
if ($rc -eq $False) {
	efatal("Environment is not functional.")
}

$rc = New-BuildDirectory -Template "$($Global:DIRNAME)/windows/template" -Destination $build.buildDir -build $null
$rc = New-BuildDirectory -Destination $build.buildDir -build $build

[uint16]$debugLevel = 0
if ($Global:VERBOSE) { $debugLevel = 2 }
if ($Global:DEBUG) { $debugLevel = 3 }
if ($Global:DEVEL) { $debugLevel = 4 }

if ($Exe) {
	ebegin("Building setup " + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".exe")
	# create include file for NSIS
	$build | Out-NullSoftInstallerScriptHeaderFile -FileName $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + "windows" + [IO.Path]::DirectorySeparatorChar + "header.nsi")

	# discover where is nsis.exe
	if (fileExist($(${env:ProgramFiles(x86)} + "\NSIS\makensis.exe"))) { $MAKENSIS = $(${env:ProgramFiles(x86)} + "\NSIS\makensis.exe") }
	if (fileExist($(${env:ProgramFiles} + "\NSIS\makensis.exe"))) { $MAKENSIS = $(${env:ProgramFiles} + "\NSIS\makensis.exe") }
	if (!$MAKENSIS) { eerror("makensis.exe not found") }
	edevel("MAKENSIS = " + $MAKENSIS)

	$rc = eexec -exe "$MAKENSIS" "/V$debugLevel /INPUTCHARSET UTF8 /OUTPUTCHARSET UTF8 '$($Global:DIRNAME)\windows\header.nsi' '$($Global:DIRNAME)\windows\$($build.PRODUCT_SHORTNAME).nsi'"
	eend $rc
}

if ($Cab) {
	ebegin("Building cabinet " + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".cab")
	$ddf = $build | Out-CabinetDefinitionFile -Destination "$($build.buildDir)"
	if (!(fileExist $ddf)) { efatal("Cannot find cabinet definition file at '$ddf'") }
	
	# $rc2 = eexec -exe makecab.exe /F "$($build.root)\build\windows\$($build.PRODUCT_SHORTNAME).ddf" /D SourceDir=$($build.root) /D CabinetNameTemplate=$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).cab /D DiskDirectoryTemplate=$($build.root)\releases
	$rc = eexec -exe makecab.exe /F "$($build.buildDir + [IO.Path]::DirectorySeparatorChar + "$($build.PRODUCT_SHORTNAME).ddf")"
	eend $rc
}

# summary
$ERRORFOUND = $false
if ($Exe) {
	if (fileExist("$($build.releases)\$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).exe")) {
		ewarn("The setup package is available at")
		ewarn("$($build.releases)\$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).exe")
	} else {
		eerror("Failed to build setup package.")
		$ERRORFOUND = $true
	}
}

if ($Cab) {
	if (fileExist("$($build.releases)\$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).cab")) {
		ewarn("The cabinet archive is available at")
		ewarn("$($build.releases)\$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).cab")
	} else {
		eerror("Failed to build cabinet archive.")
		$ERRORFOUND = $true
	}
}

if ($ERRORFOUND) {
	efatal("An error occured. Either .exe or .cab package were not build.")
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