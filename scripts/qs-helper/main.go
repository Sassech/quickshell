package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	cmd := os.Args[1]
	args := os.Args[2:]

	code := 0
	switch cmd {
	case "spotlight":
		code = runSpotlight(args)
	case "clipboard":
		code = runClipboard()
	case "clipboard-copy":
		id := ""
		if len(args) > 0 {
			id = args[0]
		}
		code = runClipboardCopy(id)
	case "folder":
		path := ""
		if len(args) > 0 {
			path = args[0]
		}
		code = runFolder(path)
	case "wallpaper":
		folder := ""
		if len(args) > 0 {
			folder = args[0]
		}
		code = runWallpaper(folder)
	case "wallpaper-save":
		if len(args) == 0 {
			fmt.Fprintln(os.Stderr, "Usage: qs-helper wallpaper-save <folder>")
			code = 1
			break
		}
		code = runWallpaperSave(args[0])
	default:
		fmt.Fprintf(os.Stderr, "qs-helper: subcomando desconocido %q\n", cmd)
		usage()
		code = 1
	}
	os.Exit(code)
}

func usage() {
	fmt.Fprintln(os.Stderr, `qs-helper — utilidades para la shell quickshell

Uso:
  qs-helper spotlight [--list-apps | --record <exec> | <query>]
  qs-helper clipboard
  qs-helper clipboard-copy <id>
  qs-helper folder <path>
  qs-helper wallpaper <folder>
  qs-helper wallpaper-save <folder>`)
}

// ── Helpers compartidos ───────────────────────────────────────────────────

// contextTimeout crea un contexto con timeout (evita repetir imports).
func contextTimeout(d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), d)
}

// expandTilde expande "~" y "~/..." al home del usuario.
func expandTilde(p string) string {
	if p == "" {
		return p
	}
	if p == "~" {
		return homeDir
	}
	if strings.HasPrefix(p, "~/") {
		return filepath.Join(homeDir, p[2:])
	}
	return p
}

func isDir(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.IsDir()
}
