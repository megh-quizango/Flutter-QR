# PRD: ScanLight, QR & Barcode Scanner (Flutter) — v2

Version 2.0 · 2026-11-25 · Android + iOS · Replaces `PRD-flutter.md` v1.0 (the UI and motion addendum
still applies)

**What changed in v2:**
- The screens, features and flows now match the reference app in `reference/`, mapped in
  `replica/recon.md` (screen IDs S00–S19, flows F01–F12) and scored in `replica/features.csv`.
- The ScanLight-only features stay: the brand kit, style presets, share card, link safety and the
  collection.
- Ads, tracking, the consent wall and rate prompts are left out.

---

## 1. Summary

ScanLight is a fast, private and **ad-free** QR and barcode scanner. It opens straight on the camera:
point it at a code, or share an image to the app, and you get a typed result with one-tap actions.
It can also batch-scan many codes in a row.

Every scan goes into a day-grouped history with favourites, type filters, and export and import.

You can create QR codes and 12 barcode formats, keep your own contact card as **My QR**, and add custom
actions that send a code to any URL.

Created codes can carry your **brand**: a logo, a colour and a shape.

This is a functional rebuild of the reference app (`com.gamma.scan` 2.2.229). It copies the features
and flow, never the brand, artwork, code or copy. It differs on purpose in five ways:
- no ads;
- no tracking;
- no consent wall;
- no paid "remove ads" app;
- the brand kit.

## 2. Goals and non-goals

**Goals**
- G1. Cold start to a decoded result in under 2 seconds on a mid-range Android phone.
- G2. Decode every format ML Kit supports, and let the user turn format groups off.
- G3. Typed results with native actions for 10 content types plus books (ISBN), and user-defined
  custom actions.
- G4. Fully offline, with no account and no backend.
- G5. Create QR codes for 9 content types, plus 12 barcode formats, and save or share them as images.
- G6. Parity with the reference app on every `must` and `should` row in `replica/features.csv`.

**Non-goals**
- Ads, paywalls, IAP, analytics SDKs, the ad ID, a consent wall, rate prompts, "Our apps".
- Affiliate shopping buttons.
- Web or desktop builds, and cloud sync.

## 3. Users

| persona | need |
| --- | --- |
| Everyday scanner | Scan a menu, poster or coupon quickly and safely |
| Shopper or reader | Scan a product barcode or a book ISBN and look it up |
| Café or hotel guest | Join Wi-Fi from a QR without typing the password |
| Stock taker or event staff | **Batch scan** many codes in a row, then export them |
| Small business owner | Make **branded** codes for Wi-Fi, a website or a contact card, and print product barcodes |
| Networker | Show **My QR** so people can save their contact details in one scan |

## 4. Tech stack

Unchanged from v1, with these additions:

| concern | choice |
| --- | --- |
| Framework | Flutter (stable 3.x, Dart 3), Material 3, Riverpod, go_router |
| Scanner | `mobile_scanner`: live scan, torch, zoom, switch camera, `analyzeImage`, `invertImage`, `formats` |
| QR rendering | `qr_flutter` + `RepaintBoundary.toImage` (ScanLight presets and brand kit) |
| **Barcode encoding (new)** | `barcode_widget` / `barcode`: EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, ITF, Codabar, Data Matrix, Aztec, PDF417 |
| **Share-intent entry (new)** | `receive_sharing_intent`: `SEND text/*` opens Create, `SEND image/*` scans the image |
| **Current location (new)** | `geolocator`, asked for only when the user taps "Current location" |
| **Contact picker (new)** | `flutter_contacts` `openExternalPick()` for "Add from contacts" |
| **File export and import (new)** | `file_picker` (import CSV, save to file); `share_plus` (share the export) |
| Join Wi-Fi | `wifi_iot` (Android), `plugin_wifi_connect` (iOS) |
| Contacts and calendar | `flutter_contacts`, `add_2_calendar` |
| Gallery and share | `gal`, `share_plus` |
| Links | `url_launcher` (in-app browser view, or the system browser) |
| Storage | `sqflite` (history, custom actions) + `shared_preferences` (settings, brand kit, My QR) |
| Product lookup | Open Food Facts API with `http`, no backend |
| Link info (new, off by default) | `http` GET of the page, reading only `<title>` and the description; 4-second timeout; 1 MB cap |

Platform notes:
- Android: minSdk 24.
- Permissions:
  - `CAMERA`.
  - `ACCESS_WIFI_STATE` and `CHANGE_WIFI_STATE`.
  - `ACCESS_FINE_LOCATION`, requested only for "Current location", or where `wifi_iot` needs it.
- Intent filters for `SEND text/*` and `SEND image/*`.
- iOS 13+: a Share Extension for text and images, plus the v1 usage strings and
  `NSLocationWhenInUseUsageDescription`.

## 5. Navigation

The app **opens on the Scanner (S02)**. A **navigation drawer (S03)** replaces the v1 bottom tabs. Its
entries, in this order:

| entry | screen |
| --- | --- |
| Scan | S02 Scanner |
| Scan image | S04 (gallery picker) |
| Favourites | S08 |
| History | S07 |
| My QR | S13 |
| Create | S10 |
| Settings | S14 |
| Share app | system share sheet |

- On phones the drawer is modal and opens from the menu button on the scanner toolbar.
- From 840 dp wide it becomes a permanent drawer. Between 600 and 840 dp it becomes a navigation rail.
- Pushed screens: S05 Result, S06 Batch review, S11 Create form, S12 Created code, S15 Custom action
  editor, S16 Custom search URL, S17 In-app browser, the brand sheet, Privacy and Licences.
- Back from any drawer destination returns to the Scanner.

## 6. Functional requirements

Priorities: **P0** = must ship, **P1** = should, **P2** = could. The **New** column marks work that
the current build does not have yet.

### 6.1 First run (S00, S01)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-ONB-1 | First launch shows a one-screen privacy note ("Everything stays on this phone. No ads, no account."), then Continue. There is no accept wall. | P1 | yes |
| R-ONB-2 | A 3-step setup with Back, Skip and Next. Step 1: Beep, Vibrate, Copy to clipboard, Auto-open links and Batch mode. Step 2: accent colour. Step 3: the camera permission rationale. Skip goes straight to the scanner. It never shows again. | P2 | yes |

### 6.2 Scanning (S02, S04, S06)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-SCAN-1 | Full-bleed rear camera with the viewfinder. A **top toolbar** holds Menu, Scan image, Flash, Flip camera, Batch (only when batch mode is on) and More (Settings, Help). | P0 | layout |
| R-SCAN-2 | Formats are QR, EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, Codabar, ITF, Data Matrix, Aztec and PDF417. Settings group them as 1D product, 1D industrial, QR, Data Matrix, Aztec and PDF417, each with its own switch. | P0 | toggles |
| R-SCAN-3 | On detection: play the beep and vibration and copy to the clipboard (each per settings), save to history (per settings), then open the Result screen. Resume scanning on return. | P0 | |
| R-SCAN-4 | Scan image: from the drawer, the toolbar, or **an image shared from another app**. Several codes open a picker. None shows "No code found". | P0 | share |
| R-SCAN-5 | Flash toggle, showing its state. | P0 | |
| R-SCAN-6 | A zoom bar with **− and + buttons** around a slider, plus pinch to zoom. | P1 | buttons |
| R-SCAN-7 | Flip between the front and rear camera. Settings → Camera picks the default camera. | P1 | setting |
| R-SCAN-8 | Permission rationale before the system prompt. If access is permanently denied, show "Open settings". Scanning an image always stays available. | P0 | |
| R-SCAN-9 | The same value seen again within 2 seconds is ignored. With **Keep duplicates** off (the default), a repeat scan of a value already in history moves that record to the top instead of adding a copy. | P0 | setting |
| R-SCAN-10 | Pause the camera in the background or on another screen, and resume on return. | P0 | |
| R-SCAN-11 | **Batch scan:** with batch mode on, the Batch button starts a session. Each new code beeps and adds to a running count chip that shows the last value, and the camera stays on. Stop opens **S06 Batch review** ("12 codes"): a list you can open, delete or share all of. Every record carries a `batch_id`. | P1 | yes |
| R-SCAN-12 | **Invert scan** setting: also decode white codes on black, using `invertImage`. | P2 | yes |
| R-SCAN-13 | Tap to focus, when the device supports it. | P2 | yes |

### 6.3 Result (S05, S17)

Parsing is unchanged from v1 (`ScanParser`, with tests for every type). v2 adds **ISBN**, which is
EAN-13 starting with 978 or 979 and is shown as Book.

| type | header label | actions (in this order) | pri |
| --- | --- | --- | --- |
| url | Website | Open, Copy, Share | P0 |
| text | Text | Web search, Copy, Share | P0 |
| wifi | Wi-Fi | **Connect**, Copy password, Share | P0 |
| contact | Contact | Add contact, Call, Email, Show map (when there is an address), Share | P1 |
| email | Email | Send email, Copy, Share | P0 |
| phone | Phone | Call, Add contact, Copy, Share | P0 |
| sms | SMS | Send SMS, Send MMS, Copy, Share | P0 |
| geo | Location | Show map, Get directions, Copy, Share | P1 |
| event | Event | Add event, Copy, Share | P1 |
| product | Product | Product search, Web search, Copy, Share | P1 |
| isbn | Book | Book search, Web search, Copy, Share | P1 |

Every type also gets **Save image** and any custom actions that are turned on for it (R-ACT-1).

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-RES-1 | **Header:** the type badge, type name and time, plus **Rename** (edits the title, saved to history) and **Favourite**. | P0 | rename |
| R-RES-2 | **Actions** form a grid of round icon buttons, each with a label underneath. The first action is the main one, filled in the type colour. | P0 | layout |
| R-RES-3 | Copy shows a "Copied" snackbar. Share opens the system share sheet. Save image writes a 1024 px PNG of the code to the gallery. | P0 | save |
| R-RES-4 | **URL safety:** links never open automatically unless Auto-open is on. Show a warning for http, a raw IP address, punycode, shorteners and lookalike domains. | P1 | |
| R-RES-5 | **Link info** (setting, off by default): fetch the page title and description and show them under the URL. | P2 | yes |
| R-RES-6 | Wi-Fi Connect works as in v1. S19 states: requesting ("Requesting connection to network…"), connected, failed. On failure, offer Copy password and Wi-Fi settings. | P0 | |
| R-RES-7 | Product lookup works as in v1 (Open Food Facts). Product and web search use the chosen search engine and country (R-SET-4). Book search opens the engine's book search. | P1 | engine |
| R-RES-8 | Details: Format, Type, Metadata (EC level or raw bytes when known) and the **barcode image** re-rendered from the value. | P0 | image |
| R-RES-9 | Open goes to the **in-app browser (S17)** when "Use in-app browser" is on: a title bar, Refresh, Copy link and "Open in browser". Otherwise it uses the system browser. | P1 | screen |
| R-RES-10 | "Make one like this" (prefills Create) and "Scan another". | P1 | |

### 6.4 Custom actions and search (S15, S16)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-ACT-1 | Settings → Custom actions lists the user's actions, with an Add button. The editor has Name, URL template with `{code}` (for example `https://example.com/lookup?q={code}`), the types it appears on (checkboxes), and Enabled. Validation: the name is required, the URL must be http(s) and contain `{code}`. | P1 | yes |
| R-ACT-2 | On a result, a custom action replaces `{code}` with the URL-encoded value and opens the link the same way Open does. | P1 | yes |
| R-ACT-3 | Custom search URL: a template with `{code}` that replaces the engine for Web search when it is set. | P2 | yes |

### 6.5 History and Favourites (S07, S08, S09)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-HIS-1 | Newest first, grouped under **day headers** (Today, Yesterday, then dates). Each row: type icon in its colour, title, time, detail line, star, and a row menu (Open, Rename, Share, Delete). | P0 | menu |
| R-HIS-2 | Each day header has a menu with "Delete this day" and a confirmation: "Delete all scans from {date}?". | P1 | yes |
| R-HIS-3 | **Filter by type:** a side sheet on phones (a panel on wide screens) listing the 11 types with counts. The source filter (All, Scanned, Created) stays as chips. | P1 | type |
| R-HIS-4 | Search across the title and the raw value. | P1 | |
| R-HIS-5 | Swipe or menu delete with an Undo snackbar. Clear history (overflow menu) asks for confirmation. | P0 | |
| R-HIS-6 | Long-press starts multi-select with a "3 selected" bar: Delete (with confirmation), Share, Favourite. | P1 | |
| R-HIS-7 | Empty states: "No history" with a Scan button, "No matches" with Clear filters. | P0 | |
| R-HIS-8 | **Favourites** is its own screen: the starred items in the user's order, **drag to reorder** (stored in `favorite_order`), and "Remove all favourites" with a confirmation. Empty: "No favourites yet". | P1 | yes |
| R-HIS-9 | **Export and import sheet:** Export CSV, Export TXT (one value per line), Save to file, Share, and **Import CSV**. Import uses ScanLight's own CSV columns, skips duplicate ids and reports "Added 24 codes". A bad file shows an error and changes nothing. | P1 | TXT, import |
| R-HIS-10 | Cap at 5,000 records. When full, drop the oldest record that is not a favourite. | P0 | |
| R-HIS-11 | ScanLight collection header: the 10 types filling in, counts (all time, last 7 days, types found) and the 7-day chart, collapsible, at the top of History. | P2 | moved |

### 6.6 Create (S10, S11, S12) and My QR (S13)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-CRE-1 | **Type list:** "Content from clipboard" at the top, shown only when the clipboard has text. It detects the type and opens the right form, filled in. Then the **QR** types: Text, Website, Wi-Fi, Contact, Email, Phone, SMS, Event, Location. Then **Other types**: EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, ITF, Codabar, Data Matrix, Aztec, PDF417. | P0 | clipboard, event, location, barcodes |
| R-CRE-2 | Text shared from another app opens the type list with that text in "Content from clipboard". | P1 | yes |
| R-CRE-3 | **Forms**, using `Form` validation, finished with ✓:<br>• Text, with a counter.<br>• Website.<br>• Wi-Fi: SSID, password, security, Hidden.<br>• Contact: name (required), organisation, address, phone, email, notes, and Add from contacts.<br>• Email: to, subject, body.<br>• Phone, with Add from contacts.<br>• SMS: number, message.<br>• **Event**: name (required), start and end date and time, all-day, location, description.<br>• **Location**: latitude and longitude (required, range-checked), query, and **Current location**.<br>• **Barcode**: one value field with format rules and a counter. EAN-8 takes 7 or 8 digits, EAN-13 12 or 13, UPC-A 11 or 12, and UPC-E 7 or 8; a missing check digit is computed. Code 39 accepts its own character set. ITF needs an even digit count. | P0 | event, location, barcodes |
| R-CRE-4 | Encoding works as in v1 (escaping, vCard 3.0). Events use VEVENT, locations use `geo:lat,lng?q=`. | P0 | |
| R-CRE-5 | **Created code (S12):** a header with type, Rename and Favourite; the code; the content; then Save to gallery (1024 px PNG) and Share. It is saved to history with source = created. | P0 | rename |
| R-CRE-6 | **ScanLight styling, QR only:**<br>• Presets: Classic, Dots, Colour, Badge, Ink, and **Brand**.<br>• More options: foreground and background colour, error correction, rounded corners, and a low-contrast warning.<br>• Barcodes (1D, Data Matrix, Aztec, PDF417) offer only foreground colour, using the same contrast rule, and always print their digits for 1D. | P0 | barcode colour |
| R-CRE-7 | **Brand kit** (unchanged, ScanLight-only):<br>• A logo from photos or from a website (fetched only on request, http(s), 5-second timeout, 2 MB cap).<br>• A colour taken from the logo, or set by swatch or hex, and darkened until it reaches 4.5:1 on white.<br>• Dots or squares; one saved kit.<br>• The first tap on Brand applies the saved kit; later taps open the editor.<br>• The logo sits on a background tile at 24% size, with high error correction. | P0 | |
| R-CRE-8 | **Share card:** a white card with the type header, code, title, summary, and the optional "Made with ScanLight" footer (setting). | P1 | |
| R-CRE-9 | **My QR:** the first visit shows the contact form with a short explanation ("Only add what you want to share"). ✓ saves it in prefs and shows the code. Later visits open straight on the code (with Brand when it is set), plus Edit and Share. It is not added to history. | P1 | yes |

### 6.7 Settings (S14)

| ID | requirement | pri | new |
| --- | --- | --- | --- |
| R-SET-1 | **Scanning:** Beep (on), Vibrate (on), Copy to clipboard (off), Auto-open links (off), Keep duplicates (off), Link info (off), Batch scan mode (off), Save to history (on). | P0 | 3 new |
| R-SET-2 | **Camera:** Camera (rear or front), Auto focus (on), Touch focus (on), Invert scan (off). | P2 | yes |
| R-SET-3 | **Formats:** six switches (R-SCAN-2), all on by default. Turning off the last one is blocked. | P2 | yes |
| R-SET-4 | **Search:** engine (Google, Bing, DuckDuckGo, Ecosia, Yahoo, Yandex, Baidu, Ask; default DuckDuckGo), product search country (a list of country domains; default device region), custom search URL (R-ACT-3). | P1 | yes |
| R-SET-5 | **Actions:** Custom actions (R-ACT-1). **Browser:** Use in-app browser (on). | P1 | |
| R-SET-6 | **Appearance:** Theme (System, Light, Dark) and **Accent colour** (6 swatches that each pass AA; the default is ScanLight green). The accent recolours the chrome only, never the type colours. | P1 | accent |
| R-SET-7 | **Sharing:** "Made with ScanLight" on share cards (on). | P2 | |
| R-SET-8 | **About:** Privacy ("Everything stays on this phone. The internet is used only for product lookups, link info when you turn it on, and website logos when you ask."), Licences (`showLicensePage`), Share app, Send feedback (mailto). | P0 | |

## 7. Data model

```dart
enum ScanSource { camera, photo, created, batch }
enum ContentType { url, text, wifi, contact, email, phone, sms, geo, event, product, isbn }

class ScanRecord {
  final String id;              // uuid v4
  final ScanSource source;
  final String format;          // BarcodeFormat name
  final ContentType type;
  final String rawValue;
  final Map<String, dynamic> parsed;
  final String title;           // renamable (R-RES-1)
  final bool favorite;
  final int? favoriteOrder;     // R-HIS-8
  final String? batchId;        // R-SCAN-11
  final DateTime createdAt, updatedAt;
}

class CustomAction {            // table custom_actions
  final String id, name, urlTemplate;   // must contain {code}
  final Set<ContentType> types;
  final bool enabled;
}
```

- **Migration v1 → v2 (`onUpgrade`):**
  - Add `favorite_order INTEGER`, `batch_id TEXT` and an index on `batch_id`.
  - Create the `custom_actions` table.
  - Existing favourites get their order from `created_at`.
- **Prefs:** the settings above, the brand kit (as in v1.2), `myQr` (vCard string), `accentColor`,
  `onboarded`.
- **Product lookup:** `isbn` re-types existing EAN-13 978/979 records on read, with no write needed.

## 8. Project structure (additions)

```
lib/features/batch/        batch session controller, review screen
lib/features/favorites/    reorderable list
lib/features/my_qr/
lib/features/browser/      in-app browser screen
lib/features/settings/custom_actions/
lib/features/onboarding/
lib/core/barcode_encoder.dart   format rules + check digits (with tests)
lib/core/share_intent.dart      SEND text/image routing
lib/core/export.dart            CSV/TXT export + CSV import (with round-trip tests)
```

## 9. UX direction

- Keep the v1.1 identity: neutral chrome, one accent, the type colours as the only colour moments, the
  green viewfinder brackets as the signature, Lucide icons, and Inter at 400 and 500.
- The scanner toolbar sits over the camera, so its icons are on a dark scrim with 48 dp targets.
- The result action grid uses round 56 dp buttons with labels. The main action is filled in the type
  colour; the others are neutral.
- Accessibility: Semantics labels on every icon button, AA contrast, text scaling up to 2×, and reduced
  motion respected.
- The Figma brief for every screen and state is in `docs/figma-design-prompt.md`.

## 10. Non-functional requirements

Same as v1 (NFR-1 to NFR-7), plus:
- **NFR-8.** Batch scanning keeps 30 fps on a mid-range phone and holds no more than one decoded frame
  in memory.
- **NFR-9.** Shared images are read once and never copied into app storage.
- **NFR-10.** Link info and logo fetches send no cookies or identifiers.

## 11. Phased plan

| phase | goal | requirements | done when |
| --- | --- | --- | --- |
| **5. Reference flow** | Scanner-first navigation | §5 drawer · R-SCAN-1,6 · R-RES-1,2,3,8 · R-HIS-1,2,3 · R-CRE-5 rename | The app opens on the camera, every drawer entry works, and a record can be renamed from the result |
| **6. Create parity** | Every create type | R-CRE-1,2,3,4,6 · barcode encoder tests · R-CRE-9 My QR | Each of the 9 QR types and 12 barcode formats encodes, saves and scans back to the same value |
| **7. Power features** | Batch, favourites, export | R-SCAN-11 · R-HIS-8,9 · R-SCAN-4 share image · R-SET-1 | A batch of 10 codes exports as CSV, imports into a fresh install, and the favourites order survives a restart |
| **8. Customisation** | Actions, search, settings | R-ACT-1,2,3 · R-SET-2,3,4,6 · R-RES-5,7,9 · R-SCAN-12,13 · R-ONB-1,2 | A custom action added in Settings appears on matching results and opens with the code filled in |

Definition of done per phase: `flutter analyze` is clean, all tests pass (goldens updated), and the
phase's "done when" line is checked on a real Android phone (with Artemis).

## 12. Acceptance checklist (v2 additions)

- [ ] **Navigation:**
  - A cold start lands on the camera.
  - The drawer reaches all 8 entries.
  - Back from any of them returns to the scanner.
- [ ] **Sharing into the app:**
  - Sharing a photo of a QR from the gallery app opens its result.
  - Sharing a URL from the browser opens Create with it filled in.
- [ ] **Batch scan:**
  - Scan 5 different codes → the count reads 5.
  - Stop → the review lists 5.
  - Delete one → History shows 4 with the same `batch_id`.
- [ ] **Duplicates:** with Keep duplicates off, scanning the same code twice leaves one record, moved
  to the top.
- [ ] **Day headers:** "Delete this day" removes only that day's records.
- [ ] **Type filter:** filtering by Wi-Fi shows only Wi-Fi records, with counts that match.
- [ ] **Favourites:** reorder 3 favourites → restart → same order.
- [ ] **Export and import:** Export CSV → Clear history → Import CSV restores every record.
- [ ] **Barcodes:**
  - EAN-13 `544900000099` gets check digit 6.
  - The created code scans back as `5449000000996`.
  - UPC-E, Code 39, ITF and PDF417 each round-trip.
- [ ] **Event and Location:**
  - An event round-trips.
  - "Current location" asks for permission only when tapped and fills in the coordinates.
- [ ] **My QR:**
  - Fill it in once → reopen → the code shows straight away.
  - The brand kit applies to it.
- [ ] **Custom actions:**
  - Add "Lookup" with `https://example.com/?q={code}` for Product.
  - It appears on a product result and opens with the code URL-encoded.
- [ ] **Search:** set the engine to DuckDuckGo → Web search on a text result opens DuckDuckGo.
- [ ] **Invert scan** reads a white-on-black QR.
- [ ] **Accent colour:** switching it recolours buttons and the selection, but not the type badges.
- [ ] **Brand kit:** fetching a logo from a website applies the logo and its colour, and the code
  still scans.

## 13. Risks

| risk | mitigation |
| --- | --- |
| Batch mode records junk from repeat frames | 2-second same-value debounce, plus Keep duplicates off by default |
| A wrong barcode check digit makes an unscannable code | Compute and validate check digits in `barcode_encoder.dart`, with tests per format |
| The iOS share extension is extra native work | Ship Android intents first. iOS shares through the system Open-in for images; text is P2 there |
| Link info leaks which links were scanned | Off by default, explained in Settings, no cookies |
| CSV import of a malformed or huge file | Validate the header, cap at 5,000 rows, transactional insert, report errors |
| Drawer navigation is less discoverable than tabs | The scanner toolbar keeps Scan image and Batch one tap away; the drawer opens with an edge swipe |

## 14. Legal and branding

Never use the reference app's name, icon, screenshots, colours, store text, code or strings. The
reference APK in `reference/` is for analysis only and never ships or goes into the repo's release
assets.
