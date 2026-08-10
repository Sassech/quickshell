package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

var clipboardLogFile = filepath.Join(os.TempDir(), "qs-clipboard.log")

const (
	clipBinaryPrefix = "[[ binary"
	copyOKPrefix     = "[copy] OK: "
	copyErrPrefix    = "[copy] Error: "
)

func clipboardLog(msg string) {
	f, err := os.OpenFile(clipboardLogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\n", time.Now().Format("2006-01-02 15:04:05"), msg)
}

func hasMagick() bool {
	_, err := exec.LookPath("magick")
	return err == nil
}

type clipEntry struct {
	ID       string `json:"id"`
	Preview  string `json:"preview"`
	IsBinary bool   `json:"isBinary"`
	Thumb    string `json:"thumb"`
}

// generateThumbnail replica generate_thumbnail del Python.
func generateThumbnail(entryID, preview string) string {
	thumbPath := filepath.Join(os.TempDir(), "qs-clip-"+entryID+".png")
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	rawPath := filepath.Join(os.TempDir(), "qs-raw-"+entryID)
	line := []byte(entryID + "\t" + preview)

	ctx, cancel := contextTimeout(10 * time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "cliphist", "decode")
	cmd.Stdin = bytes.NewReader(line)
	out, err := cmd.Output()
	if err != nil || len(out) < 50 {
		return ""
	}
	if err := os.WriteFile(rawPath, out, 0o600); err != nil {
		return ""
	}
	defer os.Remove(rawPath)

	mctx, mcancel := contextTimeout(10 * time.Second)
	defer mcancel()
	mcmd := exec.CommandContext(mctx, "magick", rawPath,
		"-thumbnail", "72x72^", "-gravity", "center", "-extent", "72x72", thumbPath)
	_ = mcmd.Run()

	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	return ""
}

// generateFileThumbnail crea un thumb 72x72 del archivo referenciado.
func generateFileThumbnail(entryID, path string) string {
	thumbPath := filepath.Join(os.TempDir(), "qs-fthumb-"+entryID+".png")
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	ctx, cancel := contextTimeout(10 * time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "magick", path+"[0]",
		"-thumbnail", "72x72^", "-gravity", "center", "-extent", "72x72", thumbPath)
	_ = cmd.Run()
	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	return ""
}

// fileRefPath devuelve el path si la preview es una ruta absoluta existente.
func fileRefPath(preview string) string {
	if strings.Contains(preview, "\n") || !strings.HasPrefix(preview, "/") {
		return ""
	}
	if _, err := os.Stat(preview); err == nil {
		return preview
	}
	return ""
}

// runClipboard implementa el subcomando clipboard.
func runClipboard() int {
	if !hasMagick() {
		// Igual lista, sin thumbs de binarios.
		entries := clipboardList()
		out, _ := json.Marshal(entries)
		fmt.Println(string(out))
		return 0
	}
	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	result, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[list] cliphist error: " + err.Error())
		fmt.Println("[]")
		return 0
	}

	entries := []clipEntry{}
	type thumbTask struct {
		idx     int
		id      string
		preview string
		path    string
	}
	thumbTasks := []thumbTask{}

	scanner := bufio.NewScanner(bytes.NewReader(result))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 {
			continue
		}
		entryID := line[:idx]
		preview := line[idx+1:]
		isBinary := strings.HasPrefix(preview, clipBinaryPrefix)
		entries = append(entries, clipEntry{
			ID:       entryID,
			Preview:  preview,
			IsBinary: isBinary,
			Thumb:    "",
		})
		if isBinary && strings.Contains(strings.ToLower(preview), "png") {
			thumbTasks = append(thumbTasks, thumbTask{len(entries) - 1, entryID, preview, ""})
		} else if p := fileRefPath(preview); p != "" {
			thumbTasks = append(thumbTasks, thumbTask{len(entries) - 1, entryID, preview, p})
		}
	}

	// Thumbnails en paralelo, 4 workers.
	if len(thumbTasks) > 0 {
		var wg sync.WaitGroup
		sem := make(chan struct{}, 4)
		for _, t := range thumbTasks {
			wg.Add(1)
			go func(t thumbTask) {
				defer wg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()
				if t.path != "" {
					entries[t.idx].Thumb = generateFileThumbnail(t.id, t.path)
				} else {
					entries[t.idx].Thumb = generateThumbnail(t.id, t.preview)
				}
			}(t)
		}
		wg.Wait()
	}

	out, _ := json.Marshal(entries)
	fmt.Println(string(out))
	return 0
}

// clipboardList sin magick: solo lista.
func clipboardList() []clipEntry {
	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	result, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[list] cliphist error: " + err.Error())
		return []clipEntry{}
	}
	entries := []clipEntry{}
	scanner := bufio.NewScanner(bytes.NewReader(result))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 {
			continue
		}
		entries = append(entries, clipEntry{
			ID:       line[:idx],
			Preview:  line[idx+1:],
			IsBinary: strings.HasPrefix(line[idx+1:], clipBinaryPrefix),
			Thumb:    "",
		})
	}
	return entries
}

// binaryMIME infiere el MIME de una preview binaria, replicando clipboard-copy.sh.
func binaryMIME(preview string) string {
	p := strings.ToLower(preview)
	switch {
	case strings.Contains(p, "png"):
		return "image/png"
	case strings.Contains(p, "jpg") || strings.Contains(p, "jpeg"):
		return "image/jpeg"
	case strings.Contains(p, "gif"):
		return "image/gif"
	case strings.Contains(p, "webp"):
		return "image/webp"
	case strings.Contains(p, "svg"):
		return "image/svg+xml"
	default:
		return "application/octet-stream"
	}
}

// findClipEntry busca en la salida de cliphist list la entrada con el ID dado.
func findClipEntry(id string, list []byte) (entry, preview string) {
	scanner := bufio.NewScanner(bytes.NewReader(list))
	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "\t")
		if idx < 0 || line[:idx] != id {
			continue
		}
		return line, line[idx+1:]
	}
	return "", ""
}

// lanzarWlCopy ejecuta wl-copy sin esperar su salida. wl-copy forkea al
// background para mantener viva la selección y el hijo hereda el pipe de
// stdout: esperar con Output()/CombinedOutput() cuelga hasta el EOF del
// pipe. Solo Start() + liberar el handle replica el comportamiento bash.
func lanzarWlCopy(mime string, payload []byte) bool {
	cmd := exec.Command("wl-copy")
	if mime != "" {
		cmd = exec.Command("wl-copy", "--type", mime)
	}
	cmd.Stdin = bytes.NewReader(payload)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		clipboardLog(copyErrPrefix + "wl-copy Start falló (" + mime + "): " + err.Error())
		return false
	}
	cmd.Process.Release()
	return true
}

// clipboardFileRef detecta referencias a archivo (gestor de archivos) y
// devuelve MIME + payload para re-copiar: file:// → text/uri-list, formato
// Nautilus → x-special/gnome-copied-files, ruta absoluta existente → file://.
func clipboardFileRef(decoded []byte) (string, []byte, bool) {
	text := strings.TrimSpace(string(decoded))

	for _, line := range strings.Split(text, "\n") {
		if strings.HasPrefix(line, "file://") {
			return "text/uri-list", decoded, true
		}
	}

	if strings.HasPrefix(text, "x-special/gnome-copied-files") {
		return "x-special/gnome-copied-files", decoded, true
	}

	if !strings.Contains(text, "\n") && strings.HasPrefix(text, "/") {
		if _, err := os.Stat(text); err == nil {
			return "text/uri-list", []byte("file://" + text), true
		}
	}

	return "", nil, false
}

// runClipboardCopy implementa el subcomando clipboard-copy <id>.
// Exit codes replican clipboard-copy.sh: 1 ID vacío, 2 cliphist list falló,
// 3 ID no encontrado, 4 decode/fallo de copia.
func runClipboardCopy(id string) int {
	if id == "" {
		clipboardLog(copyErrPrefix + "ID vacío")
		return 1
	}

	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	list, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog(copyErrPrefix + "cliphist list falló: " + err.Error())
		return 2
	}

	entry, preview := findClipEntry(id, list)
	if entry == "" {
		clipboardLog(copyErrPrefix + "ID '" + id + "' no encontrado en cliphist")
		return 3
	}

	dctx, dcancel := contextTimeout(10 * time.Second)
	defer dcancel()
	decCmd := exec.CommandContext(dctx, "cliphist", "decode")
	decCmd.Stdin = bytes.NewReader([]byte(entry + "\n"))
	decoded, err := decCmd.Output()
	if err != nil {
		clipboardLog(copyErrPrefix + "cliphist decode falló: " + err.Error())
		return 4
	}

	if strings.HasPrefix(preview, clipBinaryPrefix) {
		mime := binaryMIME(preview)
		if !lanzarWlCopy(mime, decoded) {
			return 4
		}
		clipboardLog(copyOKPrefix + id + " (" + mime + ")")
		return 0
	}

	// Rama no-binaria: archivo → MIME real → imagen → texto.
	if mime, payload, ok := clipboardFileRef(decoded); ok {
		if !lanzarWlCopy(mime, payload) {
			return 4
		}
		clipboardLog(copyOKPrefix + id + " (" + mime + " - file ref)")
		return 0
	}

	mimeType := http.DetectContentType(decoded)
	if strings.HasPrefix(mimeType, "image/") {
		if !lanzarWlCopy(mimeType, decoded) {
			return 4
		}
		clipboardLog(copyOKPrefix + id + " (" + mimeType + " - auto-detected)")
		return 0
	}

	if !lanzarWlCopy("", decoded) {
		return 4
	}
	clipboardLog(copyOKPrefix + id + " (text)")
	return 0
}
