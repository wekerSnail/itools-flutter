// Package widgets holds the app's shared look: headers, rows, cards and
// empty states, drawn with ApiGo's design language.
package widgets

import (
	"time"

	"github.com/egoist/mygo/ui"

	"itools/internal/ui/icons"
	"itools/internal/ui/theme"
)

// PageHost draws one page of a window's in-place page stack, sliding the
// page in the way the navigation went: 1 into a sub-page from the right, -1
// back from the left. key must change with the page, as settings and the
// scheduler do; the page leaving fades out without a trail.
func PageHost(c *ui.Context, key any, direction int, child func()) ui.Element {
	if direction == 0 {
		direction = 1
	}
	host := ui.Box(c).
		Fill().
		Key(key).
		Transition(ui.ElementTransition{
			Duration: 200 * time.Millisecond,
			Enter:    &ui.Motion{X: 24 * float32(direction), Opacity: 1},
			Exit:     &ui.Motion{Opacity: 0},
		})
	host.Children(child)
	return host
}

// Button draws a secondary button in ApiGo's look: 32 DIPs tall, a hairline
// border over the surface and the tighter control radius.
func Button(c *ui.Context, label string) ui.Element {
	return ui.Button(c, label).
		Height(theme.ControlHeight).
		Padding(0, theme.ControlPaddingX).
		Radius(theme.RadiusControl).
		Cursor(ui.CursorPointer)
}

// PrimaryButton draws the accent-filled button of a page's main action, with
// the same size as Button.
func PrimaryButton(c *ui.Context, label string) ui.Element {
	return ui.PrimaryButton(c, label).
		Height(theme.ControlHeight).
		Padding(0, theme.ControlPaddingX).
		Radius(theme.RadiusControl).
		Cursor(ui.CursorPointer)
}

// Segmented draws ApiGo's segmented control: a quiet track with the chosen
// segment raised as a bordered card. Its segments are as wide as their
// labels, so the control never leaves empty track beside them.
func Segmented(c *ui.Context, p theme.Palette, selected *int, labels ...string) ui.Element {
	parts := ui.SegmentedBase(c, selected, len(labels))
	track := parts.Track.
		Height(theme.ControlHeight).
		Padding(3).
		Gap(2).
		Radius(theme.RadiusControl).
		Background(p.Muted).
		AlignSelf(ui.Start).
		AlignItems(ui.Stretch)
	track.Children(func() {
		for index, label := range labels {
			index, label := index, label
			chosen := index == *selected
			segment := parts.Segment(index).
				Height(theme.ControlHeight-6).
				Padding(0, 12).
				Radius(theme.RadiusControl - 1).
				Cursor(ui.CursorPointer)
			if chosen {
				segment.Background(p.Background).Border(1, p.Border)
			}
			segment.Children(func() {
				color := p.MutedForeground
				weight := 400
				if chosen {
					color = p.Foreground
					weight = 500
				}
				ui.Text(c, label).
					FontSize(theme.FontSizeBody).
					FontWeight(weight).
					TextColor(color).
					SingleLine()
			})
		}
	})
	return track
}

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
			Height(theme.HeaderHeight).
			Background(p.Background).
			Padding(0, theme.PagePadding).
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
		Background(p.Background).
		Border(1, p.Border).
		Radius(p.Radius).
		Padding(16)
	card.Children(child)
	return card
}

// InteractiveCard is a card that reacts to the pointer and clicks.
func InteractiveCard(c *ui.Context, p theme.Palette, onClick func(), child func()) ui.Element {
	card := ui.Box(c).
		Background(p.Background).
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
			Height(theme.ListRowHeight).
			Padding(0, 8).
			Radius(theme.RadiusControl).
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
		Size(theme.IconButtonSize, theme.IconButtonSize).
		Radius(theme.RadiusControl).
		AlignItems(ui.Center).
		Justify(ui.Center).
		Cursor(ui.CursorPointer).
		OnClick(onClick)
	if button.Hovered() {
		button.Background(p.CardHover)
	}
	button.Children(func() {
		ui.Icon(c, icons.Must(icon)).Width(14).Height(14).TextColor(p.MutedForeground)
	})
	return button
}
