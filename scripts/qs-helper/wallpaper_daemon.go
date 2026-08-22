package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
)

// ── Daemon wallpaper-multi ───────────────────────────────────────────────
// Protocolo JSON-lines: {"id","folder","force"} → {"id","folder","items"}
// (mismo id, para correlacionar sin depender del orden). Cache por carpeta
// en memoria; solo re-escanéa si el mtime del dir cambió o se pide force.

// wallRequest es un request JSON-lines del daemon wallpaper-multi.
type wallRequest struct {
	ID     string `json:"id"`
	Folder string `json:"folder"`
	Force  bool   `json:"force"`
}

// wallResponse es la respuesta JSON-lines del daemon wallpaper-multi.
type wallResponse struct {
	ID     string          `json:"id"`
	Folder string          `json:"folder"`
	Items  []wallpaperItem `json:"items"`
	Error  string          `json:"error,omitempty"`
}

// wallFolderCache es el cache de una carpeta.
type wallFolderCache struct {
	items  []wallpaperItem
	dirMod int64
}

// wallDaemonState cachea el listado por carpeta. Un solo goroutine (el loop
// principal del daemon) accede al estado, así que no hay races sin locks.
type wallDaemonState struct {
	folders map[string]*wallFolderCache
}

func newWallDaemonState() *wallDaemonState {
	return &wallDaemonState{folders: map[string]*wallFolderCache{}}
}

// itemsFor devuelve los items de una carpeta. Re-listea solo si el mtime del
// directorio cambió desde la última vez (nuevos archivos/borrados) o si se
// pidió force. La clave del cache es el folder ORIGINAL (sin expandir ~),
// para que QML matchee contra el path que ya tiene guardado en _tabs.
func (s *wallDaemonState) itemsFor(folder string, force bool) ([]wallpaperItem, string) {
	expanded := expandTilde(folder)
	fi, err := os.Stat(expanded)
	if err != nil || !fi.IsDir() {
		return nil, "carpeta no encontrada o no es un directorio: " + folder
	}
	if !force {
		if c, ok := s.folders[folder]; ok && c.dirMod == fi.ModTime().Unix() {
			fmt.Fprintf(os.Stderr, "wallpaper-multi --daemon: cache hit para %q\n", folder)
			return c.items, ""
		}
	}
	mpv := hasMpvpaper()
	imgs := collectWallpaperFiles(expanded, mpv)
	if len(imgs) > 60 {
		imgs = imgs[:60]
	}
	items := buildWallpaperItems(imgs)
	s.folders[folder] = &wallFolderCache{items: items, dirMod: fi.ModTime().Unix()}
	return items, ""
}

// runWallpaperMultiDaemon atiende requests en JSON-lines hasta que se cierra
// stdin o llega SIGTERM/SIGINT. stdout lleva SOLO respuestas; logs a stderr.
func runWallpaperMultiDaemon() int {
	_ = os.MkdirAll(thumbDir, 0o755)
	st := newWallDaemonState()

	lines := make(chan string, 1)
	go func() {
		defer close(lines)
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Buffer(make([]byte, 0, 64*1024), 1*1024*1024)
		for scanner.Scan() {
			lines <- scanner.Text()
		}
		if err := scanner.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "wallpaper-multi --daemon: leyendo stdin: %v\n", err)
		}
	}()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)

	out := bufio.NewWriter(os.Stdout)
	for {
		select {
		case line, ok := <-lines:
			if !ok {
				return 0
			}
			handleWallRequest(line, st, out)
		case <-signals:
			return 0
		}
	}
}

// handleWallRequest procesa una línea JSON {"id","folder","force"}. Un error
// de parseo solo descarta ese request, el daemon sigue vivo.
func handleWallRequest(line string, st *wallDaemonState, out *bufio.Writer) {
	if strings.TrimSpace(line) == "" {
		return
	}
	var req wallRequest
	if err := json.Unmarshal([]byte(line), &req); err != nil {
		writeJSONLine(out, wallResponse{Error: "request no parseable: " + err.Error()})
		return
	}
	if strings.TrimSpace(req.Folder) == "" {
		writeJSONLine(out, wallResponse{ID: req.ID, Error: "falta el campo folder"})
		return
	}
	items, errMsg := st.itemsFor(req.Folder, req.Force)
	writeJSONLine(out, wallResponse{ID: req.ID, Folder: req.Folder, Items: items, Error: errMsg})
}
