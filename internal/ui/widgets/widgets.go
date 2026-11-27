// Package widgets holds the app's shared look: headers, rows, cards and
// empty states, drawn with ApiGo's design language.
package widgets

import (
	"github.com/egoist/mygo/ui"

	"itools/internal/ui/icons"
	"itools/internal/ui/theme"
)

// PageHeader draws a page's title, subtitle, optional back button and actions
// in a 48 DIP bar over a hairline divider.
func PageHeader(
	c *ui.Context,
	p theme.Palette,
	title string,
	subtitle string,
	onBack func(),
	actions func(),
) ui.Element {
	return ui.Column(c).FillWidth().Children(func() {
		ui.Row(c).
			FillWidth().
			Height(48).
			Background(p.Card).
			Padding(0, 20).
			Gap(10).
			AlignItems(ui.Center).
			Children(func() {
				if onBack != nil {
					IconButton(c, p, "chevron-left", onBack)
				}
				ui.Column(c).Grow(1).Gap(1).Children(func() {
					ui.Text(c, title).FontSize(theme.FontSizeTitle).FontWeight(600).TextColor(p.Foreground)
					if subtitle != "" {
						ui.Text(c, subtitle).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
					}
				})
				if actions != nil {
					actions()
				}
			})
		Divider(c, p)
	})
}

// Divider is the one-DIP line between regions.
func Divider(c *ui.Context, p theme.Palette) ui.Element {
	return ui.Row(c).FillWidth().Height(1).Background(p.Divider)
}

// SectionHeader labels a group of cards.
func SectionHeader(c *ui.Context, p theme.Palette, title, subtitle, icon string) ui.Element {
	return ui.Row(c).FillWidth().Gap(8).AlignItems(ui.Center).Children(func() {
		if icon != "" {
			ui.Icon(c, icons.Must(icon)).Width(14).Height(14).TextColor(p.MutedForeground)
		}
		ui.Column(c).Gap(1).Children(func() {
			ui.Text(c, title).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
			if subtitle != "" {
				ui.Text(c, subtitle).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
			}
		})
	})
}

// FieldLabel is the 11 DIP label over a form field.
func FieldLabel(c *ui.Context, p theme.Palette, text string) ui.Element {
	return ui.Text(c, text).FontSize(theme.FontSizeTiny).FontWeight(600).TextColor(p.MutedForeground)
}

// SurfaceCard is a static card: a surface, a hairline border and no shadow.
func SurfaceCard(c *ui.Context, p theme.Palette, child func()) ui.Element {
	card := ui.Box(c).
		Background(p.Card).
		Border(1, p.Border).
		Radius(p.Radius).
		Padding(16)
	card.Children(child)
	return card
}

// InteractiveCard is a card that reacts to the pointer and clicks.
func InteractiveCard(c *ui.Context, p theme.Palette, onClick func(), child func()) ui.Element {
	card := ui.Box(c).
		Background(p.Card).
		Border(1, p.Border).
		Radius(p.Radius).
		Padding(16).
		OnClick(onClick)
	if card.Hovered() {
		card.Background(p.CardHover)
	}
	card.Children(child)
	return card
}

// IconContainer is the icon tile used by cards and settings rows.
func IconContainer(c *ui.Context, p theme.Palette, icon string) ui.Element {
	return ui.Box(c).
		Size(32, 32).
		Radius(theme.RadiusIconBox).
		Background(p.Secondary).
		AlignItems(ui.Center).
		Justify(ui.Center).
		Children(func() {
			ui.Icon(c, icons.Must(icon)).Width(16).Height(16).TextColor(p.Primary)
		})
}

// MenuCard is a list row: an icon, a title, a description and a chevron,
// closed by a hairline divider as ApiGo's list rows are.
func MenuCard(c *ui.Context, p theme.Palette, icon, title, description string, onClick func()) ui.Element {
	return ui.Column(c).FillWidth().Children(func() {
		row := ui.Row(c).
			FillWidth().
			Height(52).
			Padding(0, 4).
			Gap(12).
			AlignItems(ui.Center).
			OnClick(onClick)
		if row.Hovered() {
			row.Background(p.CardHover)
		}
		row.Children(func() {
			IconContainer(c, p, icon)
			ui.Column(c).Grow(1).Gap(1).Children(func() {
				ui.Text(c, title).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
				if description != "" {
					ui.Text(c, description).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
				}
			})
			ui.Icon(c, icons.Must("chevron-right")).Width(14).Height(14).TextColor(p.MutedForeground)
		})
		Divider(c, p)
	})
}

// EmptyState fills a card with a short explanation.
func EmptyState(c *ui.Context, p theme.Palette, icon, title, description string) ui.Element {
	return SurfaceCard(c, p, func() {
		ui.Column(c).FillWidth().Padding(20, 24).Gap(8).AlignItems(ui.Center).Children(func() {
			ui.Row(c).
				Size(56, 56).
				Radius(16).
				Background(p.CardHover).
				AlignItems(ui.Center).
				Justify(ui.Center).
				Children(func() {
					ui.Icon(c, icons.Must(icon)).Width(24).Height(24).TextColor(p.Primary)
				})
			ui.Text(c, title).FontSize(theme.FontSizeHeading).FontWeight(600).TextColor(p.Foreground)
			if description != "" {
				ui.Text(c, description).
					FontSize(theme.FontSizeBody).
					TextColor(p.MutedForeground).
					TextAlign(ui.Center)
			}
		})
	})
}

// StatusBadge is a small tinted label, as the status of a task shows.
func StatusBadge(c *ui.Context, p theme.Palette, label string, color ui.Color) ui.Element {
	return ui.Row(c).
		Padding(6, 2).
		Radius(theme.RadiusSmall).
		Background(color.Alpha(0.12)).
		Children(func() {
			ui.Text(c, label).FontSize(theme.FontSizeTiny).FontWeight(600).TextColor(color)
		})
}

// IconButton is a compact square button holding one icon.
func IconButton(c *ui.Context, p theme.Palette, icon string, onClick func()) ui.Element {
	button := ui.Box(c).
		Size(28, 28).
		Radius(theme.RadiusSmall).
		AlignItems(ui.Center).
		Justify(ui.Center).
		OnClick(onClick)
	if button.Hovered() {
		button.Background(p.CardHover)
	}
	button.Children(func() {
		ui.Icon(c, icons.Must(icon)).Width(15).Height(15).TextColor(p.MutedForeground)
	})
	return button
}
