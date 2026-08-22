package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type folderEntry struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	IsDir bool   `json:"isDir"`
}

type folderResponse struct {
	Path    string        `json:"path"`
	Parent  string        `json:"parent"`
	Entries []folderEntry `json:"entries"`
	Error   string        `json:"error,omitempty"`
}

// runFolder implementa el subcomando folder (port de folder-list.py).
func runFolder(rawPath string) int {
	expanded := expandTilde(rawPath)
	if expanded == "" {
		expanded = homeDir
	}
	abs, err := filepath.Abs(expanded)
	if err != nil {
		abs = homeDir
	}
	resolved, err := filepath.EvalSymlinks(abs)
	if err != nil {
		resolved = abs
	}
	if !isDir(resolved) {
		resolved = homeDir
	}

	parent := filepath.Dir(resolved)
	if resolved == "/" {
		parent = "/"
	}

	entries := []folderEntry{}
	var readErr string
	items, err := os.ReadDir(resolved)
	if err != nil {
		readErr = err.Error()
	} else {
		// sorted: dirs first, luego name.lower() — igual que Python
		sort.Slice(items, func(i, j int) bool {
			di, dj := items[i].IsDir(), items[j].IsDir()
			if di != dj {
				return di
			}
			return strings.ToLower(items[i].Name()) < strings.ToLower(items[j].Name())
		})
		for _, e := range items {
			name := e.Name()
			if strings.HasPrefix(name, ".") {
				continue
			}
			full := filepath.Join(resolved, name)
			entries = append(entries, folderEntry{
				Name:  name,
				Path:  full,
				IsDir: e.IsDir(),
			})
		}
	}

	resp := folderResponse{Path: resolved, Parent: parent, Entries: entries, Error: readErr}
	out, _ := json.Marshal(resp)
	fmt.Println(string(out))
	return 0
}
