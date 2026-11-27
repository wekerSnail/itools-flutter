package main

import (
	"log"

	"github.com/egoist/mygo"
	// Link MyGo's Chinese strings (editor menus, dialogs) for apps that
	// ship 简体中文.
	_ "github.com/egoist/mygo/locales/zh-Hans"
	"github.com/egoist/mygo/ui"

	"itools/assets"
	"itools/internal/app"
	"itools/internal/ui/theme"
)

func main() {
	// The interface font is embedded: a text system that cannot add it
	// falls back to the system's, so a failure is not fatal.
	if err := ui.RegisterFont(assets.InterVariable, theme.FontName); err != nil {
		log.Printf("load interface font, using the system's: %v", err)
	}

	if !mygo.App.RequestSingleInstanceLock() {
		return
	}

	// The app is written in Chinese: without this its language resolves to
	// English and MyGo's own strings, as the editor's context menu, stay
	// English whatever SetLocale asks for.
	mygo.App.SetLanguages("zh-Hans")
	mygo.App.SetLocale("zh-Hans")

	application := app.New()
	mygo.App.OnSecondInstance(func(args []string, workingDir string) {
		application.ShowMain()
	})
	mygo.App.WhenReady(application.Start)

	if err := mygo.App.Run(); err != nil {
		log.Fatal(err)
	}
}
