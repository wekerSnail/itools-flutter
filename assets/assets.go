// Package assets embeds the images and fonts the app ships with.
package assets

import _ "embed"

// TrayPNG is the 32x32 tray icon.
//
//go:embed tray.png
var TrayPNG []byte

// InterVariable is the interface font, embedded rather than installed so
// every platform shows the same Latin shapes. Glyphs it does not cover,
// Chinese above all, fall back to the system's fonts.
//
//go:embed fonts/InterVariable.ttf
var InterVariable []byte

// InterLicense is the SIL Open Font License the interface font ships under.
//
//go:embed fonts/OFL.txt
var InterLicense string
