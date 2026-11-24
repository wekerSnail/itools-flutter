// Package assets embeds the images the app ships with.
package assets

import _ "embed"

// TrayPNG is the 32x32 tray icon.
//
//go:embed tray.png
var TrayPNG []byte
