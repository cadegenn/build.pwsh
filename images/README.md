# How to build icon

## from a linux machine

Tested on an Ubuntu 16.04 host :

-   install `imagemagick` and `icnsutils`
-   Open and modify pwsh_fw.xcf as needed
-   Export image as a PNG image file
-   Build icon with following command line under your favorite shell (Imagemagick must be installed)

```.sh
# convert to .ico for windows
convert favicon.png -define icon:auto-resize=128,64,48,32,16 favicon.ico
# convert to .icns for MacOS
png2icns favicon.icns favicon.png
```
