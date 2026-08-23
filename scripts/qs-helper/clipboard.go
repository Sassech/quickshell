package main

import (
	"archive/zip"
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

var clipboardLogFile = filepath.Join(os.TempDir(), "qs-clipboard.log")

const (
	clipBinaryPrefix = "[[ binary"
	copyOKPrefix     = "[copy] OK: "
	copyErrPrefix    = "[copy] Error: "
	// maxClipPayloadBytes es el tope para analizar y re-copiar clips
	// binarios completos en memoria (50 MB).
	maxClipPayloadBytes = 50 * 1024 * 1024
	mimeHTML            = "text/html"
	mimeOctetStream     = "application/octet-stream"
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

type thumbTask struct {
	idx     int
	id      string
	preview string
	path    string
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

// cleanOldThumbs elimina thumbnails generados por el helper que superen maxAge.
func cleanOldThumbs(maxAge time.Duration) {
	pattern := filepath.Join(os.TempDir(), "qs-clip-*.png")
	files, _ := filepath.Glob(pattern)
	cutoff := time.Now().Add(-maxAge)
	for _, f := range files {
		if fi, err := os.Stat(f); err == nil && fi.ModTime().Before(cutoff) {
			_ = os.Remove(f)
		}
	}
}

// runClipboard implementa el subcomando clipboard (one-shot).
func runClipboard() int {
	cleanOldThumbs(7 * 24 * time.Hour)
	out, _ := json.Marshal(clipboardEntries())
	fmt.Println(string(out))
	return 0
}

// clipboardEntries lista el portapapeles y genera los thumbnails faltantes.
// Es la lógica compartida entre el modo one-shot y el daemon (clipboard
// --daemon), que cachea su resultado en memoria entre refreshes.
func clipboardEntries() []clipEntry {
	if !hasMagick() {
		// Igual lista, sin thumbs de binarios.
		return clipboardList()
	}
	ctx, cancel := contextTimeout(5 * time.Second)
	defer cancel()
	result, err := exec.CommandContext(ctx, "cliphist", "list").Output()
	if err != nil {
		clipboardLog("[list] cliphist error: " + err.Error())
		return []clipEntry{}
	}
	entries, thumbTasks := parseClipEntries(result)
	if len(thumbTasks) > 0 {
		attachThumbnails(entries, thumbTasks)
	}
	return entries
}

func parseClipEntries(result []byte) ([]clipEntry, []thumbTask) {
	entries := []clipEntry{}
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
		collectThumbTask(&thumbTasks, len(entries)-1, entryID, preview, isBinary)
	}
	return entries, thumbTasks
}

func collectThumbTask(tasks *[]thumbTask, idx int, entryID, preview string, isBinary bool) {
	if isBinary && strings.Contains(strings.ToLower(preview), "png") {
		*tasks = append(*tasks, thumbTask{idx: idx, id: entryID, preview: preview})
		return
	}
	if p := fileRefPath(preview); p != "" {
		*tasks = append(*tasks, thumbTask{idx: idx, id: entryID, preview: preview, path: p})
	}
}

func attachThumbnails(entries []clipEntry, thumbTasks []thumbTask) {
	thumbs := make([]string, len(thumbTasks))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 4)
	for i, t := range thumbTasks {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int, t thumbTask) {
			defer wg.Done()
			defer func() { <-sem }()
			thumbs[i] = thumbnailForTask(t)
		}(i, t)
	}
	wg.Wait()
	for i, t := range thumbTasks {
		entries[t.idx].Thumb = thumbs[i]
	}
}

func thumbnailForTask(t thumbTask) string {
	if t.path != "" {
		return generateFileThumbnail(t.id, t.path)
	}
	return generateThumbnail(t.id, t.preview)
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

// binaryToken extrae el token de formato de una preview binaria de cliphist:
// "[[ binary data 102 KiB png 551x214 ]]" -> "png".
// cliphist solo genera preview binaria para imágenes decodificables
// (image.DecodeConfig), así que el token está en el 5º campo del split.
func binaryToken(preview string) string {
	fields := strings.Fields(preview)
	if len(fields) >= 6 && fields[0] == "[[" && fields[1] == "binary" {
		return strings.ToLower(fields[5])
	}
	return ""
}

// binaryMIME infiere el MIME de una preview binaria usando el token real de
// cliphist (formato de imagen Go), no strings.Contains.
func binaryMIME(preview string) string {
	switch binaryToken(preview) {
	case "png":
		return "image/png"
	case "jpeg":
		return "image/jpeg"
	case "gif":
		return "image/gif"
	case "bmp":
		return "image/bmp"
	case "tiff":
		return "image/tiff"
	case "webp":
		return "image/webp"
	case "svg":
		return "image/svg+xml"
	case "pdf":
		return "application/pdf"
	case "html":
		return mimeHTML
	default:
		return mimeOctetStream
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

// officeMIME detecta DOCX/XLSX/PPTX inspeccionando [Content_Types].xml del
// ZIP (http.DetectContentType solo sabe que es application/zip).
func officeMIME(decoded []byte) string {
	zr, err := zip.NewReader(bytes.NewReader(decoded), int64(len(decoded)))
	if err != nil {
		return ""
	}
	for _, f := range zr.File {
		if f.Name != "[Content_Types].xml" {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			return ""
		}
		buf := make([]byte, 1024)
		n, _ := io.ReadFull(rc, buf)
		rc.Close()
		s := string(buf[:n])
		switch {
		case strings.Contains(s, "wordprocessingml"):
			return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
		case strings.Contains(s, "spreadsheetml"):
			return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
		case strings.Contains(s, "presentationml"):
			return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
		}
		return ""
	}
	return ""
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
	decoded, err := decodeClipEntry(entry)
	if err != nil {
		return 4
	}
	if handled, code := handleOversizedClip(id, decoded); handled {
		return code
	}
	if handled, code := handleBinaryClip(id, preview, decoded); handled {
		return code
	}
	if handled, code := handleFileRefClip(id, decoded); handled {
		return code
	}
	return handleDetectedMIME(id, decoded)
}

func decodeClipEntry(entry string) ([]byte, error) {
	dctx, dcancel := contextTimeout(10 * time.Second)
	defer dcancel()
	decCmd := exec.CommandContext(dctx, "cliphist", "decode")
	decCmd.Stdin = bytes.NewReader([]byte(entry + "\n"))
	decoded, err := decCmd.Output()
	if err != nil {
		clipboardLog(copyErrPrefix + "cliphist decode falló: " + err.Error())
	}
	return decoded, err
}

func handleOversizedClip(id string, decoded []byte) (bool, int) {
	if len(decoded) <= maxClipPayloadBytes {
		return false, 0
	}
	if !lanzarWlCopy(mimeOctetStream, decoded) {
		return true, 4
	}
	clipboardLog(copyOKPrefix + id + " (" + mimeOctetStream + " - oversize)")
	return true, 0
}

func handleBinaryClip(id, preview string, decoded []byte) (bool, int) {
	if !strings.HasPrefix(preview, clipBinaryPrefix) {
		return false, 0
	}
	mime := binaryMIME(preview)
	if !lanzarWlCopy(mime, decoded) {
		return true, 4
	}
	clipboardLog(copyOKPrefix + id + " (" + mime + ")")
	return true, 0
}

func handleFileRefClip(id string, decoded []byte) (bool, int) {
	mime, payload, ok := clipboardFileRef(decoded)
	if !ok {
		return false, 0
	}
	if !lanzarWlCopy(mime, payload) {
		return true, 4
	}
	clipboardLog(copyOKPrefix + id + " (" + mime + " - file ref)")
	return true, 0
}

func handleDetectedMIME(id string, decoded []byte) int {
	mimeType := http.DetectContentType(decoded)
	mimeType = resolveOfficeMIME(mimeType, decoded)
	if handled, code := handleNonTextMime(id, decoded, mimeType); handled {
		return code
	}
	if handled, code := handleHTMLMime(id, decoded, mimeType); handled {
		return code
	}
	if !lanzarWlCopy("", decoded) {
		return 4
	}
	clipboardLog(copyOKPrefix + id + " (text)")
	return 0
}

func resolveOfficeMIME(mimeType string, decoded []byte) string {
	if mimeType != "application/zip" {
		return mimeType
	}
	if office := officeMIME(decoded); office != "" {
		return office
	}
	return mimeType
}

func handleNonTextMime(id string, decoded []byte, mimeType string) (bool, int) {
	if strings.HasPrefix(mimeType, "text/") || mimeType == mimeOctetStream {
		return false, 0
	}
	if !lanzarWlCopy(mimeType, decoded) {
		return true, 4
	}
	clipboardLog(copyOKPrefix + id + " (" + mimeType + " - auto-detected)")
	return true, 0
}

func handleHTMLMime(id string, decoded []byte, mimeType string) (bool, int) {
	if !strings.HasPrefix(mimeType, mimeHTML) {
		return false, 0
	}
	if !lanzarWlCopy(mimeHTML, decoded) {
		return true, 4
	}
	clipboardLog(copyOKPrefix + id + " (" + mimeHTML + ")")
	return true, 0
}

// ── Daemon clipboard (JSON-lines, cache en memoria) ─────────────────────

// clipRequest es un request JSON-lines del daemon clipboard.
type clipRequest struct {
	ID  string `json:"id"`
	Cmd string `json:"cmd"`
}

// clipResponse es la respuesta JSON-lines: devuelve el mismo id del request
// para que el cliente descarte respuestas stale.
type clipResponse struct {
	ID    string      `json:"id"`
	Items []clipEntry `json:"items"`
	Error string      `json:"error,omitempty"`
}

// clipDaemonState cachea la última lista. Un solo goroutine (el loop
// principal del daemon) accede al estado, así que no hay races sin locks.
type clipDaemonState struct {
	items   []clipEntry
	dbMod   int64
	hasList bool
}

// cliphistDBPath devuelve la ruta de la base de cliphist, usada como señal de
// invalidación del cache (el mtime cambia cuando cliphist store/wipe escriben).
func cliphistDBPath() string {
	cacheHome := os.Getenv("XDG_CACHE_HOME")
	if cacheHome == "" {
		cacheHome = filepath.Join(homeDir, ".cache")
	}
	return filepath.Join(cacheHome, "cliphist", "db")
}

// refresh devuelve la lista actual. Re-ejecuta cliphist solo si la base
// cambió (o si nunca se listó); si no, sirve el cache en memoria.
func (s *clipDaemonState) refresh() []clipEntry {
	if fi, err := os.Stat(cliphistDBPath()); err == nil {
		if s.hasList && fi.ModTime().Unix() == s.dbMod {
			fmt.Fprintln(os.Stderr, "clipboard --daemon: cache hit, cliphist no re-ejecutado")
			return s.items
		}
		s.dbMod = fi.ModTime().Unix()
	} else {
		// Base no accesible: re-listar siempre por seguridad.
		s.hasList = false
	}
	s.items = clipboardEntries()
	s.hasList = true
	return s.items
}

// runClipboardDaemon atiende requests en JSON-lines hasta que se cierra stdin
// o llega SIGTERM/SIGINT. stdout lleva SOLO respuestas; logs a stderr.
func runClipboardDaemon() int {
	cleanOldThumbs(7 * 24 * time.Hour)
	st := &clipDaemonState{}

	lines := make(chan string, 1)
	go func() {
		defer close(lines)
		scanner := bufio.NewScanner(os.Stdin)
		scanner.Buffer(make([]byte, 0, 64*1024), 1*1024*1024)
		for scanner.Scan() {
			lines <- scanner.Text()
		}
		if err := scanner.Err(); err != nil {
			fmt.Fprintf(os.Stderr, "clipboard --daemon: leyendo stdin: %v\n", err)
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
			handleClipRequest(line, st, out)
		case <-signals:
			return 0
		}
	}
}

// handleClipRequest procesa una línea: "refresh" a secas (sin id) o JSON
// {"id","cmd":"refresh"}. Un error de parseo solo descarta ese request.
func handleClipRequest(line string, st *clipDaemonState, out *bufio.Writer) {
	if strings.TrimSpace(line) == "" {
		return
	}
	id := ""
	cmd := ""
	trimmed := strings.TrimSpace(line)
	if trimmed == "refresh" {
		cmd = "refresh"
	} else {
		var req clipRequest
		if err := json.Unmarshal([]byte(trimmed), &req); err != nil {
			writeJSONLine(out, clipResponse{Error: "request no parseable: " + err.Error()})
			return
		}
		id = req.ID
		cmd = strings.TrimSpace(req.Cmd)
		if cmd == "" {
			cmd = "refresh"
		}
	}
	switch cmd {
	case "refresh":
		writeJSONLine(out, clipResponse{ID: id, Items: st.refresh()})
	default:
		writeJSONLine(out, clipResponse{ID: id, Error: "comando desconocido: " + cmd})
	}
}
