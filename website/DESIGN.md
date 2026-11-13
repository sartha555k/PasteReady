---
name: PasteReady website
description: A quiet web showcase for the native Mac clipboard app.
colors:
  paper: "#fbfcf9"
  ink: "#242e26"
  muted: "#626b61"
  line: "#dce1d8"
  focus: "#566e4f"
  action-hover: "#3c4a3b"
  action-text: "#fff"
  selection: "#dee7d8"
  success: "#3a5b32"
  error: "#8a3529"
  dot: "#b9c3b2"
typography:
  display:
    fontFamily: "Bodoni Moda, serif"
    fontSize: "clamp(48px, 5.3vw, 72px)"
    fontWeight: 400
    lineHeight: 1.08
    letterSpacing: "-.025em"
  headline:
    fontFamily: "Bodoni Moda, serif"
    fontSize: "39px"
    fontWeight: 400
    lineHeight: 1.16
    letterSpacing: "-.02em"
  intro:
    fontFamily: "Hanken Grotesk, sans-serif"
    fontSize: "18px"
    lineHeight: 1.55
  body:
    fontFamily: "Hanken Grotesk, sans-serif"
    fontSize: "15px"
    lineHeight: 1.65
  title:
    fontFamily: "Hanken Grotesk, sans-serif"
    fontSize: "16px"
    fontWeight: 500
  label:
    fontFamily: "Hanken Grotesk, sans-serif"
    fontSize: "14px"
    fontWeight: 500
  command:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "12px"
    lineHeight: 1.85
rounded:
  action: "7px"
  command: "8px"
spacing:
  icon-gap: "9px"
  action-y: "12px"
  action-x: "20px"
  page-gutter: "28px"
  mobile-gutter: "24px"
  feature-row: "32px"
  feature-column: "60px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.action-text}"
    typography: "{typography.label}"
    rounded: "{rounded.action}"
    padding: "12px 20px"
  button-primary-hover:
    backgroundColor: "{colors.action-hover}"
  command-container:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.command}"
    padding: "17px 20px"
  gallery-tab:
    textColor: "{colors.muted}"
    padding: "12px 0 11px"
  gallery-tab-selected:
    textColor: "{colors.ink}"
---

# Design System: PasteReady website

## Overview

**Creative North Star: "Quiet product field"**

A pale field, centered serif introduction, and generous whitespace frame the native app. Supporting text and controls stay compact and plain. The faint dotted introduction provides texture without competing with the app captures.

This document describes only the website boundary. It derives from `dist/style.css`, `dist/index.html`, and `dist/app.js`, with the final desktop capture in `../.impeccable/review/reference-pass/desktop.png` as observational evidence. Native Mac surfaces retain their separate root design system. The user's supplied image establishes restraint, rather than a literal layout to reproduce; the earlier notch-led composition is superseded. The latest surface direction is recorded in the final section of `../.impeccable/surfaces/website-dist-index-html.md`.

**Key Characteristics:**
- Light, subtly green paper with dark green-black text.
- High-contrast serif headings paired with quiet grotesk body text.
- Unframed native app captures and thin rules instead of decorative containers.
- Clear interactive states with limited motion and visible keyboard focus.

## Colors

The palette is nearly neutral with a muted green cast; the frontmatter records the source CSS values.

### Primary
- **Ink:** headings, body foreground, selected gallery tab, and the filled install action.
- **Focus:** the shared keyboard outline, visible against paper.

### Neutral
- **Paper:** the continuous page and expanded command background.
- **Muted:** supporting copy, inactive tabs, and quiet navigation.
- **Line:** command outline, FAQ separators, and footer rule.
- **Action text:** white foreground on the dark filled action.
- **Dot:** the introduction's low-opacity radial pattern.

The action-hover color marks pointer feedback. Success and error colors belong to copy feedback; selection colors selected text. These roles are separate from decorative accents.

**The Quiet Ground Rule.** Keep the page field continuous; use ink, type, space, and fine separators to establish hierarchy.

## Typography

**Display Font:** self-hosted Bodoni Moda, serif fallback, normal weight 400.
**Body Font:** self-hosted Hanken Grotesk, sans-serif fallback, available weights 400–600.
**Command Font:** the platform monospace stack recorded in the frontmatter.

Bodoni Moda's fine contrast gives the introduction its editorial voice. Hanken Grotesk makes navigation, instructions, and native feature descriptions easy to scan. The source fonts use `font-display: swap` and are preloaded by the document.

### Hierarchy
- **Display:** the centered introduction; balanced wrapping, desktop clamp in frontmatter.
- **Headline:** section headings, using the same serif at a smaller scale.
- **Intro:** muted supporting text, limited to 44 characters in width.
- **Body:** feature descriptions; FAQ copy uses a slightly roomier line-height (1.7).
- **Title:** feature terms with medium weight.
- **Label:** primary action; navigation is similarly compact, with gallery labels at 13px and metadata at 12px.
- **Command:** selectable Terminal text, with wrapping permitted anywhere to retain access on small screens.

## Layout

Header and footer are flex rows with wide central bounds; the header's maximum width is 1060px including horizontal padding. The introduction has 116px top padding on desktop. The product region is limited to 650px and the visible capture to 480px; the native image keeps its aspect ratio. Feature content is bounded at 820px and FAQ at 720px, including gutters. The feature list uses two equal columns and the frontmatter's row/column gaps. Major sections use roughly 92–100px of separation.

At 680px and below, the introduction top padding drops to 68px; its title becomes `clamp(44px, 12.5vw, 65px)` with line-height 1.06 and maximum width 500px. Intro text becomes 16px/1.6; section headings become 34px. Feature terms stack in one column with 25px gaps, and the feature heading aligns left for reading. Feature/FAQ gutters are 25px and spacing falls to 64–68px. Capture captions drop their forced line break and wrap naturally; images remain fluid. Footer navigation can wrap. At 1080px and below the footer gets explicit 28px outer margins. These changes preserve readable copy and the same centered product emphasis without squeezing desktop columns into a phone.

## Elevation & Depth

The website adds no box shadows. The native captures carry their own rendered app depth; do not interpret that embedded depth as a website card shadow token. Texture comes from a radial dot field on a 24px grid at opacity .34, fading vertically through a mask. It is confined to the introduction. Fine borders define disclosures and section ends.

## Shapes

The filled action has gently rounded corners; the command disclosure uses a slightly larger radius. Most elements are unboxed. Gallery selection is a thin bottom border rather than a pill. FAQ rows use full-width separators. Icons are fine inline SVG strokes with rounded ends; the site does not use decorative icon tiles.

## Components

### Primary action

Compact and clear: the filled install button has minimum dimensions 226 × 46px, a 9px icon gap, and the colors/padding in frontmatter. Hover changes its background; active moves it down 1px. Its transition is .16s ease-out. The implemented disabled rule reduces opacity and shows a waiting cursor. Copy success changes its text/icon and announces next steps through a polite status region, resetting after seven seconds.

### Command disclosure

An understated text summary exposes a bordered, selectable monospace command. If clipboard access fails, the disclosure opens, the command is selected and focused, and an error status gives manual-copy guidance. The desktop summary's minimum height is 40px, growing to 44px on mobile. The command panel padding falls to 15px on mobile.

### Gallery tabs

Three text buttons select a single native capture panel. The selected label gains an ink underline. A roving tab stop, arrow keys, Home, and End support keyboard selection; panels expose their tab relationships and hide inactive content. A .28s clarity transition fades from .75 opacity and 1.5px blur using `cubic-bezier(.16, 1, .3, 1)`. The capture note identifies sample data and the current development build; keep that visible beside the gallery.

### Navigation

Plain wordmark and compact text links share the header baseline. Pointer hover underlines header/footer links. The footer's secondary links stay muted. A skip link becomes visible on focus.

### Feature index and FAQ

Features use a semantic definition list with medium-weight terms and muted descriptions, without cards. FAQ rows are native details/summary disclosures; their plus rotates 45 degrees when open. No additional animation is applied to their expansion.

All interactive elements use a 2px focus outline with 5px offset. Reduced-motion preference removes transitions and animations and changes smooth scrolling to automatic scrolling.

## Do's and Don'ts

### Do:
- **Do** preserve the continuous pale field and serif/sans role distinction.
- **Do** use thin separators and whitespace before introducing more containers.
- **Do** retain visible keyboard focus and reduced-motion behavior.
- **Do** keep native product imagery unframed and its sample/development provenance clear.

### Don't:
- **Don't** restore the rejected oversized notch-led composition as this website's baseline.
- **Don't** replace real app captures with generated interface imagery.
- **Don't** apply this website's serif and pale field to the separately documented native app.
- **Don't** imply that development-build screenshots prove a newer published release.
