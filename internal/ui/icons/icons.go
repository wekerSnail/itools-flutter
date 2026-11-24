// Package icons embeds the SVG icons the app draws.
package icons

import (
	"embed"
	"fmt"
	"path"
	"strings"
	"sync"

	"github.com/egoist/mygo/ui"
)

//go:embed svg/*.svg
var files embed.FS

var (
	once  sync.Once
	cache map[string]*ui.SVG
)

func load() {
	cache = make(map[string]*ui.SVG)
	entries, err := files.ReadDir("svg")
	if err != nil {
		return
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		data, err := files.ReadFile(path.Join("svg", entry.Name()))
		if err != nil {
			continue
		}
		svg, err := ui.ParseSVG(data)
		if err != nil {
			continue
		}
		cache[strings.TrimSuffix(entry.Name(), ".svg")] = svg
	}
}

// Get returns the named icon, or nil when it is not embedded.
func Get(name string) *ui.SVG {
	once.Do(load)
	return cache[name]
}

// Must returns the named icon and panics when it is not embedded.
func Must(name string) *ui.SVG {
	svg := Get(name)
	if svg == nil {
		panic(fmt.Sprintf("icons: %q is not embedded", name))
	}
	return svg
}
