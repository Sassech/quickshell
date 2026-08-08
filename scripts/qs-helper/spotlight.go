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

func fileCandidates(query string) []spotlightItem {
	type cand struct {
		path  string
		score int
	}
	q := strings.ToLower(strings.TrimSpace(query))
	if q == "" {
		return nil
	}

	// Cola BFS compartida (dir + depth), protegida por mutex.
	type bfsItem struct {
		dir   string
		depth int
	}
	var (
		mu        sync.Mutex
		queue     = []bfsItem{{dir: homeDir, depth: 0}}
		direct    []cand // substring/prefix matches (como fd)
		subseq    []cand // solo subsecuencia (fallback fuzzy)
		stop      atomic.Bool
		inflight  atomic.Int64
		deadline  = time.Now().Add(2 * time.Second)
	)
	queueEmpty := sync.NewCond(&mu)

	addCand := func(list *[]cand, c cand) {
		mu.Lock()
		*list = append(*list, c)
		if len(direct) >= 12 {
			stop.Store(true)
		}
		mu.Unlock()
	}

	// Un worker: popea un dir de la cola, procesa sus entries.
	worker := func() {
		for {
			if stop.Load() || time.Now().After(deadline) {
				return
			}
			// Pop e incremento de inflight bajo EL MISMO lock: el goroutine
			// de terminación nunca puede observar "cola vacía + inflight 0"
			// entre el pop y el procesamiento.
			mu.Lock()
			for len(queue) == 0 && !stop.Load() {
				queueEmpty.Wait()
			}
			if stop.Load() || len(queue) == 0 {
				mu.Unlock()
				return
			}
			it := queue[0]
			queue = queue[1:]
			inflight.Add(1)
			if len(queue) == 0 {
				queueEmpty.Broadcast()
			}
			mu.Unlock()

			func() {
				entries, err := os.ReadDir(it.dir)
				if err != nil {
					return
				}
				for _, e := range entries {
					if stop.Load() || time.Now().After(deadline) {
						return
					}
					name := e.Name()
					if fileExcludes[name] || strings.HasPrefix(name, ".") {
						continue
					}
					rel, _ := filepath.Rel(homeDir, it.dir)
					if rel == "." {
						rel = ""
					}
					if rel != "" && fileExcludes[rel+"/"+name] {
						continue
					}
					full := filepath.Join(it.dir, name)
					if e.IsDir() {
						if it.depth+1 < 6 {
							mu.Lock()
							queue = append(queue, bfsItem{dir: full, depth: it.depth + 1})
							queueEmpty.Signal()
							mu.Unlock()
						}
						continue
					}
					lower := strings.ToLower(name)
					if strings.Contains(lower, q) {
						s := fuzzyScoreNoTypo(q, name, "")
						if s > 0 {
							addCand(&direct, cand{path: full, score: s})
						}
					} else if s := subsequenceScore(q, lower, 3); s > 0 {
						mu.Lock()
						subseq = append(subseq, cand{path: full, score: s})
						mu.Unlock()
					}
				}
			}()

			mu.Lock()
			inflight.Add(-1)
			queueEmpty.Broadcast()
			mu.Unlock()
		}
	}

	const maxWorkers = 8
	var wg sync.WaitGroup
	for i := 0; i < maxWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			worker()
		}()
	}

	// Espera a que la cola se vacíe Y no haya dirs en vuelo, o corte temprano.
	done := make(chan struct{})
	go func() {
		mu.Lock()
		for (len(queue) > 0 || inflight.Load() > 0) && !stop.Load() {
			queueEmpty.Wait()
		}
		stop.Store(true)
		queueEmpty.Broadcast()
		mu.Unlock()
		close(done)
	}()
	<-done
	wg.Wait()

	// Rankear: direct primero (más relevantes), subseq como relleno.
	all := append(direct, subseq...)
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
	rec := loadFrecency()

	// Calculadora (primera)
	if val, ok := tryCalc(query); ok {
		results = append(results, spotlightItem{
			Type:     "calc",
			Name:     "= " + val,
			Detail:   "Copiar resultado al portapapeles",
			Exec:     "wl-copy " + val,
			Icon:     "󰃬",
			IconPath: "",
		})
	}

	// Aplicaciones (top 10 por score, boost de recencia)
	if queryLow != "" {
		apps := scanApps()
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
			if len(results) >= 10 {
				break
			}
			results = append(results, it)
		}
	}

	// Archivos (solo si hay espacio y query >= 2)
	if queryLow != "" && len([]rune(queryLow)) >= 2 && len(results) < 12 {
		for _, it := range fileCandidates(query) {
			if len(results) >= 12 {
				break
			}
			results = append(results, it)
		}
	}

	// Ventanas
	if queryLow != "" {
		for _, it := range hyprWindows(query) {
			results = append(results, it)
		}
	}

	// Comando de shell (siempre al final si no es calc)
	if query != "" && !calcRe.MatchString(query) {
		cmdArgs := []string{"kitty", "-e", "bash", "-i", "-c",
			fmt.Sprintf("history -s -- %s; exec bash", pythonRepr(query))}
		results = append(results, spotlightItem{
			Type:     "cmd",
			Name:     query,
			Detail:   "Ejecutar en terminal",
			ExecArgs: cmdArgs,
			Icon:     "󰆍",
			IconPath: "",
		})
	}

	// Slice a 15
	if len(results) > 15 {
		results = results[:15]
	}
	return results
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
