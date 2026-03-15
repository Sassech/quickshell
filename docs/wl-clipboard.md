wl-clipboard: Wayland clipboard utilities
This project implements two command-line Wayland clipboard utilities, wl-copy and wl-paste, that let you easily copy data between the clipboard and Unix pipes, sockets, files and so on.

# Copy a simple text message:
$ wl-copy Hello world!

# Copy the list of files in ~/Downloads:
$ ls ~/Downloads | wl-copy

# Copy an image:
$ wl-copy < ~/Pictures/photo.png

# Copy the previous command:
$ wl-copy "!!"

# Paste to a file:
$ wl-paste > clipboard.txt

# Sort clipboard contents:
$ wl-paste | sort | wl-copy

# Upload clipboard contents to a pastebin on each change:
$ wl-paste --watch nc paste.example.org 5555