#!/usr/bin/env python3
import sys
import os
import subprocess
import json

result = subprocess.run(['cliphist', 'list'], capture_output=True, text=True)
entries = []

for line in result.stdout.splitlines():
    if '\t' not in line:
        continue
    tab = line.index('\t')
    entry_id = line[:tab]
    preview = line[tab+1:]
    is_bin = preview.startswith('[[ binary')
    thumb = ''

    if is_bin and 'png' in preview:
        thumb_path = f'/tmp/qs-clip-{entry_id}.png'
        if not os.path.exists(thumb_path):
            raw_path = f'/tmp/qs-raw-{entry_id}'
            try:
                decoded = subprocess.run(
                    ['bash', '-c',
                        f'cliphist list | grep -P "^{entry_id}\\t" | cliphist decode'],
                    capture_output=True
                )
                if decoded.returncode == 0 and len(decoded.stdout) > 50:
                    with open(raw_path, 'wb') as f:
                        f.write(decoded.stdout)
                    subprocess.run(
                        ['magick', raw_path, '-thumbnail', '72x72^',
                         '-gravity', 'center', '-extent', '72x72', thumb_path],
                        capture_output=True
                    )
                    if os.path.exists(raw_path):
                        os.unlink(raw_path)
            except Exception:
                pass
        if os.path.exists(thumb_path):
            thumb = thumb_path

    entries.append({'id': entry_id, 'preview': preview,
                   'isBinary': is_bin, 'thumb': thumb})

print(json.dumps(entries))
