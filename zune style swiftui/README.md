# Zune Explorer

A lightweight macOS media browser with a dark, typographic Zune HD inspired interface. It uses the system file picker to open a folder, Quick Look thumbnails for visual previews, and Quick Look for full previews of supported media and documents.

## Run

Requires macOS 13 or later and Xcode Command Line Tools.

```sh
swift run
```

Choose **Open Folder** to browse a library. The browser lists folders and supported media in the current folder; opening a folder navigates into it. Use the category rail to filter audio, video, images, or documents.

## Controls

- Arrow keys: move selection
- Return: open selected item or folder
- Space: preview selected file
- Delete: go to parent folder
- Escape: close preview or go to parent folder
- Mouse: select; double-click to open

Supported previews are provided by macOS Quick Look. The category filters recognize common audio, video, image, and document extensions; Quick Look decides which files it can preview.
