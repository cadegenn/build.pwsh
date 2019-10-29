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
	[switch]$App,
	[switch]$Dmg,
	[switch]$Pkg,
	[switch]$All,
	[Parameter(Mandatory = $true, ValueFromPipeLine = $true)][string]$ProjectPath
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

# Handle -All
if ($All) {
	$Dmg = $true
	$App = $true
	$Pkg = $true
}

#
# COMMON CODE
# TODO merge code somewhere
#
# load common resources
$build=@{}
$build.conf = $($ProjectPath + [IO.Path]::DirectorySeparatorChar + "build" + [IO.Path]::DirectorySeparatorChar + "build.conf.ps1")
$build.rc = $($ProjectPath + [IO.Path]::DirectorySeparatorChar + "build" + [IO.Path]::DirectorySeparatorChar + "build.rc")
$build.inc  = $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + ".." + [IO.Path]::DirectorySeparatorChar + "includes" + [IO.Path]::DirectorySeparatorChar + "build.inc.ps1")
$item = Get-Item $MyInvocation.MyCommand.Definition
$build.osInc = $($Global:DIRNAME + [IO.Path]::DirectorySeparatorChar + ".." + [IO.Path]::DirectorySeparatorChar + "includes" + [IO.Path]::DirectorySeparatorChar + $($item.BaseName) + ".inc.ps1")

if (!(fileExist $($build.conf))) { efatal "build.conf.ps1 not found." }
. $build.conf
if (!(fileExist $build.inc)) { efatal "build.inc.ps1 not found." }
. $build.inc
# include build-os.inc.ps1 if exists
if (fileExist $build.osInc) {
	. $build.osInc
}

# build and check build environment
$build += Get-BuildRC -From $($build.rc)
$build += Get-BuildEnvironment -ProjectPath $ProjectPath
$rc = Approve-BuildEnvironment -InputObject $build
if ($rc -eq $False) {
	edevel($build | ConvertTo-Json)
	efatal("Environment is not functional.")
}

if (dirExist "$($build.buildDir)") { $rc = eexec Remove-Item -Recurse "'$($build.buildDir)'" -Force -ErrorAction:SilentlyContinue }
$rc = eexec New-Item "'$($build.buildDir)' -ItemType container -Force"

#
# END COMMON CODE
#

if ($Dmg) { $App = $true }

<#

 ########  ##     ## #### ##       ########        ###    ########  ########
 ##     ## ##     ##  ##  ##       ##     ##      ## ##   ##     ## ##     ##
 ##     ## ##     ##  ##  ##       ##     ##     ##   ##  ##     ## ##     ##
 ########  ##     ##  ##  ##       ##     ##    ##     ## ########  ########
 ##     ## ##     ##  ##  ##       ##     ##    ######### ##        ##
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ##        ##
 ########   #######  #### ######## ########     ##     ## ##        ##

#>
if ($App) {
	etitle("Build " + $build.PRODUCT_SHORTNAME + ".app")
	eindent
	# $layout = New-MacOSBuildLayout -build $build -SourceFolders $Script:folders -SourceFiles $Script:files -Type App
	# # eexec rsync -a --delete $layout $($build.releases + "/")
	# $rc = eexec rsync "-a --delete '$layout/' '$($build.releases)/$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).app'"
	$rc = New-BuildDirectory -Template "$($Global:DIRNAME)/macos" -Destination $build.buildDir -build $null
	$rc = New-BuildDirectory -Destination "$($build.buildDir)/Contents/MacOS" -build $build
	$build | Out-InfoPlist -Destination "$($build.buildDir)/Contents"
	Copy-Item $build.buildDir -Destination "$($build.releases)/$($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).app" -Recurse -Container -Force
	eoutdent
}

<#

 ########  ##     ## #### ##       ########     ########  ##     ##  ######
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ###   ### ##    ##
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## #### #### ##
 ########  ##     ##  ##  ##       ##     ##    ##     ## ## ### ## ##   ####
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ##     ## ##    ##
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ##     ## ##    ##
 ########   #######  #### ######## ########     ########  ##     ##  ######

#>

if ($Dmg) {
	etitle("Build " + $build.PRODUCT_SHORTNAME + ".dmg")
	eindent
	if (fileExist "'$("/tmp/" + $build.PRODUCT_SHORTNAME + ".dmg")'") { eexec Remove-Item -Recurse "'$("/tmp/" + $build.PRODUCT_SHORTNAME + ".dmg")'" -Force }
	Copy-Item $build.buildDir -Destination "$($build.releases)/$($build.PRODUCT_SHORTNAME).app" -Recurse -Container -Force
	$rc = eexec hdiutil $("create '/tmp/" + $build.PRODUCT_SHORTNAME + ".dmg' -ov -volname '" + $build.PRODUCT_SHORTNAME + "' -fs HFS+ -srcfolder '$($build.releases)/$($build.PRODUCT_SHORTNAME).app'")
	$rc = eexec hdiutil $("convert '/tmp/" + $build.PRODUCT_SHORTNAME + ".dmg' -format UDBZ -o '$($build.releases + "/" + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".dmg")'")
	$rc = $?
	Remove-Item -Recurse "$($build.releases)/$($build.PRODUCT_SHORTNAME).app" -Force
	eoutdent
}

<#

 ########  ##     ## #### ##       ########     ########  ##    ##  ######
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ##   ##  ##    ##
 ##     ## ##     ##  ##  ##       ##     ##    ##     ## ##  ##   ##
 ########  ##     ##  ##  ##       ##     ##    ########  #####    ##   ####
 ##     ## ##     ##  ##  ##       ##     ##    ##        ##  ##   ##    ##
 ##     ## ##     ##  ##  ##       ##     ##    ##        ##   ##  ##    ##
 ########   #######  #### ######## ########     ##        ##    ##  ######

#>
if ($Pkg) {
	etitle("Build " + $build.PRODUCT_SHORTNAME + ".pkg")
	eindent
	if (dirExist "$($build.buildDir)") { $rc = eexec Remove-Item -Recurse "'$($build.buildDir)'" -Force -ErrorAction:SilentlyContinue }
	$rc = New-BuildDirectory -Destination $build.buildDir -build $build
	Copy-Item "$($Global:DIRNAME)/build/build.rc" "$($build.root)/build/macos/Contents/Scripts/"
	$rc = eexec pkgbuild "--root '$($build.buildDir)' --identifier $($build.PRODUCT_ID) --version $($build.version).$($build.number) --install-location $($build.DEFAULT_MACOS_INSTALL_DIR + "/" + $build.PRODUCT_SHORTNAME) --ownership recommended --scripts $($build.root)/build/macos/Contents/Scripts '$($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".pkg")'"
	# $build | Out-DistributionXML -Destination "/tmp"
	# $rc = eexec productbuild "--distribution /tmp/Distribution.xml --resources $($Global:DIRNAME)/macos/Content/Resources --package-path '$($build.buildDir + "/")' --version $($build.version).$($build.number) '$($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".pkg")'"
	eoutdent
}

<#

 ######## ##    ## ########     ##     ## ########  ######   ######     ###     ######   ########
 ##       ###   ## ##     ##    ###   ### ##       ##    ## ##    ##   ## ##   ##    ##  ##
 ##       ####  ## ##     ##    #### #### ##       ##       ##        ##   ##  ##        ##
 ######   ## ## ## ##     ##    ## ### ## ######    ######   ######  ##     ## ##   #### ######
 ##       ##  #### ##     ##    ##     ## ##             ##       ## ######### ##    ##  ##
 ##       ##   ### ##     ##    ##     ## ##       ##    ## ##    ## ##     ## ##    ##  ##
 ######## ##    ## ########     ##     ## ########  ######   ######  ##     ##  ######   ########

#>
if ($App) {
	if (dirExist("$($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".app")")) {
		ewarn("The package have been successfully built.")
		ewarn("It is available at")
		ewarn($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".app")
	} else {
		eerror "An error occured while building $($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).app"
		$ERRORFOUND = $true
	}
}

if ($Dmg) {
	if (fileExist("$($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".dmg")")) {
		ewarn("The package have been successfully built.")
		ewarn("It is available at")
		ewarn($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".dmg")
	} else {
		eerror "An error occured while building $($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).dmg"
		$ERRORFOUND = $true
	}
}

if ($Pkg) {
	if (fileExist("$($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".pkg")")) {
		ewarn("The package have been successfully built.")
		ewarn("It is available at")
		ewarn($build.releases + [IO.Path]::DirectorySeparatorChar + $build.PRODUCT_SHORTNAME + "-" + $build.version + "." + $build.number + ".pkg")
	} else {
		eerror "An error occured while building $($build.PRODUCT_SHORTNAME)-$($build.version).$($build.number).pkg"
		$ERRORFOUND = $true
	}
}

if ($ERRORFOUND) {
	efatal("An error occured. Some package were not built.")
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
