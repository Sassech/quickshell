package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// runWallpaperMulti procesa varias carpetas en UN SOLO proceso, generando los
// thumbnails faltantes con un worker pool acotado (evita saturar CPU/memoria
// con decenas de magick/ffmpeg simultáneos cuando hay varias carpetas con
// hasta 60 imágenes cada una). Salida: JSON {folder: items[]}, usando como
// clave el folder ORIGINAL (sin expandir el ~) para que QML matchee contra
// el path que ya tiene guardado en _tabs.
func runWallpaperMulti(folders []string) int {
	if len(folders) == 0 {
		fmt.Fprintln(os.Stderr, "wallpaper-multi: faltan carpetas")
		return 1
	}
	_ = os.MkdirAll(thumbDir, 0o755)
	mpv := hasMpvpaper()

	type job struct {
		fi, pi int
		path   string
	}

	perFolder := make([][]string, len(folders))
	for i, f := range folders {
		expanded := expandTilde(f)
		imgs := collectWallpaperFiles(expanded, mpv)
		if len(imgs) > 60 {
			imgs = imgs[:60]
		}
		perFolder[i] = imgs
	}

	results := make([][]wallpaperItem, len(folders))
	var jobs []job
	for fi, paths := range perFolder {
		results[fi] = make([]wallpaperItem, len(paths))
		for pi, p := range paths {
			results[fi][pi] = wallpaperItem{Path: p, Name: filepath.Base(p), Type: wallpaperItemType(p)}
			jobs = append(jobs, job{fi, pi, p})
		}
	}

	// Worker pool acotado via parallelRun: min(4, NumCPU). No escala con
	// folders*60 — evita lanzar decenas de magick/ffmpeg simultáneos que
	// saturarían CPU/memoria.
	parallelRun(len(jobs), func(k int) {
		j := jobs[k]
		results[j.fi][j.pi].Thumb = makeWallpaperThumb(j.path)
	})

	out := make(map[string][]wallpaperItem, len(folders))
	for i, f := range folders {
		out[f] = results[i]
	}
	data, _ := json.Marshal(out)
	fmt.Println(string(data))
	return 0
}
