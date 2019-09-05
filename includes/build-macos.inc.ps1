<#
.SYNOPSIS
Write Info.plist

.DESCRIPTION
Output a fully-formated Info.plist file based on build configuration

.PARAMETER build
build object read from build.rc

.PARAMETER Destination
destination folder

.EXAMPLE
$build | Out-InfoPlist -Destination /tmp/project.build/Contents

.NOTES

#>

function Out-InfoPlist {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][hashtable]$build,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)][string]$Destination
	)
	Begin {
		eenter($MyInvocation.MyCommand)
		if (!(dirExist($Destination))) { New-Item $($Destination) -Force -ItemType Directory }
	}

	Process {
@"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>CFBundlePackageType</key>					<string>APPL</string>
		<key>CFBundleInfoDictionaryVersion</key>		<string>6.0</string>
		<key>CFBundleName</key>							<string>$($build.PRODUCT_SHORTNAME)</string>
		<key>CFBundleDisplayName</key>					<string>$($build.PRODUCT_FULLNAME)</string>
		<key>CFBundleExecutable</key>					<string>run-$($build.PRODUCT_SHORTNAME)-app.sh</string>
		<key>CFBundleIdentifier</key>					<string>$($build.PRODUCT_ID)</string>
		<key>CFBundleIconFile</key>						<string>$($build.PRODUCT_SHORTNAME).icns</string>
		<key>CFBundleShortVersionString</key>			<string>$($build.version)</string>
		<key>CFBundleVersion</key>						<string>$($build.version).$($build.number)</string>
		<key>CFBundleGetInfoString</key>				<string>$($build.PRODUCT_DESCRIPTION)</string>
	</dict>
</plist>
"@ | Set-Content "$($Destination + "/Info.plist")"
		return "$($Destination + "/Info.plist")"
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}

<#
.SYNOPSIS
Write Distribution.xml

.DESCRIPTION
Output a fully-formated Distribution.xml file based on build configuration

.PARAMETER build
build object read from build.rc

.PARAMETER Destination
destination folder

.OUTPUTS
Full path to Distribution.xml file

.EXAMPLE
$build | Out-DistributionXML -Destination /tmp/project.build

.NOTES

#>
function Out-DistributionXML {
	[CmdletBinding()]Param (
		[Parameter(Mandatory = $true,ValueFromPipeLine = $true)][hashtable]$build,
		[Parameter(Mandatory = $true,ValueFromPipeLine = $false)][string]$Destination
	)
	Begin {
		eenter($MyInvocation.MyCommand)
		if (!(dirExist($Destination))) { New-Item $($Destination) -Force -ItemType Directory }
	}

	Process {
@"
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<installer-gui-script minSpecVersion="1">
    <title>$($build.PRODUCT_FULLNAME)</title>
    <organization>fr.univ-lr</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true" />
    <!-- Define documents displayed at various steps -->
    <welcome    file="welcome.html"    mime-type="text/html" />
    <license    file="LICENSE"         mime-type="text/plain" />
    <conclusion file="conclusion.html" mime-type="text/html" />
    <!-- List all component packages -->
    <pkg-ref id="$($build.PRODUCT_ID)"
             version="0"
             auth="root">/tmp/$($build.PRODUCT_SHORTNAME).pkg</pkg-ref>
    <!-- List them again here. They can now be organized
         as a hierarchy if you want. -->
    <choices-outline>
        <line choice="$($build.PRODUCT_ID)"/>
    </choices-outline>
    <!-- Define each choice above -->
    <choice
        id="$($build.PRODUCT_ID)"
        visible="false"
        title="$($build.PRODUCT_SHORTNAME) daemon"
        description="$($build.PRODUCT_SHORTNAME) daemon"
        start_selected="true">
      <pkg-ref id="$($build.PRODUCT_ID)"/>
    </choice>
</installer-gui-script>
"@ | Set-Content "$($Destination)/Distribution.xml"
		return "$($Destination)/Distribution.xml"
	}

	End {
		eleave($MyInvocation.MyCommand)
	}
}
