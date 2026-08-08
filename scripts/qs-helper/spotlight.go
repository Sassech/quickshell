package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ── Tipos de resultado ────────────────────────────────────────────────────
// Usamos map[string]any para no inventar campos y dar libertad de shape.
type spotlightItem struct {
	Type     string   `json:"type"`
	Name     string   `json:"name"`
	Detail   string   `json:"detail"`
	Exec     string   `json:"exec,omitempty"`
	ExecArgs []string `json:"execArgs,omitempty"`
	Icon     string   `json:"icon"`
	IconPath string   `json:"iconPath"`
	score    int      // ranking interno, nunca se emite
}

// ── Recencia (frecency) ───────────────────────────────────────────────────
var frecencyPath = func() string {
	return filepath.Join(homeDir, ".cache", "qs-frecency.json")
}()

type frecencyMap map[string]int

func loadFrecency() frecencyMap {
	m := frecencyMap{}
	data, err := os.ReadFile(frecencyPath)
	if err != nil {
		return m
	}
	_ = json.Unmarshal(data, &m)
	if m == nil {
		m = frecencyMap{}
	}
	return m
}

func saveFrecency(m frecencyMap) {
	data, err := json.Marshal(m)
	if err != nil {
		return
	}
	dir := filepath.Dir(frecencyPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return
	}
	tmp := frecencyPath + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, frecencyPath)
}

// recordFrecency implementa `spotlight --record <exec>`.
func recordFrecency(execStr string) {
	m := loadFrecency()
	m[execStr]++
	saveFrecency(m)
}

// ── Helpers de output ────────────────────────────────────────────────────
func pythonRepr(s string) string {
	var b strings.Builder
	b.WriteByte('\'')
	for _, r := range s {
		switch r {
		case '\'':
			b.WriteString(`\'`)
		case '\\':
			b.WriteString(`\\`)
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('\'')
	return b.String()
}

func shortPath(p string) string {
	return strings.Replace(p, homeDir, "~", 1)
}

// ── Modo lista de apps (sin query) ────────────────────────────────────────
func spotlightListApps() []spotlightItem {
	apps := scanApps()
	rec := loadFrecency()
	items := make([]spotlightItem, 0, len(apps))
	for _, a := range apps {
		items = append(items, spotlightItem{
			Type:     "app",
			Name:     a.name,
			Detail:   a.exec,
			Exec:     a.exec,
			Icon:     "󰣆",
			IconPath: findIconPath(a.icon),
			score:    rec[a.exec],
		})
	}
	// Orden: recencia desc, luego name.lower() (estable).
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].score != items[j].score {
			return items[i].score > items[j].score
		}
		return strings.ToLower(items[i].Name) < strings.ToLower(items[j].Name)
	})
	return items
}

// ── Ventanas (hyprctl clients) ────────────────────────────────────────────
type hyprClient struct {
	Address   string `json:"address"`
	Title     string `json:"title"`
	Class     string `json:"class"`
	Workspace struct {
		ID int `json:"id"`
	} `json:"workspace"`
}

func hyprWindows(query string) []spotlightItem {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "hyprctl", "clients", "-j").Output()
	if err != nil {
		return nil
	}
	var clients []hyprClient
	if err := json.Unmarshal(out, &clients); err != nil {
		return nil
	}
	items := []spotlightItem{}
	for _, c := range clients {
		title := c.Title
		if strings.TrimSpace(title) == "" {
			continue
		}
		s := fuzzyScore(query, title, "")
		if s <= 0 {
			continue
		}
		addr := c.Address
		if !strings.HasPrefix(addr, "0x") {
			addr = "0x" + addr
		}
		detail := fmt.Sprintf("Ventana · %s · ws %d", c.Class, c.Workspace.ID)
		items = append(items, spotlightItem{
			Type:     "win",
			Name:     title,
			Detail:   detail,
			Exec:     "hyprctl dispatch focuswindow address:" + addr,
			Icon:     "󰕮",
			IconPath: "",
			score:    s,
		})
	}
	sort.SliceStable(items, func(i, j int) bool { return items[i].score > items[j].score })
	if len(items) > 8 {
		items = items[:8]
	}
	return items
}

// ── Búsqueda de archivos (walker nativo, reemplaza fd) ────────────────────
var fileExcludes = map[string]bool{
	".git":               true,
	".cache":             true,
	".icons":             true,
	".local/share/icons": true,
	"node_modules":       true,
}

// fileCand es un candidato rankeado (directo o subsecuencia).
type fileCand struct {
	path  string
	score int
}

// bfsDir es un directorio pendiente de procesar en la BFS.
type bfsDir struct {
	dir   string
	depth int
}

// fileWalker ejecuta la búsqueda BFS compartida entre workers.
type fileWalker struct {
	q        string
	mu       sync.Mutex
	queue    []bfsDir
	direct   []fileCand // substring/prefix matches (como fd)
	subseq   []fileCand // solo subsecuencia (fallback fuzzy)
	stop     atomic.Bool
	inflight atomic.Int64
	deadline time.Time
	cond     *sync.Cond
}

func newFileWalker(q string) *fileWalker {
	w := &fileWalker{
		q:        q,
		queue:    []bfsDir{{dir: homeDir, depth: 0}},
		deadline: time.Now().Add(2 * time.Second),
	}
	w.cond = sync.NewCond(&w.mu)
	return w
}

// addDirect registra un candidato directo y corta la búsqueda al llegar a 12.
func (w *fileWalker) addDirect(c fileCand) {
	w.mu.Lock()
	w.direct = append(w.direct, c)
	if len(w.direct) >= 12 {
		w.stop.Store(true)
	}
	w.mu.Unlock()
}

// pop saca el próximo dir a procesar, bloqueando mientras la cola esté vacía.
// El pop y el incremento de inflight ocurren bajo EL MISMO lock: el goroutine
// de terminación nunca observa "cola vacía + inflight 0" en el medio.
func (w *fileWalker) pop() (bfsDir, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	for len(w.queue) == 0 && !w.stop.Load() {
		w.cond.Wait()
	}
	if w.stop.Load() || len(w.queue) == 0 {
		return bfsDir{}, false
	}
	it := w.queue[0]
	w.queue = w.queue[1:]
	w.inflight.Add(1)
	if len(w.queue) == 0 {
		w.cond.Broadcast()
	}
	return it, true
}

// isExcluded decide si un entry (por nombre y ruta relativa) debe saltarse.
func isExcluded(rel, name string) bool {
	if fileExcludes[name] || strings.HasPrefix(name, ".") {
		return true
	}
	if rel != "" && fileExcludes[rel+"/"+name] {
		return true
	}
	return false
}

// scanDir procesa un dir: enqueuea subdirectorios y rankea archivos.
func (w *fileWalker) scanDir(it bfsDir) {
	entries, err := os.ReadDir(it.dir)
	if err != nil {
		return
	}
	for _, e := range entries {
		if w.stop.Load() || time.Now().After(w.deadline) {
			return
		}
		name := e.Name()
		rel, _ := filepath.Rel(homeDir, it.dir)
		if rel == "." {
			rel = ""
		}
		if isExcluded(rel, name) {
			continue
		}
		full := filepath.Join(it.dir, name)
		if e.IsDir() {
			w.enqueueDir(full, it.depth)
			continue
		}
		w.rankFile(full, name)
	}
}

func (w *fileWalker) enqueueDir(full string, depth int) {
	if depth+1 < 6 {
		w.mu.Lock()
		w.queue = append(w.queue, bfsDir{dir: full, depth: depth + 1})
		w.cond.Signal()
		w.mu.Unlock()
	}
}

// rankFile clasifica un archivo como match directo o subsecuencia.
func (w *fileWalker) rankFile(full, name string) {
	lower := strings.ToLower(name)
	if strings.Contains(lower, w.q) {
		if s := fuzzyScoreNoTypo(w.q, name, ""); s > 0 {
			w.addDirect(fileCand{path: full, score: s})
		}
		return
	}
	if s := subsequenceScore(w.q, lower, 3); s > 0 {
		w.mu.Lock()
		w.subseq = append(w.subseq, fileCand{path: full, score: s})
		w.mu.Unlock()
	}
}

// worker consume dirs de la cola hasta parar o agotar el deadline.
func (w *fileWalker) worker() {
	for {
		if w.stop.Load() || time.Now().After(w.deadline) {
			return
		}
		it, ok := w.pop()
		if !ok {
			return
		}
		w.scanDir(it)
		w.mu.Lock()
		w.inflight.Add(-1)
		w.cond.Broadcast()
		w.mu.Unlock()
	}
}

// run lanza los workers y espera a que la cola se vacíe, sin dirs en vuelo,
// o a un corte temprano (stop/deadline).
func (w *fileWalker) run() {
	const maxWorkers = 8
	var wg sync.WaitGroup
	for i := 0; i < maxWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			w.worker()
		}()
	}

	done := make(chan struct{})
	go func() {
		w.mu.Lock()
		for (len(w.queue) > 0 || w.inflight.Load() > 0) && !w.stop.Load() {
			w.cond.Wait()
		}
		w.stop.Store(true)
		w.cond.Broadcast()
		w.mu.Unlock()
		close(done)
	}()
	<-done
	wg.Wait()
}

func fileCandidates(query string) []spotlightItem {
	q := strings.ToLower(strings.TrimSpace(query))
	if q == "" {
		return nil
	}

	w := newFileWalker(q)
	w.run()

	// Rankear: direct primero (más relevantes), subseq como relleno.
	all := append(w.direct, w.subseq...)
	sort.SliceStable(all, func(i, j int) bool { return all[i].score > all[j].score })
	if len(all) > 6 {
		all = all[:6]
	}
	items := []spotlightItem{}
	for _, c := range all {
		items = append(items, spotlightItem{
			Type:     "file",
			Name:     filepath.Base(c.path),
			Detail:   shortPath(c.path),
			Exec:     "xdg-open " + pythonRepr(c.path),
			Icon:     "󰈙",
			IconPath: "",
		})
	}
	return items
}

// ── Modo query ────────────────────────────────────────────────────────────
func spotlightSearch(query string) []spotlightItem {
	queryLow := strings.ToLower(strings.TrimSpace(query))
	results := []spotlightItem{}

	appendCalcResult(query, &results)
	appendAppMatches(queryLow, &results)
	appendFileMatches(query, queryLow, &results)
	appendWindowMatches(query, queryLow, &results)
	appendShellCommand(query, &results)

	// Slice a 15
	if len(results) > 15 {
		results = results[:15]
	}
	return results
}

// appendCalcResult antepone el resultado de calculadora, si la query es una.
func appendCalcResult(query string, results *[]spotlightItem) {
	if val, ok := tryCalc(query); ok {
		*results = append(*results, spotlightItem{
			Type:     "calc",
			Name:     "= " + val,
			Detail:   "Copiar resultado al portapapeles",
			Exec:     "wl-copy " + val,
			Icon:     "󰃬",
			IconPath: "",
		})
	}
}

// appendAppMatches agrega apps (top 10 por score, boost de recencia).
func appendAppMatches(queryLow string, results *[]spotlightItem) {
	if queryLow == "" {
		return
	}
	apps := scanApps()
	rec := loadFrecency()
	seen := map[string]bool{}
	scored := []spotlightItem{}
	for _, a := range apps {
		if seen[a.name] {
			continue
		}
		seen[a.name] = true
		extra := strings.TrimSpace(a.generic + " " + a.keywords)
		s := fuzzyScore(queryLow, a.name, extra)
		if s == 0 {
			continue
		}
		scored = append(scored, spotlightItem{
			Type:     "app",
			Name:     a.name,
			Detail:   a.exec,
			Exec:     a.exec,
			Icon:     "󰣆",
			IconPath: findIconPath(a.icon),
			score:    s + rec[a.exec]*5,
		})
	}
	sort.SliceStable(scored, func(i, j int) bool {
		if scored[i].score != scored[j].score {
			return scored[i].score > scored[j].score
		}
		return strings.ToLower(scored[i].Name) < strings.ToLower(scored[j].Name)
	})
	for _, it := range scored {
		if len(*results) >= 10 {
			break
		}
		*results = append(*results, it)
	}
}

// appendFileMatches agrega archivos (solo si hay espacio y query >= 2).
func appendFileMatches(query, queryLow string, results *[]spotlightItem) {
	if queryLow == "" || len([]rune(queryLow)) < 2 || len(*results) >= 12 {
		return
	}
	for _, it := range fileCandidates(query) {
		if len(*results) >= 12 {
			break
		}
		*results = append(*results, it)
	}
}

// appendWindowMatches agrega ventanas de hyprctl.
func appendWindowMatches(query, queryLow string, results *[]spotlightItem) {
	if queryLow == "" {
		return
	}
	for _, it := range hyprWindows(query) {
		*results = append(*results, it)
	}
}

// appendShellCommand agrega el comando de shell al final (si no es calc).
func appendShellCommand(query string, results *[]spotlightItem) {
	if query == "" || calcRe.MatchString(query) {
		return
	}
	cmdArgs := []string{"kitty", "-e", "bash", "-i", "-c",
		fmt.Sprintf("history -s -- %s; exec bash", pythonRepr(query))}
	*results = append(*results, spotlightItem{
		Type:     "cmd",
		Name:     query,
		Detail:   "Ejecutar en terminal",
		ExecArgs: cmdArgs,
		Icon:     "󰆍",
		IconPath: "",
	})
}

// ── Entry point del subcomando spotlight ─────────────────────────────────
func runSpotlight(args []string) int {
	loadIconCache()
	defer saveIconCache()

	if len(args) > 0 && args[0] == "--list-apps" {
		items := spotlightListApps()
		out, _ := json.Marshal(items)
		fmt.Println(string(out))
		return 0
	}
	if len(args) > 1 && args[0] == "--record" {
		recordFrecency(args[1])
		return 0
	}
	query := ""
	if len(args) > 0 {
		query = args[0]
	}
	items := spotlightSearch(query)
	out, _ := json.Marshal(items)
	fmt.Println(string(out))
	return 0
}
