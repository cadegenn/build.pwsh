# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## \[unreleased]

### Added

### Changed

### Removed

## \[1.1.0]

### Added

-   Travis CI/CD build debian (bionic) package.deb
-   Travis CI/CD build macOS (XCode10) package.pkg and package.dmg
-   add `-All` parameter to build all target at once

### Changed

### Removed

-   `PRODUCT_UNINST_ROOT_KEY` unused.
-   `PRODUCT_UNINST_KEY` no more needed. `build.pwsh` guesses it.

## \[1.0.0] - 2019.09.16

### Added

-   imported build system from `pwsh` project
-   correctly build debian package
-   correctly build windows setup.exe
-   correctly build windows cabinet archive file
-   AppVeyor CI/CD build windows setup.exe and archive.cab

### Changed

### Removed
