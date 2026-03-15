Usage
Listen for clipboard changes
$ wl-paste --watch cliphist store
This will listen for changes on your primary clipboard and write them to the history.
Call it once per session - for example, in your Sway config.

Select an old item
$ cliphist list | dmenu | cliphist decode | wl-copy
Bind it to something nice on your keyboard.

Delete an old item
$ cliphist list | dmenu | cliphist delete
Or else query manually: $ cliphist delete-query "secret item".

Clear database
$ cliphist wipe.