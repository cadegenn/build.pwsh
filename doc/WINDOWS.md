<img align="left" width="64" height="64" src="../images/windows.png">

# Build a Windows setup

Create `build/windows` directory at the root of the project

## Target setup.exe

Create a `${PRODUCT_SHORTNAME}.nsi` file into `build/windows` directory.

A template is provided with `build.pwsh` :

```nsis
#Build Switches
# /DVERSION=[Version]

# Switches:
# /INI [IniFile] Use settings from INI file
# /S Silent

# Exit codes:
# 0: OK
# 1: Cancel
# 2: Not administrator
# -1: Error

#
# Includes
#
!include FileFunc.nsh
!include LogicLib.nsh
!include x64.nsh
!insertmacro GetParameters
!insertmacro GetOptions

#
# defines
#

#
# General Attributes
#
Unicode true
CrcCheck off # CRC check generates random errors
Icon "${BUILDDIR}\images\favicon.ico"
InstallDir "${DEFAULT_WINDOWS_INSTALL_DIR}\${PRODUCT_FULLNAME}"
Name "${PRODUCT_NAME}"
OutFile "${ROOT}\releases\${PRODUCT_SHORTNAME}-${VERSION}.${NUMBER}.exe"
RequestExecutionLevel admin

VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "Comments" "${PRODUCT_DESCRIPTION}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "LegalCopyright" "${PRODUCT_COPYRIGHT}"
VIAddVersionKey "FileDescription" "Installer"
VIAddVersionKey "FileVersion" "${VERSION}.${NUMBER}"
VIProductVersion "${VERSION}.${NUMBER}"

#
# Pages
#
Page license
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

LicenseData "${BUILDDIR}\LICENSE"

#
# Functions
#
Function Usage
  push $0
  StrCpy $0 "Switches:$\r$\n"
  StrCpy $0 "$0/S - Install ${PRODUCT_SHORTNAME} silently with no user prompt.$\r$\n"
  StrCpy $0 "$0/D=c:\path\to\install\folder - Specify an alternate installation folder. Default install dir is '${DEFAULT_WINDOWS_INSTALL_DIR}'.$\r$\n"
  MessageBox MB_OK $0
  pop $0
FunctionEnd

Function .onInit
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/?"    $R1
  ${IfNot} ${Errors}
    call Usage
    Abort
  ${EndIf}
  # use HKLM\Software and C:\Program Files, even on 64-bit computer
  # where Windows would normally redirect ourself to
  # HKLM\Software\wow6432Nodes and C:\Program Files (x86)
  ${If} ${RunningX64}
	DetailPrint "Running on a 64-bit Windows... setting RegView accordingly"
	SetRegView 64
  ${Else}
	DetailPrint "Running on a 32-bit Windows..."
  ${EndIf}
FunctionEnd

#
# Sections
#
; ; The "" makes the section hidden.
; Section "" SecUninstallPrevious
    ; Call UninstallPrevious
; SectionEnd

Section "Install"
	SetOutPath "$INSTDIR"
	
	; pack everything
	File /r /x "*.bak" "${BUILDDIR}\*"

	; write registry values
	; add/remove programs
	DetailPrint "Registering uninstallation options in add/remove programs"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_FULLNAME}"
	; if we omit *UninstallString, it will not display in Add/Remove Programs
	; WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" '"$INSTDIR\uninst.exe"'
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninst.exe" /S'
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\images\favicon.ico"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${VERSION}.${NUMBER}"
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
	WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1
	; from @url http://nsis.sourceforge.net/Add_uninstall_information_to_Add/Remove_Programs
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $0 "0x%08X" $0
	WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"

	WriteUninstaller $INSTDIR\uninst.exe
SectionEnd

Section "Uninstall"
	# use HKLM\Software and C:\Program Files, even on 64-bit computer
	# where Windows would normally redirect ourself to
	# HKLM\Software\wow6432Nodes and C:\Program Files (x86)
	${If} ${RunningX64}
		DetailPrint "Running on a 64-bit Windows... setting RegView accordingly"
		SetRegView 64
	${Else}
		DetailPrint "Running on a 32-bit Windows..."
	${EndIf}

	Delete "$INSTDIR\uninst.exe"
	RMDIR /r "$INSTDIR"
	DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
SectionEnd
```

To build the setup.exe, call `build-windows.ps1` with `-exe` parameter.

## Target a cab archive file

There is nothing more to do. `build.pwsh` will automatically build a cabinet archive file with content listed in `build.conf.ps1`. It will preserve file hierarchy.

To build the cabinet archive file, call `build-windows.ps1` with `-cab` parameter.
