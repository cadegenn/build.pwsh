<img align="left" width="64" height="64" src="../images/Book_icon_1.png">

# `build.pwsh` documentation

## Requirements

The following files must exists in the project you want to build :

-	CHANGELOG.md : your changelog file (see [keepachanglelog.com](https://keepachangelog.com/en/1.0.0/) for a start)
-	LICENSE
-	README.md
-	VERSION : just one line with the current version of your project. No new line.

## Create build environment

You will need to add these folders / files :

-   create `build` directory at the root of the project
-   write a `build.rc` text file in this directory (see below)
-   write a `build.conf.ps1` script file in this directory (see below)

### Requirements for Debian

-   create `build/debian` directory at the root of the project

### Requirements for macOS

-   create `build/macos` directory at the root of the project

### Requirements for Windows

-   create `build\windows` directory at the root of the project
-   write a ${project}

## Files

### `build.rc`

`build.rc` contains constant strings related to project. It must contain at least the following :

```.rc
PRODUCT_CODENAME="project-code-name"
PRODUCT_FULLNAME="Project's full name"
PRODUCT_NAME="project-name"
PRODUCT_SHORTNAME="project-shortname"
PRODUCT_DESCRIPTION="Description of the project."
PRODUCT_ID="org.company.department.project"
PRODUCT_PUBLISHER="Fullname of author"
PRODUCT_PUBLISHER_EMAIL="author@company.com"
PRODUCT_WEB_SITE="https://github.com/owner/project"
PRODUCT_COPYRIGHT="GPL v3+"
PRODUCT_UNINST_ROOT_KEY="HKLM"
PRODUCT_UNINST_KEY="Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\project"
DEFAULT_LINUX_INSTALL_DIR="/opt"
#DEFAULT_MACOS_INSTALL_DIR="/Applications/Utilities"
DEFAULT_MACOS_INSTALL_DIR="/opt"
DEFAULT_WINDOWS_INSTALL_DIR="C:\\Program Files"
```

### `build.conf.ps1`

`build.conf.ps1` contains a list of files and folders that must be included in packages. The minimum is :

```.ps1
$Script:Folders = @("images", "includes", "Modules")
$Script:Files = @("CHANGELOG.md", "README.md", "LICENSE", "VERSION", "app.ps1")
```
