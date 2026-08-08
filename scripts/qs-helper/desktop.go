package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// appInfo replica el dict retornado por parse_desktop.
type appInfo struct {
	name     string
	exec     string
	icon     string
	generic  string
	keywords string
}

var (
	reNoDisplay  = regexp.MustCompile(`(?m)^NoDisplay=true`)
	reHidden     = regexp.MustCompile(`(?m)^Hidden=true`)
	reName       = regexp.MustCompile(`(?m)^Name=(.+)$`)
	reExec       = regexp.MustCompile(`(?m)^Exec=(.+)$`)
	reIcon       = regexp.MustCompile(`(?m)^Icon=(.+)$`)
	reGeneric    = regexp.MustCompile(`(?m)^GenericName=(.+)$`)
	reKeywords   = regexp.MustCompile(`(?m)^Keywords=(.+)$`)
	reFieldCodes = regexp.MustCompile(`%[a-zA-Z]`)
)

// parseDesktop lee un archivo .desktop y retorna appInfo, o nil si debe ocultarse.
func parseDesktop(path string) *appInfo {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	content := string(data)
	if reNoDisplay.MatchString(content) || reHidden.MatchString(content) {
		return nil
	}
	nameM := reName.FindStringSubmatch(content)
	execM := reExec.FindStringSubmatch(content)
	if len(nameM) < 2 || len(execM) < 2 {
		return nil
	}
	info := &appInfo{
		name: strings.TrimSpace(nameM[1]),
		exec: strings.TrimSpace(reFieldCodes.ReplaceAllString(strings.TrimSpace(execM[1]), "")),
	}
	if m := reIcon.FindStringSubmatch(content); len(m) > 1 {
		info.icon = strings.TrimSpace(m[1])
	}
	if m := reGeneric.FindStringSubmatch(content); len(m) > 1 {
		info.generic = strings.TrimSpace(m[1])
	}
	if m := reKeywords.FindStringSubmatch(content); len(m) > 1 {
		info.keywords = strings.TrimSpace(m[1])
	}
	return info
}

// appDirs replica APP_DIRS del Python.
func appDirs() []string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "~"
	}
	return []string{
		"/usr/share/applications",
		filepath.Join(home, ".local/share/applications"),
	}
}

// scanApps recorre los dirs de aplicaciones y devuelve apps únicas por nombre
// (el primer dir gana), igual que el modo --list-apps del Python.
func scanApps() []appInfo {
	seen := map[string]bool{}
	apps := []appInfo{}
	for _, d := range appDirs() {
		entries, err := os.ReadDir(d)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() || filepath.Ext(e.Name()) != ".desktop" {
				continue
			}
			info := parseDesktop(filepath.Join(d, e.Name()))
			if info == nil || seen[info.name] {
				continue
			}
			seen[info.name] = true
			apps = append(apps, *info)
		}
	}
	return apps
}
