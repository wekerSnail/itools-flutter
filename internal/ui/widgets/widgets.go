// Package widgets holds the app's shared look: headers, cards and empty states.
package widgets

import (
	"github.com/egoist/mygo/ui"

	"itools/internal/ui/icons"
	"itools/internal/ui/theme"
)

// PageHeader draws a page's title, subtitle, optional back button and actions.
func PageHeader(
	c *ui.Context,
	p theme.Palette,
	title string,
	subtitle string,
	onBack func(),
	actions func(),
) ui.Element {
	return ui.Row(c).FillWidth().Padding(14, 20).Gap(10).AlignItems(ui.Center).Children(func() {
		if onBack != nil {
			IconButton(c, p, "chevron-left", onBack)
		}
		ui.Column(c).Grow(1).Gap(2).Children(func() {
			ui.Text(c, title).FontSize(18).FontWeight(600).TextColor(p.Foreground)
			if subtitle != "" {
				ui.Text(c, subtitle).FontSize(12).TextColor(p.MutedForeground)
			}
		})
		if actions != nil {
			actions()
		}
	})
}

// SectionHeader labels a group of cards.
func SectionHeader(c *ui.Context, p theme.Palette, title, subtitle, icon string) ui.Element {
	return ui.Row(c).FillWidth().Gap(10).AlignItems(ui.Center).Children(func() {
		ui.Icon(c, icons.Must(icon)).Width(16).Height(16).TextColor(p.Primary)
		ui.Column(c).Gap(1).Children(func() {
			ui.Text(c, title).FontSize(15).FontWeight(600).TextColor(p.Foreground)
			if subtitle != "" {
				ui.Text(c, subtitle).FontSize(12).TextColor(p.MutedForeground)
			}
		})
	})
}

// SurfaceCard is a static card.
func SurfaceCard(c *ui.Context, p theme.Palette, child func()) ui.Element {
	card := ui.Box(c).Background(p.Card).Border(1, p.Border).Radius(p.Radius).Padding(14)
	card.Children(child)
	return card
}

// InteractiveCard is a card that reacts to the pointer and clicks.
func InteractiveCard(c *ui.Context, p theme.Palette, onClick func(), child func()) ui.Element {
	card := ui.Box(c).Background(p.Card).Border(1, p.Border).Radius(p.Radius).Padding(14).OnClick(onClick)
	if card.Hovered() {
		card.Background(p.CardHover)
		card.Border(1, p.Ring)
		card.Shadow(0, 2, 8, 0, p.Foreground.Alpha(0.08))
	}
	card.Children(child)
	return card
}

// IconContainer is the icon tile used by cards and settings rows.
func IconContainer(c *ui.Context, p theme.Palette, icon string) ui.Element {
	return ui.Box(c).
		Size(34, 34).
		Radius(9).
		Background(p.Secondary.Alpha(0.45)).
		AlignItems(ui.Center).
		Justify(ui.Center).
		Children(func() {
			ui.Icon(c, icons.Must(icon)).Width(16).Height(16).TextColor(p.SecondaryForeground)
		})
}

// MenuCard is a settings entry: an icon, a title, a description and a chevron.
func MenuCard(c *ui.Context, p theme.Palette, icon, title, description string, onClick func()) ui.Element {
	return InteractiveCard(c, p, onClick, func() {
		ui.Row(c).FillWidth().Gap(12).AlignItems(ui.Center).Children(func() {
			IconContainer(c, p, icon)
			ui.Column(c).Grow(1).Gap(2).Children(func() {
				ui.Text(c, title).FontSize(14).FontWeight(600).TextColor(p.Foreground)
				ui.Text(c, description).FontSize(12).TextColor(p.MutedForeground)
			})
			ui.Icon(c, icons.Must("chevron-right")).Width(14).Height(14).TextColor(p.MutedForeground)
		})
	})
}

// EmptyState fills a card with a short explanation.
func EmptyState(c *ui.Context, p theme.Palette, icon, title, description string) ui.Element {
	return SurfaceCard(c, p, func() {
		ui.Column(c).FillWidth().Padding(10).Gap(8).AlignItems(ui.Center).Children(func() {
			IconContainer(c, p, icon)
			ui.Text(c, title).FontSize(14).FontWeight(600).TextColor(p.Foreground)
			ui.Text(c, description).FontSize(12).TextColor(p.MutedForeground).TextAlign(ui.Center)
		})
	})
}

// IconButton is a compact square button holding one icon.
func IconButton(c *ui.Context, p theme.Palette, icon string, onClick func()) ui.Element {
	button := ui.Box(c).Size(28, 28).Radius(7).AlignItems(ui.Center).Justify(ui.Center).OnClick(onClick)
	if button.Hovered() {
		button.Background(p.Muted)
	}
	button.Children(func() {
		ui.Icon(c, icons.Must(icon)).Width(15).Height(15).TextColor(p.MutedForeground)
	})
	return button
}
