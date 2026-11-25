# Prompt: ScanLight design in Figma, matching the reference app, with options per screen

Paste everything below the line into Claude, in a session that has the Figma connector enabled and the
`ui-ux-pro-max` skill installed. It works in phases and stops for your choice between them.
The screen list comes from `replica/recon.md`, which was built from the reference APK.

---

You are the lead product designer for **ScanLight**, a Flutter app (Android and iOS) that scans and
creates QR codes and barcodes and keeps a private history on the phone.

Design every screen in Figma. ScanLight must have **the same screens, features and flows** as the
reference app described below, in ScanLight's own visual identity. It also keeps ScanLight's own
feature, the **Brand kit**.

Give me real options to choose from before you commit to one.
- Use the Figma connector for all Figma work.
- Use the `ui-ux-pro-max` skill for design-system reasoning.
- Never use the reference app's name, icon, colours, illustrations or wording.

## 0. Setup (do this first and report the result)

1. **Skill.** Check the `ui-ux-pro-max` skill is available. If it isn't, install it with one of:
   - `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill`, then
     `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`
   - or `npx ui-ux-pro-max-cli init --ai claude`
2. **Figma connector.** Check it can **create and edit** files (frames, components and variables), not
   only read them. If it can only read, say so and stop. Don't fake the output as images or HTML.
3. **Context.** If this repo is open, read `replica/recon.md` and `replica/features.csv` for the full
   screen and settings detail.
4. **Design system.** Generate the base design system with the skill and keep the files:
   ```
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "QR code barcode scanner utility mobile app privacy" --design-system --persist -p "ScanLight" --tokens dtcg
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "QR scanner" --stack flutter
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "mobile scanner camera overlay navigation drawer" --domain ux
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "utility app" --domain icons
   ```
   - For each screen below, also run `--design-system --persist -p "ScanLight" --page "<screen>"`.
   - Follow `design-system/scanlight/pages/<screen>.md` when it exists, and `MASTER.md` otherwise.
   - Treat the skill's output as input to your judgement, not as the answer. Where it conflicts with the
     product facts or constraints below, the facts and constraints win. Say where you overrode it.

## 1. Product facts (design for exactly this; don't add features)

### Navigation
- The app opens on the **Scanner**.
- A **navigation drawer** holds: Scan, Scan image, Favourites, History, My QR, Create, Settings and
  Share app.
- The drawer is modal on phones. From 840 dp wide it is a permanent drawer or a navigation rail.

### Content types (10)
- Website, Text, Wi-Fi, Contact, Email, Phone, SMS, Location, Event and Product (with ISBN for books).
- Each type has a colour and an icon.
- Type colours carry meaning, so use them only where they identify a type: badges, history icons, QR
  codes, and the result's main action.

### Scanning
- **Scanner toolbar** over the camera: menu (opens the drawer), Scan image, Flash, Flip camera, Batch
  scan (shown only when it is turned on in Settings), and More.
- **Zoom bar:** a − button, a slider and a + button.
- **Batch scan:** scan many codes in a row with a running count, then review them as one list.
- **Scan image:** from the gallery, or by sharing an image to ScanLight from another app.

### Result
- **Header:** type icon, type name and time, with **Rename** and **Favourite**.
- **Content:** the content itself, plus optional page info for links.
- **Actions:** a grid of round icon buttons, each with a label underneath, chosen per type:
  - Website: Open, Copy, Share.
  - Text: Web search, Copy, Share.
  - Wi-Fi: Connect, Copy password, Share.
  - Contact: Add contact, Call, Email, Show map.
  - Phone: Call, Add contact, Copy.
  - SMS: Send SMS, Send MMS, Copy.
  - Location: Show map, Get directions, Copy.
  - Event: Add event, Copy.
  - Product: Product search, Web search, Copy.
  - Book: Book search, Copy.
  - Every type also gets **Save image**, plus any **custom actions** the user has added.
- **Details:** Format, Type and Metadata rows, and the barcode image.
- **Safety:** links show a warning banner ("Check this link before opening") for http, raw IP
  addresses, shorteners and lookalike domains.

### History and Favourites
- **History:**
  - Grouped by day (Today, Yesterday, then dates). Each day header has a menu with "Delete this day".
  - A side **filter by type**, and search.
  - Rows show the type icon, title, date, detail, a star and a row menu.
  - Swipe or menu delete with **Undo**.
  - Long-press for multi-select with a "3 selected" bar (delete, share).
  - Overflow menu: Export and import, Clear history.
- **Favourites** is its own screen, with **drag to reorder**.
- **Export and import sheet:** Export CSV, Export TXT, Save to file, Share, Import CSV.

### Create
- **Type list:**
  - "Content from clipboard" at the top.
  - QR types: Text, Website, Wi-Fi, Contact, Email, Phone, SMS, Event and Location.
  - "Other types": EAN-8, EAN-13, UPC-A, UPC-E, Code 39, Code 93, Code 128, ITF, Codabar, Data
    Matrix, Aztec and PDF417.
  - Sharing text to ScanLight opens this list with the text filled in.
- **Forms:**
  - Text: a character counter.
  - Wi-Fi: SSID, password, security (WPA, WEP or none), and a Hidden option.
  - Contact: name, organisation, address, phone, email, notes, and "Add from contacts".
  - Event: name, start and end date and time, all-day, location, description.
  - Location: latitude, longitude, query, and "Current location".
  - Barcode: one field with format rules ("Enter 7, 8, 12 or 13 digits") and a counter.
  - Every form has inline "Required" or "Invalid" errors and a ✓ to finish.
- **Created code:** header (type, Rename, Favourite), the code, the content, Save and Share. Then the
  ScanLight additions below.

### My QR
- Your own contact card as a QR code.
- The first visit shows the contact form with a short explanation. Every later visit shows the code
  straight away, with Edit.

### Settings
- **Scanning:** Beep, Vibrate, Copy to clipboard, Auto-open links, Keep duplicates, Link info, Batch scan
  mode, Save to history.
- **Camera:** Camera choice, Auto focus, Touch focus, Invert scan (white on black).
- **Formats:** 1D product codes, 1D industrial codes, QR, Data Matrix, Aztec and PDF417.
- **Search:** Search engine (Google, Bing, DuckDuckGo, Ecosia and others), Product search country,
  Custom search URL.
- **Actions:** Custom actions, as a list with Add.
- **Browser:** Use in-app browser.
- **Appearance:** Theme (System, Light or Dark) and Accent colour (swatches).
- **About:** Privacy, Licences, Share app.
- **Sub-screens:**
  - Custom action editor: name; URL with `{code}`; which types it appears on; enabled.
  - Custom search URL.

### First run
- A short privacy note: "Everything stays on this phone". There is no consent wall.
- Then a 3-step setup with Back, Skip and Next: key scan settings, then accent colour, then camera
  permission.

### In-app browser
- Title, Refresh, Copy link, "Open in browser", and the page.

### ScanLight's own features (keep; the reference app doesn't have these)
- **Style presets** on created codes: Classic, Dots, Colour, Badge (type icon in the centre) and Ink.
- **Brand kit:**
  - A logo from photos, or from a website (the app fetches the site's icon).
  - A colour taken from the logo automatically, or chosen by swatch or hex.
  - Dots or squares.
  - One saved kit, applied with one tap.
- **More options:** foreground and background colour, error correction, rounded corners, and a
  low-contrast warning.
- **Share card:** a white card with the type header, the code, the title and summary, and an optional
  "Made with ScanLight" footer.
- **Collection:** the 10 types filling in as you find them, plus counts (all time, last 7 days, types
  found) and a 7-day chart. These sit at the top of History, and can be collapsed.
- **New-type pill** ("New in your collection: Wi-Fi · 5 of 10").

### Privacy
- Everything is stored on the phone.
- The network is used only for product lookup, link info (off by default), and the website logo when
  the user asks.
- No ads, no account and no tracking.

### Current ScanLight look (a reference, not a requirement)
- Inter at weights 400 and 500.
- Lucide icons at a light stroke.
- Warm off-white and graphite neutrals.
- Signal green `#00745C` on light and `#4FDDB6` on dark.
- An ink-black scan panel with green viewfinder corner brackets, the signature detail.
- Cards with a 16 radius and hairline borders.

## 2. Complete screen and state inventory

Design every item in **light and dark** at **phone 360×780**. Also design the screens marked ◆ at
**tablet 800×1280** and **landscape 1280×800**.

Use plausible real data, for example "Café Guest", "bit.ly/menu", "+1 555 0134" and "5449000000996".
Never use lorem ipsum or `123,456`.

1. **First run:**
   - Privacy note.
   - Setup step 1: scan settings.
   - Setup step 2: accent colour.
   - Setup step 3: camera permission.
2. **Scanner (home):**
   - Camera permission rationale, permission denied ("Open settings").
   - Live viewfinder (idle sweep), and detected (brackets snap to the code).
   - Flash on and off, zoom bar, a hint chip.
   - The toolbar with the batch button shown and hidden.
   - The "Several codes found" chooser sheet, and the camera error.
3. **Batch scan:**
   - Running, with the count chip and the last code shown.
   - Review list ("12 codes"): open, delete, share all, save all to history.
4. **Navigation drawer** ◆: closed, open and current item; permanent drawer or rail on wide screens.
5. **Scan image:** decoding, "No code found", and the share-sheet entry.
6. **Result** ◆ (a full page from history, and the same layout after a live scan):
   - Website with the safety warning and link info.
   - Text.
   - Wi-Fi in four Connect states: idle, connecting, connected, and failed with the "Wi-Fi settings"
     fallback.
   - Contact, Email, Phone, SMS, Location, Event.
   - Product: loading, found with an image, and not found.
   - Book (ISBN).
   - Also show:
     - The action grid with a custom action.
     - The rename dialog.
     - Favourite on and off.
     - Details expanded, with the barcode image.
     - "Scan another" and "Make one like this".
7. **In-app browser:** loading, loaded and error.
8. **History** ◆:
   - Day headers with their menu, and the "Delete this day" confirmation.
   - The type filter (side sheet on phone, panel on wide screens), and search.
   - Rows with a star.
   - Swipe to delete with Undo, and multi-select mode.
   - The collection and stats header, expanded and collapsed.
   - Empty, "No matches", the loading skeleton and the error state.
   - The overflow menu and the Clear history confirmation.
9. **Favourites** ◆: the list, drag-to-reorder (handle and lifted row), "No favourites yet", and
   "Remove all" with its confirmation.
10. **Export and import sheet:** the options, Import CSV result ("Added 24 codes"), and the import
    error.
11. **Create: type list** ◆: Content from clipboard (with and without text in the clipboard), QR
    types, and Other types.
12. **Create: forms**, one per type: Text, Website, Wi-Fi, Contact, Email, Phone, SMS, Event (with the
    date and time pickers), Location (with "Current location"), and a Barcode example (EAN-13 and
    Code 128). For each, show empty, filled and validation errors.
13. **Created code** ◆:
    - The share card with each preset.
    - Brand applied.
    - Rename and favourite.
    - Save and Share.
    - More options (swatches, error correction, rounded) and the low-contrast warning.
    - A non-QR barcode result (EAN-13), which has no presets, only colour.
14. **Brand editor sheet:**
    - Logo states: no logo, logo from photos, the "From website" dialog, loading, and the "No logo
      found" error.
    - Colour from the logo, the "Darkened so it scans" note, and Dots or Squares.
15. **My QR:** the first-visit form, the saved code (with Brand applied), and edit.
16. **Settings** ◆:
    - Every group in section 1.
    - The Search engine picker, Product search country and Custom search URL.
    - The Custom actions list, with empty and filled states.
    - The Custom action editor, including its error.
    - The accent colour picker.
17. **Privacy** ◆ and **Licences**.
18. **Feedback moments:**
    - The new-type pill and the "Saved to gallery" pill.
    - The Copied state.
    - Snackbars with Undo.
    - The rename dialog and the confirm dialogs.

## 3. Options: how to give me choices

Work in phases and **stop after each phase for my choice**. Use your question tool if you have one;
otherwise ask in plain text and wait.

**Phase A: three visual directions.**
- Build three clearly different directions from the skill's recommendations and your own judgement:
  - One that refines the current "ink and read-light" look.
  - Two that differ in more than colour: the type pairing, density, shape language, and how the type
    colours and the signature detail show up.
- For each direction, make a small style tile: colours, type scale, buttons, inputs, cards, type badges,
  the action-grid button and one QR card.
- Show the same four key screens in each direction, in light and dark:
  - Scanner (detected).
  - Drawer open.
  - Result (Wi-Fi).
  - History.
- Name each direction in two or three concrete words. Not "clean", "modern", "sleek", "minimal" or
  "premium".
- Write one paragraph on who each direction suits and its trade-offs.
- Recommend one.

**Phase B: layout options per screen,** in the chosen direction.
- For **each screen in section 2**, design **2 or 3 layout variants** that differ in hierarchy or
  composition, not just colour. For example:
  - The scanner toolbar at the top or as a bottom bar.
  - Result actions as a round-icon grid, or as a primary button plus an icon row.
  - The History type filter as a side sheet, or as chips.
  - The Create list as grouped rows, or as a tile grid.
- Label them `Option 1/2/3` with a one-line rationale under each, and mark your pick.
- **Keep every feature and the flow order from section 1 in every option.** Variants change layout,
  never what the screen can do.

**Phase C: the final system.**
- Build the chosen options into the complete set: every state in section 2, in light and dark, at every
  breakpoint marked ◆.
- Use shared components and variables, so the file is ready to hand to development.

## 4. Figma file structure

- **File:** one file named `ScanLight — Design`.
- **Pages:**
  - `Cover`
  - `Design system`
  - `A · Directions`
  - `B · Screen options`
  - `C · Final — Phone`
  - `C · Final — Tablet & landscape`
  - `Flows`
- **Variables:**
  - Colour collections with Light and Dark modes: neutrals, text roles, the accent (with the Settings
    accent swatches as alternatives), and semantic colours.
  - The 10 type colours, each with strong, on-strong, container and on-container.
  - Spacing on a 4 pt scale, radius (8, 12, 16, 20), and the type scale.
- **Components with variants:**
  - Button: primary, tonal, outline and text × enabled, pressed, disabled and loading.
  - Action-grid button: round icon and label × enabled and disabled.
  - Type badge: neutral and solid × 10 types.
  - QR card, style preset tile, and brand tile.
  - History row: default, selected, swipe and dragging.
  - Day header.
  - Drawer item.
  - Scanner toolbar button, and the zoom bar.
  - Chips, switch row, picker row, search field, and form field with error.
  - Date and time picker.
  - Banners (warning and error), sheet, dialog, pill and snackbar.
  - Stepper footer (Back, Skip, Next).
  - Navigation drawer and navigation rail.
- **Rules:**
  - Auto layout everywhere.
  - Frames named `Screen / State / Theme / Size`.
- **Prototype links for the main flows:**
  - Scan → result → favourite.
  - Batch scan → review → open one.
  - Share image → result.
  - Create → form → created → brand → share.
  - My QR, first visit and then later visits.
  - History → filter → result → delete → undo.
  - Favourites → reorder.
  - Settings → custom action → result shows it.
  - First run → scanner.
- **Icons:** Lucide only, at one stroke weight. Use the skill's icon recommendation only if you justify
  changing set.

## 5. Constraints (non-negotiable)

- **Codes must scan.**
  - QR modules are always dark on a light background, with a quiet zone.
  - A centre logo or icon takes at most about 5% of the area.
  - 1D barcodes keep their human-readable digits and full quiet zones.
- **Accessibility:**
  - WCAG AA contrast in both themes (4.5:1 for text, 3:1 for icons and controls).
  - Touch targets of at least 48 dp, including the scanner toolbar.
  - Layouts that survive 2× text. Show Scanner, Result, History and Settings at 2× in Phase C.
- **No slop:**
  - No hue-to-hue gradients on surfaces, glows, glassmorphism, colour blobs, gradient text, emoji
    icons or sparkle badges.
  - No uppercase tracked labels, no exclamation marks, and no greeting headline.
  - One accent per screen, plus the type colour where it carries meaning.
- **No monetisation UI:** no ads, ad slots, "Remove ads", rate prompts, "Our apps" or shopping buttons.
- **Features and flows:** keep every feature and flow in section 1. Don't invent features, claims,
  ratings or stats.
- **Scanner chrome:** the viewfinder and toolbar sit over a live camera feed, so they must read on any
  image.

## 6. Report back after each phase

- The Figma link, and node links to each direction or option frame.
- What the skill recommended, and where you followed or overrode it.
- An accessibility check: the contrast pairs you verified, and any that failed.
- For Phase C, a list of every frame against the inventory in section 2, with anything missing stated
  plainly.
