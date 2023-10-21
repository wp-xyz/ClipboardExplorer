# ClipboardExplorer
![grafik](https://github.com/wp-xyz/ClipboardExplorer/assets/30792460/a62ae806-9826-4351-8ac6-14591c36ebf0)

ClipboardExplorer is a small tool to inspect the various formats which currently are loaded in the clipboard. Click the "Refresh" button to update the display when new content has been copied to the clipboard.

- List of all formats found
- Hexadecimal view of the binary content of each format
- Text view of text formats, RTF if available
- Display of images detected

# Compilation
* Lazarus v2.0.12/FPC 3.2.0 or newer (older versions might work as well, not tested))
* Requires installation of the richmemo package (https://github.com/skalogryz/richmemo)
* Works on Windows, Linux (qt4/5/6), Mac (cocoa)
