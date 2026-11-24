package main

import (
	"log"

	"github.com/egoist/mygo"
	// Link MyGo's Chinese strings (editor menus, dialogs) for apps that
	// ship 简体中文.
	_ "github.com/egoist/mygo/locales/zh-Hans"

	"itools/internal/app"
)

func main() {
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
