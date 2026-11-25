# Recon map: QR & Barcode Scanner (reference APK)

Target: Android app `com.gamma.scan`, version 2.2.229 (code 229), minSdk 24, targetSdk 36.
Source file: `reference/QR+&+Barcode+Scanner_2.2.229_APKPure.xapk` (base APK SHA-256
`8667087755ca7e9f32c8724f9a13f33bfa122713e8d07ade6b4118f28e0afb38`).
Clone: **ScanLight** (Flutter, Android + iOS). It takes the reference app's features, screens and flows.
It keeps ScanLight's own name, look and **brand kit** (custom QR colour, logo and shape), which the reference app does not have.

## Sources

| source | how | gives |
| --- | --- | --- |
| `AndroidManifest.xml` | REA `decode_android_resources` (apktool 2.12.1) | entry points, share intents, permissions, SDKs (ads, analytics) |
| `res/values/strings.xml` | same | every label, button, setting, dialog and error message |
| `res/layout/*.xml` (28 app layouts) | apktool `--no-src`, read view ids and widget types | what each screen contains |
| `res/menu/main_drawer.xml`, `history.xml` | same | navigation and overflow menus |
| `res/xml/zxing_preferences.xml` | same | all 23 settings keys and defaults |
| `res/drawable/*` names | file list | result actions (`after_*`), history tools (`export_csv`, `import_csv`, `rename`, `reorder`) |
| DEX string table | literal grep only, no decompiling | which barcode formats can be **encoded**, batch-scan and reorder keys |

Not used: decompiled source, network capture, or running the app. Nothing from the APK goes into ScanLight: no code, artwork, icons or copy.
Screen states marked *(inferred)* come from resources only. They have not been confirmed on a device, and `replica/screens/` is still empty.
To confirm them, install the APK on a test phone and capture each screen with Artemis.

## Screen inventory

| ID | screen | how you get there | purpose | key components (from layouts) | states |
| --- | --- | --- | --- | --- | --- |
| S00 | Welcome / consent | first launch | terms + privacy accept | title, text, Privacy Policy and Terms links, Accept | — (ScanLight: replaced by a privacy note, no consent wall) |
| S01 | Setup wizard | after S00, first launch | pick key settings and a colour scheme | list of setting cards with checkboxes, colour scheme picker, Back / Skip / Next | per page |
| S02 | Scanner (home) | launch, drawer "Scan" | live camera scan | full-bleed preview, viewfinder, **top toolbar**: menu (drawer), Scan image, Flash, Flip camera, **Batch scan**, More; zoom bar with − / slider / + | permission rationale, denied ("cannot run without camera"), scanning, detected, batch running with a count |
| S03 | Navigation drawer | menu button on S02 | app navigation | Scan, Scan Image, Favorites, History, My QR, Create QR, Settings, Share app | — |
| S04 | Scan from image | drawer, S02 toolbar, or **sharing an image to the app** | decode a photo | gallery picker → decode | error "Error detecting QR or barcode" |
| S05 | Result | after detection, or a history tap | typed result + actions | header (type icon, type name, time, **Rename**, **Favourite**), content text, supplement text (URL info), **grid of action buttons** (icon + label), Format / Type / Metadata rows, barcode image | one per type: URL, Text, Wi-Fi, Contact, Email, Phone, SMS, Geo, Calendar, Product, ISBN/book |
| S06 | Batch result | end of batch scan | list of codes from one session | "%d codes" header, list | *(inferred)* |
| S07 | History | drawer | every scan, grouped by day | list with **day headers** (Today / Yesterday / date) and a per-day menu (delete that day), item: type icon, title, date, detail, favourite star, context menu; **right-side filter drawer** by type; overflow: Clear history | empty ("No history"), filtered empty ("No data meet the criteria"), multi-select ("%d selected"), delete with Undo |
| S08 | Favorites | drawer | starred items, own list | same as S07 plus **drag to reorder** | empty ("No favorites yet") |
| S09 | Export / import sheet | S07/S08 menu | move history in and out | Export CSV, Export TXT, Export to file, Share export, Import CSV | *(inferred)* |
| S10 | Create: type list | drawer "Create QR", or **sharing text to the app** | choose what to encode | grouped list: "Content from clipboard", QR types (Text, URL, Wi-Fi, Contact, Email, Phone, SMS, Event, Location), "Other types" = barcode formats | — |
| S11 | Create: form | S10 | enter content | per type, see "Create forms" below; ✓ in the toolbar | field errors ("Required", "Invalid entry"), encode error |
| S12 | Create: preview | ✓ on S11 | the generated code | header (type, Rename, Favourite), code image, content text, Save, Share | — |
| S13 | My QR | drawer | your own contact card as a QR | first visit: the contact form with "Share your contact info via QR"; later visits show the code | first-run form, saved |
| S14 | Settings | drawer | preferences | grouped list (see Settings) plus sub-screens S15, S16 | — |
| S15 | Custom action editor | Settings | add a button that opens your own URL with `{code}` | Name, URL, which result types to add it to, Enable, OK | required-field error |
| S16 | Custom search engine | Settings | search URL with `{code}` | URL field, OK | required error |
| S17 | In-app browser | open a link with "Use in-app browser" on | view a page without leaving the app | toolbar title, Refresh, Copy link, "Open in {browser}", web view | loading, error |
| S18 | Rate dialog | after some uses | rating | stars, Not now, Submit; low rating opens feedback | — (ScanLight: no rate prompt) |
| S19 | Wi-Fi connecting | Connect on a Wi-Fi result | join the network | "Requesting connection to network…", permission explainer | asking, connected, failed |
| — | Ads, Remove ads, Our apps, Shop now (Amazon / eBay) | everywhere | monetisation | banner, interstitial, native ads | **not cloned** |

### Create forms (S11)

| type | fields |
| --- | --- |
| Text | multi-line text with a character counter |
| URL | URL (starts with `http://`) |
| Wi-Fi | SSID, password, network type (WPA / WEP / none), Hidden |
| Contact | full name (required), organisation, address, phone, email, notes, **Add from contacts** |
| Email | to, subject, body |
| Phone | number, Add from contacts |
| SMS | number, message |
| Event | name, start date and time, end date and time, all-day, location, description |
| Location | latitude, longitude, query, **Current location** |
| Barcode (Other types) | one value field with a counter and format rules ("Enter 7, 8, 12 or 13 digits") for EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, ITF, Codabar, plus Data Matrix, Aztec, PDF417 |

### Result actions (S05)

Each type shows a row of round icon buttons with labels underneath (from the `after_*` drawables and button strings):

| type | actions |
| --- | --- |
| URL | Open, Share, Copy, plus URL info (page title fetched when "URL info" is on) |
| Text | Web search, Share, Copy |
| Wi-Fi | Connect, Copy password, Share |
| Contact | Add contact, Call, Send email, Show map (address), Share |
| Email | Send email, Copy, Share |
| Phone | Call, Add contact, Copy, Share |
| SMS | Send SMS, Send MMS, Copy, Share |
| Geo | Show map, Get directions, Copy, Share |
| Calendar | Add event, Copy, Share |
| Product / ISBN | Product search / Book search, Web search, Content search (custom), Copy, Share |
| every type | Save (to gallery), any **custom actions** the user added |

### Settings (S14), from `zxing_preferences.xml`

| group | setting | default |
| --- | --- | --- |
| Scanning | Beep | on |
| | Vibrate | off |
| | Copy to clipboard | on |
| | Automatically open URLs | off |
| | Keep duplicates (save repeats to history) | off |
| | URL info (fetch page details) | on |
| | Batch scan mode (adds the batch button to the scanner) | off |
| | Add scans to history | on *(inferred)* |
| Camera | Camera selection ("Camera 1 – recommended") | rear |
| | Use auto focus | on |
| | Touch focus (needs auto focus) | — |
| | Invert scan (white codes on black) | off |
| | Front light mode | off |
| | Orientation lock | on |
| Formats | 1D product codes · 1D industrial codes · QR · Data Matrix · Aztec · PDF417 | on, on, on, on, off, off |
| Search | Search engine (Google, Bing, DuckDuckGo, Ecosia, Yahoo, Yandex, Baidu, Ask) | Google |
| | Search country (product search) | — |
| | Custom search URL (S16) | — |
| | Custom actions (S15) | — |
| Browser | Use in-app browser | on *(inferred)* |
| Appearance | Theme: Device default / Light / Dark | device |
| | Colour scheme (accent swatches) | — |
| About | Privacy Policy, Terms, Share app | — |

## Flows

```
F01 Scan with the camera (core loop)
    S02 -> detect -> beep/vibrate/copy (per settings) -> S05 -> action
    happy path: 0 taps to scan, 1 tap on an action
    edge: no permission, dark (flash), small code (zoom), white-on-black (invert), duplicate
F02 Batch scan
    S02 batch button -> scan many in a row (count shown) -> stop -> S06 -> open any item in S05
F03 Scan an image
    S03 drawer or S02 toolbar -> S04 picker -> S05     |  other app -> Share image -> S04 -> S05
    edge: no code found, several codes
F04 History
    S03 -> S07 -> filter drawer by type / search -> tap -> S05
    swipe or menu delete -> Undo ; per-day menu "delete all from {day}" ; long-press multi-select -> delete ; overflow Clear history (confirm)
F05 Favourites
    S05 star -> S08 ; drag to reorder ; remove all (confirm)
F06 Export and import
    S07 menu -> S09 -> CSV / TXT / file / share ; Import CSV -> merged into history
F07 Create a code
    S03 -> S10 -> S11 (type form, or "Content from clipboard") -> ✓ -> S12 -> Save / Share ; rename, favourite
    other app -> Share text -> S10 with the text prefilled
F08 My QR
    S03 -> S13 first time: fill contact -> ✓ -> code shown on every later visit ; edit
F09 Join Wi-Fi
    S05 Wi-Fi -> Connect -> S19 permission -> system prompt -> connected | failed -> Copy password
F10 Customise actions and search
    S14 -> S15 add "{code}" URL action to chosen result types -> shows on S05
    S14 -> search engine / country / S16 custom URL
F11 First run
    S00 consent -> S01 wizard (settings, colour scheme) -> S02
F12 Open a link
    S05 Open -> S17 in-app browser (refresh, copy, open in default) or the system browser
```

## Components

Top toolbar on the scanner (6 icon buttons) · navigation drawer · zoom bar (− slider +) · viewfinder overlay · result header (type icon, label, time, rename, star) · action button grid (circle icon + label) · key/value info rows (format, type, metadata) · history row (icon, title, date, detail, star, menu, check, drag handle) · day header with menu · right filter drawer (type icon + name) · grouped create list (icon, title, divider, group header) · form fields with inline "Required" error · date and time pickers · checkbox · spinner (network type) · settings card (title, description, checkbox) · colour scheme swatch with check · snackbar with Undo · confirm dialog ("Are you sure…") · options popup · rating bar.

## Inferred data model

```
ScanRecord   id, source (camera | image | created | batch), format, type, raw, parsed (json),
             title (renamable), favorite, favorite_order, batch_id?, created_at, updated_at
             evidence: rename_button, favorite_mark, reorder_icon, bulk_id, history_item_reorder
             confidence: high
CustomAction id, name, url_template ("{code}"), types (set of content types), enabled
             evidence: fragment_custom_action_layout, custom_action_explain2   confidence: high
MyQr         one vCard (name, org, address, phone, email, note)
             evidence: generate_contact + my_qr strings                        confidence: high
Settings     the 23 keys above + search engine, country, custom search URL, theme, colour scheme
             evidence: zxing_preferences.xml                                   confidence: high
```

## Not cloned (skip)

| item | reason |
| --- | --- |
| AdMob, Facebook Audience Network and Vungle ads, "Remove ads", the paid no-ads app | ScanLight is ad-free |
| Firebase Analytics, ad ID, install referrer | no tracking |
| GDPR consent wall | nothing is collected, so a short privacy note is enough |
| Rate prompt, "Our apps", "Like" | not needed |
| Amazon / eBay "Shop now" affiliate buttons | affiliate deals; plain web search covers it |
| Original name, icon, colours, copy | brand belongs to the original |

## ScanLight additions (kept)

- **Brand kit:** a logo from photos or from a website, a colour taken from the logo or picked by swatch or hex, dots or squares, saved and applied to any created code.
- QR style presets (Classic, Dots, Colour, Badge, Ink) and the share card.
- Link safety warnings, and a privacy screen.
- Collection, stats and the 7-day chart: these move to History (could).

## Size

20 screens (S00–S19, two of them replaced), 12 flows, 4 entities.

The hard parts:
1. Batch scanning while staying lifecycle-safe.
2. Encoding 12 barcode formats with per-format validation.
3. Custom actions with `{code}` templates, applied per result type.
4. Android share-intent entry points (text → create, image → scan).
5. Drag reordering of favourites.

Everything else exists in ScanLight already. Size: **M** (a few weeks) on top of the current app.
