# NATIVE_APP_DEV.md

Starting point for native Apple apps (SwiftUI on iOS, iPadOS, macOS). It collects what worked and what bit us while building feather-ai-chat, a one-binary chat client for an OpenAI-compatible proxy, deployment floor 26 (Liquid Glass), September 2026.

[DESIGN.md](../context/DESIGN.md) still owns colour and tone, and HIG still wins on chrome. This file owns process, project setup, architecture, UX patterns, testing, and the gotchas that cost time. Where the project departed from DESIGN.md, the [Visual design](#visual-design-on-the-designmd-palette) section says so.

## Day-one checklist

1. **RFC first.** Write `docs/rfc/0001-….md` before code: summary, motivation, explicit non-goals, platforms and layout, data model, interface, verification (unit + UI + manual), risks, follow-ups. Later changes get a new RFC with an `Amends: RFC 0001 sections 4, 11` line instead of silent drift. `AGENTS.md` names the next free RFC number.
2. **XcodeGen `project.yml` as the source of truth**, `project.pbxproj` committed. Set `productName`, signing, and entitlements in `project.yml` from the start (see [Project setup](#project-setup)).
3. **`justfile`** with `build`, `test`, `screenshots` wrapping `xcodebuild`.
4. **Two test targets.** Unit tests on macOS hosted in the app (fast, no permissions), UI tests in a separate `Screenshots` scheme so `just test` never needs a simulator or Accessibility permission.
5. **A Debug-only UI test fixture** (`-uiTestFixture`) with in-memory data, isolated settings and Keychain, and an in-process fake backend. Build it in week one, not after the redesign. It's what makes screenshots repeatable and lets an agent actually see the app.
6. **CloudKit-shaped schema** even if sync is a later RFC: every attribute has a default or is optional, relationships are optional, no unique constraints.
7. **App icon, asset catalog, and CI running `just test`** before calling anything "native". A generic icon was the biggest tell that the app wasn't finished.
8. **No package dependencies** unless an RFC adds one. URLSession, SwiftData, Keychain, and small hand parsers (SSE, frontmatter, a markdown subset) covered everything.

## Project setup

**Layout.** Folders by responsibility, not by type:

```text
App/
  Proxy/     network client, request building, stream parsing, error envelope
  Store/     SwiftData models, settings, Keychain, controller, pure helpers
  UI/        views, theme tokens, metrics
  Fixture/   Debug-only UI test launch state and fake backend
AppTests/    XCTest, macOS
AppUITests/  XCUITest, iPhone + iPad + Mac
docs/rfc/
justfile
project.yml
```

**XcodeGen gotchas.**

- Without `productName: Feather` on the target, XcodeGen names the product after the target (`FeatherAiChat.app`), even if `PRODUCT_NAME` is set. Schemes then reference the wrong bundle.
- Signing changed in the Xcode UI only lands in `project.pbxproj`. The next regeneration silently drops it, so port `DEVELOPMENT_TEAM`, `CODE_SIGN_IDENTITY[sdk=…]`, and entitlements into `project.yml` immediately.
- `INFOPLIST_KEY_*` build settings are ignored when `GENERATE_INFOPLIST_FILE: NO` and there's a hand-written `Info.plist`. Put display name and category in the plist itself.
- Regeneration rewrites scheme XML to a newer format and can shift file IDs. It's cosmetic, so restore those files from git when the diff should stay minimal.
- XcodeGen isn't in the Brewfile. The agent built it from source into the git-ignored `build/tools/` to avoid a global install. Adding `brew "xcodegen"` would save that step.

**Signing.** App target gets the team and `Apple Development` for both SDKs, test targets stay ad hoc:

```yaml
DEVELOPMENT_TEAM: <TEAM_ID>
CODE_SIGN_STYLE: Automatic
'CODE_SIGN_IDENTITY[sdk=iphoneos*]': Apple Development
'CODE_SIGN_IDENTITY[sdk=macosx*]': Apple Development
CODE_SIGN_ENTITLEMENTS: App/App-iOS.entitlements
'CODE_SIGN_ENTITLEMENTS[sdk=macosx*]': App/App-macOS.entitlements
```

**justfile.** Screenshot export uses `xcresulttool` plus `jq` to rename the UUID-named attachments. `jq` ships with macOS at `/usr/bin/jq`, so it's not a new dependency.

```just
iphone := "iPhone 18 Pro"
ipad := "iPad Pro 11-inch (M5)"

test:
    xcodebuild -scheme App -destination 'platform=macOS' -derivedDataPath build test

screenshots: (_shots "iphone" "platform=iOS Simulator,name=" + iphone) (_shots "ipad" "platform=iOS Simulator,name=" + ipad) (_shots "mac" "platform=macOS")

_shots name destination:
    rm -rf build/screenshots/{{name}} build/screenshots/{{name}}.xcresult
    xcodebuild -scheme Screenshots -destination '{{destination}}' -derivedDataPath build -resultBundlePath build/screenshots/{{name}}.xcresult test
    xcrun xcresulttool export attachments --path build/screenshots/{{name}}.xcresult --output-path build/screenshots/{{name}}
    cd build/screenshots/{{name}} && /usr/bin/jq -r '.[].attachments[] | "\(.exportedFileName) \(.suggestedHumanReadableName | sub("_[0-9]+_[0-9A-F-]+\\.png$"; ".png"))"' manifest.json | while read -r from to; do mv "$from" "$to"; done
```

**Info.plist.**

- `UIUserInterfaceStyle: Dark` plus `preferredColorScheme(.dark)` for dark-only apps.
- A user-typed backend URL (often `http://` on a LAN) needs `NSAllowsArbitraryLoads` and `NSLocalNetworkUsageDescription`, because no exception domain is known at build time. On iPhone, `localhost` is the phone, so document that the host must be reachable from the device.
- `CFBundleName` is the short name in the Mac menu bar, `CFBundleDisplayName` is what Finder, Dock, and Home Screen show.
- Show `Name 0.1.0 (1)` at the end of Settings, read from `CFBundleShortVersionString` and `CFBundleVersion` so it follows `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Make it selectable for bug reports.

## Architecture

**Pure logic in small enums with static functions.** `ChatSections.list`, `ContextMeter.compact`, `ModelGroups`, `ChatSearch.matches/snippet`, `ChatExport.markdown`, `ChatTitle.rename`, `MarkdownBlocks.parse`. Each one is a unit test away from verified, and views stay thin. Have them take plain structs or tuples instead of `@Model` objects, because inverse relationships aren't reliable on models created outside a container.

**One `@Observable` controller, created in `App.init`**, passed through `.environment` to both the `WindowGroup` and the Mac `Settings` scene so they share state. `App.init` is main-actor isolated, so `container.mainContext` is safe there.

**Injection seams from the start.** A client that takes a `URLSession`, a settings type with a swappable `static var store: UserDefaults`, and a Keychain wrapper with a swappable `static var service`. The UI fixture and unit tests swap all three without touching production code paths.

**SwiftData fetches made from a controller method aren't observed.** A slash menu reading `controller.cachedSkills()` never refreshed after a reset. Fix: a private `revision` counter on the `@Observable` controller that the method reads and every mutation bumps.

**Drafts are uninserted models.** "New chat" creates a `Chat` without inserting it, and the first send inserts it. Abandoned drafts leave nothing behind. Key the detail view with `.id(chat.uuid)` so identity survives the promotion from draft to selected.

**Write streamed content once, at the end.** Append deltas to transient state and insert the assistant message when the stream finishes. That's one record per reply, which matters for CloudKit and avoids per-token saves.

**Schema evolution.** New attributes always get a default (`var pinned: Bool = false`), so existing stores migrate lightly and stay CloudKit-compatible. Never rename or remove an attribute once sync ships.

**Secrets.** Keychain only, `kSecAttrAccessibleAfterFirstUnlock`. Header names live in settings, header values in the Keychain. Never log tokens or header values. A user-supplied `Authorization` header is dropped so the bearer field is the only source.

**Networking.**

- Failed refreshes keep the previous good cache. Never replace good data with an empty result from an unreadable response.
- Cap recursive walks (100 files) and report "path too broad" instead of hammering a host.
- URLSession reuses one HTTP/2 connection and bursts far faster than a curl loop, so a host that's fine under curl can rate-limit the app. Reproduce with the app's real fetch code in a small CLI harness, not curl. Tangled's nginx returned 429 with no `Retry-After` after ~44 requests in 3 seconds. The fix was spacing requests 100 ms apart and retrying 429 after 1, 3, then 8 seconds, honouring `Retry-After` when present.
- Retry narrowly. One retry on HTTP 400 without `stream_options`, only before any delta arrived. No retries on 401, 404, 429, or 502 from our own proxy.

## UX patterns that worked

### Navigation

- **One `NavigationSplitView(preferredCompactColumn:)` everywhere** instead of branching between `NavigationStack` and a split view by size class. Setting the column to `.detail` pushes the thread on iPhone, and there's no container swap to lose state.
- **iPhone launches into a fresh draft** with the list one back-swipe away, like current AI chat apps. iPad and Mac show sidebar plus draft.
- **`⌘N` as a scene command** via a focused value. Replacing `.newItem` removes New Window on Mac, which is an acceptable trade for a chat app, but note it in the RFC.

  ```swift
  extension FocusedValues {
      @Entry var newChat: (() -> Void)?
  }

  struct ChatCommands: Commands {
      @FocusedValue(\.newChat) private var newChat
      var body: some Commands {
          CommandGroup(replacing: .newItem) {
              Button("New Chat") { newChat?() }
                  .keyboardShortcut("n", modifiers: .command)
                  .disabled(newChat == nil)
          }
      }
  }
  ```

- **Mac settings are a `Settings` scene** (`⌘,`), opened with `@Environment(\.openSettings)` from a sidebar footer row. An inspector panel is the wrong pattern per HIG. iPhone and iPad keep a sheet, opened from a bottom glass toolbar that also holds New chat (the iOS 26 Mail/Notes pattern).

### Empty states are onboarding

The empty screen tells the user the next action, in three states: not configured ("Connect a proxy" plus Open Settings), failed (the error plus Try Again and Settings), and ready (a short greeting plus up to six one-tap suggestions). A bare "No chat selected" placeholder wastes the most-seen screen.

### Lists

- Group by date: Today, Yesterday, Previous 7 days, Previous 30 days, then month (year added outside the current year). Pinned items get their own leading section and don't repeat in their date group.
- A secondary preview line only in compact width. Regular-width sidebars stay single-line.
- A small spinner on the row that's actively working.
- `.searchable` in memory, case- and diacritic-insensitive, with a snippet around the first match. Fine for hundreds of items; thousands need a stored search field or index.
- Rename via context menu and leading swipe, opening an alert with a prefilled field. Renaming and pinning don't touch `updatedAt`, so items stay in their date group.
- Share with `ShareLink` and a Markdown string. Messages, Mail, Notes, Copy, and Save to Files all work with no custom exporter. Keep settings, URLs, and tokens out of exports.

### Content

- **SwiftUI `Text` ignores block-level markdown.** Paragraphs, headings, lists, code, and tables collapse into one blob. A line-based block parser plus per-block views fixed it, with inline markdown still going through `AttributedString`. Treat an unclosed code fence as code so a streaming reply stays readable.
- Code blocks: a card with a language label, a copy control, and horizontal scroll. Tables scroll horizontally too.
- Copy on the latest reply always, on older replies on hover (Mac) only. On iOS, don't reserve invisible 44pt action rows under every message.
- A pulsing indicator before the first token. `ellipsis` doesn't support `.variableColor`, so use `.symbolEffect(.pulse)` gated by Reduce Motion.
- Only fade in the live streaming block. If the stored row fades in too, the reply flickers when the stream finishes and the view swaps identity.

### Scrolling a transcript

Open at the bottom, keep a reader at the bottom as content grows, never yank someone who scrolled up, and offer a glass jump-to-latest button. Sending always scrolls down.

```swift
ScrollView { … }
    .defaultScrollAnchor(.bottom, for: .initialOffset)
    .scrollDismissesKeyboard(.interactively)
    .onScrollGeometryChange(for: Bool.self) { geometry in
        // containerSize excludes insets, visibleRect doesn't
        let visibleBottom = geometry.visibleRect.maxY - geometry.contentInsets.bottom
        return visibleBottom >= geometry.contentSize.height - bottomSlack
    } action: { _, near in
        atBottom = near
    }
```

The first attempt at this formula ignored `contentInsets.bottom`, and the jump button showed while already at the bottom.

### Input bar

- `safeAreaBar(edge: .bottom)` with `glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))`, so content scrolls under the glass with the system edge effect. A painted strip behind the bar defeats the point of glass.
- Related floating pieces (bar plus popover menu) share one `GlassEffectContainer` so they read as one material.
- Send and Stop share one frame and swap symbols. The bar never grows or jumps.
- Popover menus are keyboard-navigable: Up and Down move a highlight, Return or Tab picks. Otherwise Return sends the half-typed trigger text.
- `⌘↩` sends and `⌘.` stops from anywhere in the window.
- Long ids get a short monospaced label (after the provider prefix). Long pickers group by prefix in sections, switching to submenus past about a dozen items.
- **Status marks only for non-happy states.** A spinner while checking, a red mark that retries on failure, and nothing when connected. A permanent green check is noise.
- A small ring plus `2.3k / 128k` for usage, turning orange at 80%, hidden entirely when either number is missing. Don't estimate from characters.

### Settings

- On iOS, filled `TextField`s in a `Form` lose their labels. Use `LabeledContent(title) { TextField(…).multilineTextAlignment(.trailing) }` for label-and-value rows.
- `.textInputAutocapitalization(.never)` and `.autocorrectionDisabled()` on every URL, path, ref, and header-name field, or `http://` becomes `Http://`.
- Tint buttons with the theme instead of leaking system blue. Toggles need their own tint: a near-white accent hides the white knob, so the Grey theme keeps system green.
- Order sections by how often they're needed: connection, content sources, behaviour, appearance, then the version row.
- A version line works best as a last row with a clear background. Footers render differently across platforms and can't be scroll targets.

### Motion and haptics

- Motion explains a change: chip insert fades and scales 0.96 to 1 in ~160 ms, menus fade, theme changes crossfade ~200 ms. No springs or overshoot. Reduce Motion turns these into an instant change or a short fade.
- Haptics through `sensoryFeedback` only, on discrete events: send (light), stop (soft), done (success), error, selection changes, destructive confirm (warning). Never on keystrokes, deltas, scrolling, or opening a menu. No in-app haptics toggle; the system switch is the control.
- Hit targets: a `Metrics.hitTarget` of 44 on iOS and 28 on macOS instead of forcing 44 on Mac.

## Visual design on the DESIGN.md palette

What held up, and where practice diverged from [DESIGN.md](DESIGN.md). The divergences are candidates for a DESIGN.md update.

- **Yellow sidebar selection didn't survive contact.** Off-white text on `#FFFF11` was unreadable, and the yellow slab was the loudest thing on screen. The fix was a quiet fill (`greeny` `#3E4939`, or `#3A3A3C` in Grey) with normal text on iPad, and the system selection on Mac. Yellow stays on controls: send, chips, caret, checkmarks.
- **Sidebar vs tabs.** A chat app with a persistent, searchable list justified `NavigationSplitView`. DESIGN.md's default of tabs for two or three top-level screens still stands.
- **A two-option theme isn't a toggle.** Neither option means "off", so iOS uses two rows with a checkmark and a colour swatch, and Mac uses a native segmented picker.
- **Add a `quiet` token** for selected rows, hairlines, disabled fills, quote rules, and inline code backgrounds. It stopped every "subtle" surface from inventing its own opacity.
- **A Grey theme must not use the system accent**, or the user's purple or blue from System Settings leaks in. Use an inversion fill (`#F2F2F7` on `#1C1C1E`).
- **Glass is system chrome only.** Call `glassEffect`, `GlassEffectContainer`, `.glassProminent`, and never fake it with blur plus shadow. Transcript, canvas, and settings rows stay painted. Yellow goes on the control fill, never as a wash behind glass, where it blows out.
- **The iPadOS 26 sidebar floats as glass.** Painting it opaque with the row colour kills the effect. Hide the list background there and let the canvas show through.
- **Modern geometry:** bubble radius 20, input bar 24, cards 12, rows 10, all continuous. Reading column ~720pt centred on wide windows, user bubbles capped ~520pt. Assistant text has no bubble.
- **The blue keyboard-focus ring** on a selected iPad row when a hardware keyboard is attached is system behaviour. Leave it; removing focus effects hurts keyboard users.

## Testing and verification

**Unit tests** cover the pure helpers plus controller behaviour on an in-memory container. Always pass `cloudKitDatabase: .none`: the default `.automatic` picks up CloudKit from the entitlements, even for in-memory stores.

```swift
let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
```

Unit tests run inside the app host, so the app's own launch path must not open the user's store or iCloud. Detect it with `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil` and fall back to in-memory.

**UI test fixture** (`#if DEBUG`, `-uiTestFixture`):

- In-memory `ModelContainer`, a throwaway `UserDefaults` suite (wiped on launch), a separate Keychain service name.
- A `URLProtocol` subclass registered on an ephemeral session serves the backend in-process, including a chunked SSE stream with small delays, so "send and watch it stream" is a real round trip without network.
- Seed data is designed to exercise features: a pinned item, a word that appears only in a message body (for search), markdown with headings, a list, code, a quote, and a table.
- Extra launch args pick state and theme (`-uiTestState setup`, `-uiTestTheme grey`).
- Check the Release binary contains no fixture symbols.
- Stable `accessibilityIdentifier`s on the controls tests drive (`composer.field`, `composer.send`, `settings.open`).

**XCUITest cross-platform gotchas.**

- On macOS, `app.screenshot()` captures the whole display, including other apps. Use `app.windows.firstMatch.screenshot()`.
- Add `extension XCUIElement { func click() { tap() } }` under `#if os(iOS)` so one test body runs everywhere.
- Context menus: `rightClick()` on Mac, `press(forDuration: 1)` on iOS. Items are `menuItems` on Mac, `buttons` on iOS.
- Mac static text often carries its content in `value`, not `label`. Match `label CONTAINS x OR value CONTAINS x`, and use `matching` rather than `containing` (which matches descendants).
- Accessibility identifiers on a SwiftUI alert's `TextField` don't reach XCUI. Match by placeholder or prefilled value.
- On Mac, the alert's text field may not have focus: click it and `⌘A` before typing. A "Save" button query can hit a Touch Bar element, so press Return for the default action.
- Wait for the end state before snapping (the Send button's label returning to `Send`), or screenshots catch mid-stream UI.
- iPhone launches into the thread, so a `showList` helper taps back only when the list marker isn't hittable. Wait on a button that exists on every platform, not a section header (the Mac sidebar doesn't expose "Today" as static text).
- The first Mac run needs Accessibility permission for the test runner. A leftover window from a failed run can make the next test flaky.

**Seeing the app as an agent.**

- `xcrun simctl io booted screenshot` works without Screen Recording permission. Mac `screencapture` needs it for the terminal, so use the Mac UI test pass instead.
- `xcodebuild` and simulator services fail inside the agent sandbox. Run them unsandboxed.
- Capture a baseline before redesigning. Before/after screenshots made the markdown and selection bugs obvious.
- Avoid ad-hoc demo seeding in app code. One temporary seed saved a fake `demo.local` URL to real defaults, and later launches hung on DNS. The fixture's isolated suite prevents that; otherwise uninstall the app from simulators afterwards.

**Still needs a human:** Mac visuals, a live backend, VoiceOver order through code blocks and tables, the largest Dynamic Type sizes (the iPhone input row overflowed), and Reduce Transparency with glass.

## iCloud sync and signing

Designed in feather-ai-chat RFC 0004 and being built at the time of writing. Treat this as the plan plus known constraints, not a verified recipe.

- **Entitlements differ per platform.** iOS uses `aps-environment`, macOS uses `com.apple.developer.aps-environment`. Both need `com.apple.developer.icloud-container-identifiers`, `icloud-services: [CloudKit]`, and `ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)$(CFBundleIdentifier)`. Add `UIBackgroundModes: remote-notification` for silent pushes.
- **Two SwiftData configurations in one container.** Synced data (`Chat`, `Message`) goes to `.private("iCloud.<bundle id>")`, caches go to `.none`, each in its own store file. Moving off SwiftData's shared `default.store` needs a one-time copy guarded by a defaults flag.
- **CloudKit schema rules:** defaults or optionals everywhere, optional relationships (`var messages: [Message]? = []` with a sorted non-optional accessor), no unique constraints, `@Attribute(.externalStorage)` for blobs near the 1 MB record limit. Deploy the schema from Development to Production in the CloudKit console before release; after that, changes are additive only.
- **Non-secret settings** sync through `NSUbiquitousKeyValueStore` as one encoded blob. Per-device settings (local paths, the sync switches themselves) stay out.
- **Secrets stay per device by default.** Opt-in iCloud Keychain sync writes with `kSecAttrSynchronizable: true` and queries with `kSecAttrSynchronizableAny`, so flipping the switch doesn't strand items. This changes secrets handling, so flag it for explicit review.
- **macOS keychain split.** Synchronizable items need the data protection keychain (`kSecUseDataProtectionKeychain`), which returns `errSecMissingEntitlement` for builds without a provisioning profile. Fall back to the legacy file keychain and read from both.
- **The sync switch applies on next launch**, because the container is built at launch. Say so in the UI.
- **Status UI** comes from `NSPersistentCloudKitContainer.eventChangedNotification` plus `.CKAccountChanged` and `CKContainer.accountStatus()`.
- **Delete copy changes** to "removed from all your devices" while sync is on.
- **The Mac app sandbox was off**, which let the app read `~/.agents/skills` directly. A Mac App Store build needs the sandbox, which means an open panel plus security-scoped bookmarks for anything in the home folder.
- **Portal steps can't happen in the repo:** create the container, run once in Development to create the schema, then deploy to Production.

## Do earlier next time

- App icon and asset catalog on day one.
- CI running `just test` on push.
- The UI fixture and `just screenshots` before the first redesign, not after.
- Streaming performance: every token re-parsed the whole reply's markdown. Throttle UI updates (~30 Hz) and cache finished blocks. Avoid re-sorting messages and re-fetching caches in `body`.
- An accessibility pass alongside the redesign, not after.
- System hooks worth an RFC: App Intents for Shortcuts and Siri, a share extension, a Mac quick-ask window.
