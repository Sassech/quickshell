#!/bin/bash
# clipboard-delete.sh <id>
ID="$1"
cliphist list 2>/dev/null | grep -P "^${ID}\t" | cliphist delete 2>/dev/null
