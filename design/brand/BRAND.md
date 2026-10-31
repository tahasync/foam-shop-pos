# Foam Shop — Brand Guide (v1.5.6, flat)

> See `brand/brand-board.png`. Everything in this kit is generated from **one geometry**
> (`brand/mark.json`), so the icon, launcher layers, splash, notification icon, web icons and
> in-app mark cannot drift apart.
>
> **Style: flat, solid colour. No glassmorphism** — no gradients, transparency, blur, glow or
> shadows inside any logo or icon file. The app's own UI (theme, layout, cards) is untouched.

---

## 1. Name & voice

| | |
|---|---|
| **Product name** | **Foam Shop** |
| **Descriptor** | Digital Register |
| **Tagline** | Every sale. Every stock. Every khata. |
| **Android label** | `Foam Shop` (was `Foam Shop POS`) |
| **applicationId / Dart package** | unchanged — `com.asif.foamshop`, `foam_shop_register` |

Voice: plain, calm, confident. Short sentences, numbers first. Roman-Urdu business terms stay as
they are (Baqaya, Khata, Kharcha).

---

## 2. The mark — "Foam Layers"

Three stacked, slightly staggered slabs: the layers of a foam mattress and the stacked rows of a
ledger. The top slab is Foam White and carries three small pores; below it a Dusty Mauve slab and a
Periwinkle slab. A thin cut-out gap separates the layers, so every layer reads clearly with no
outline and no shadow.

**Construction** (1024 × 1024 design space)

| Part | Value |
|---|---|
| Slab | 600 × 224, corner radius 80 |
| Origins (x, y) | bottom 178, 528 · middle 212, 404 · top 246, 280 |
| Gap between layers | 24 |
| Pores (on the top slab, from its origin) | (470, 120) r 26 · (520, 82) r 15 · (428, 88) r 10 |
| App-icon corner radius | 232 (22.7 %) |
| Accent disc (icon only) | centre (968, 996), r 262, Slate Blue — sits in the corner, clear of the stack |

| Variant | File | Use |
|---|---|---|
| App icon (squircle) | `icon/app-icon.svg`, `icon/app-icon-1024.png` | README, web, in-app |
| App icon (full-bleed) | `icon/app-icon-square.svg`, `icon/app-icon-square-1024.png` | Store uploads, iOS, icon-tool master |
| Mark on dark | `brand/mark-on-dark.svg` | On Deep Ink / Deep Navy: Foam White · Mauve · Periwinkle |
| Mark on light | `brand/mark-on-light.svg` | On Foam White: Deep Navy · Slate Blue · Periwinkle |
| Mono white / mono ink | `brand/mark-mono-white.svg`, `…-ink.svg` | One colour: layers separated by cut-outs, pores as holes |
| Wordmark | `brand/wordmark-on-{dark,light}.svg` | With the descriptor line |
| Lockup | `brand/lockup-on-{dark,light}.svg` | Headers, store listing, slides |

The mono variant is a **different drawing on purpose**: three plain filled slabs would fuse into one
blob (and plain bars read as a menu icon), so the mono mark relies on the gaps.

**Rules**
- Clear space = the height of the top layer, on every side. Minimum: icon 32 px, mark 24 px tall, wordmark 96 px wide.
- Never recolour layers, add shadows or gradients, rotate, stretch, or put the dark-ramp mark on a light background (use *mark on light*).
- Below 32 px use the mono mark.

---

## 3. Colour — the app's existing palette, nothing new

| Token | Hex | Role in the brand |
|---|---|---|
| Deep Ink | `#0E0D15` | Dark panels, text |
| Deep Navy | `#182346` | Icon field, "Foam" in the light wordmark |
| Slate Blue | `#3D5387` | Accent disc, "Shop" in the light wordmark |
| Periwinkle | `#7C83AD` | Bottom layer, descriptor on dark |
| Dusty Mauve | `#BFA9BA` | Middle layer, pores, "Shop" in the dark wordmark |
| Foam White | `#F7F4F2` | Top layer, light page, "Foam" in the dark wordmark |

Wordmark: **Foam** in the strong colour, **Shop** in the second colour — two solid colours, no opacity.

---

## 4. Typography

Manrope (already bundled in `assets/fonts/`): **Foam** ExtraBold 800, **Shop** Medium 500, descriptor
SemiBold 600 at +30 % tracking, uppercase. All wordmark files have the glyphs converted to outlines, so
they render the same without the font installed. UI text is unchanged (Inter / Manrope per the theme).

---

## 5. Where each file goes

| Kit folder | Goes to | Notes |
|---|---|---|
| `android-res/` | `android/app/src/main/res/` | Drop-in. Vector icon layers, splash, colours, Android 12 splash styles, legacy PNGs |
| `web/` | `web/` (icons into `web/icons/`) | Manifest uses `#182346` theme, `#F7F4F2` background |
| `ios/AppIcon.appiconset/` | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | Same filenames as today; opaque, full-bleed |
| `store/` | stays in `design/brand/store/` | Play icon 512, App Store 1024, feature graphic 1024 × 500 (no invented figures) |
| everything | `design/brand/` | Not bundled into the app |

The in-app `BrandMark` is **painted by code** (no asset, no async load, no flash). Its constants mirror
`brand/mark.json`; a test keeps them equal.

## 6. Android icon system

| Layer | File | Notes |
|---|---|---|
| Background | `drawable/ic_launcher_background.xml` | Deep Navy + flat Slate disc; full-bleed, not pre-rounded |
| Foreground | `drawable/ic_launcher_foreground.xml` | Mark scaled ×0.86 about the centre: every slab corner stays inside the 72 dp circular mask |
| Monochrome | `drawable/ic_launcher_monochrome.xml` | Android 13+ themed icon |
| Legacy | `mipmap-*/ic_launcher{,_round}.png` | Pre-API-26, 48 → 192 px |
| Notification | `drawable/ic_stat_foam_shop.xml` | 24 dp, white on transparent, no pores |
| Splash | `drawable/splash_icon.xml` + `values*/brand_colors.xml` | Navy disc badge on the app's own page colour (light `#F7F4F2`, dark `#14141A`) so the hand-off to the first Flutter frame has no colour jump |

`preview/android-masks.png` shows the layers under a circle mask, a squircle mask, the themed (mono)
form, and the splash on light and dark. It is drawn from the same geometry, not rendered by Android.

## 7. Regenerating

`source/`: `geo.py` (geometry + colour), `text.py` (outlined type), `build.py` (all files), `board.py`
(brand board + feature graphic). Needs `cairosvg pillow fonttools shapely`. Run from `source/` with
`FOAM_FONTS=<repo>/assets/fonts/ python3 build.py && python3 board.py`; output goes to `out/`. If you
change the geometry, regenerate **every** file together — never hand-edit one variant.
