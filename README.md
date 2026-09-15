# Instagram (personal iOS web shell)

This repository builds a personal, sideloaded iPhone application named **Instagram** (`xyz.n9007314.instagram`). It is a native SwiftUI/iOS 26 shell around Instagram's mobile website. Instagram owns authentication and server actions; the app does not use unofficial APIs or read/store credentials.

## Architecture

- `App/` owns lifecycle, session presentation, and the hard-lock state.
- `Navigation/` contains a five-page `UIPageViewController` and the SwiftUI Liquid Glass tab bar. Home, Search, Reels, Messages, and Profile each keep an independent `WKWebView` alive. All five use `WKWebsiteDataStore.default()` so cookies persist and are shared.
- `Instagram/WebView/` builds WebKit configurations, validates bridge messages, discovers the signed-in profile, blocks restricted routes, keeps popups in-app when appropriate, and opens non-Instagram HTTPS links in the system browser.
- `Instagram/Scripts/` contains separate, failure-isolated semantic filters. `Bootstrap.js` debounces a `MutationObserver`, reacts to SPA history changes, and runs every registered filter as Instagram replaces DOM nodes.
- `Restrictions/` contains native, persisted policy state and pure policy types.
- `Tests/` covers daily usage, daily rollover, clock rollback, rolling-window boundaries, and JSON persistence.

There are no push-notification, analytics, advertising, or third-party SDKs.

## Hardcoded policies

All compile-time values are in [`Restrictions/AppPolicy.swift`](Restrictions/AppPolicy.swift).

- Daily use is limited to **30 foreground minutes per local calendar day**. Usage checkpoints are written every 15 seconds and again whenever the scene becomes inactive/backgrounded. At the limit, every WebView is stopped and a native full-screen lock remains until the next local day.
- Story publishing allows one final publish attempt in a rolling seven-day window.
- Note publishing allows two final publish attempts in a rolling seven-day window.
- Future timestamps are retained if the clock moves backwards, so clock rollback does not restore quota.
- Story allowlisting, Story-viewer removal, Instagram Map removal, comment-reply-only Activity filtering, disabled Reel Follow controls, swipe navigation, and haptics have no Settings override.

The creation limit is counted at the final semantically identified Share/Post control. Because Instagram does not expose a supported publication callback to this client, the final attempt is counted even if the network request later fails. This is intentionally fail-closed.

### Set allowed Story usernames

Edit this line in `Restrictions/AppPolicy.swift`, using lowercase names without `@`:

```swift
static let allowedStoryUsernames: Set<String> = ["first_username", "second_username"]
```

The empty default means no identifiable Stories are shown.

### Change the daily limit

Edit only `dailyUsageLimit` in `Restrictions/AppPolicy.swift`. For example, 45 minutes is `45 * 60`.

## DOM filters and maintenance

Filters favor routes, roles, accessible labels, and visible semantic text instead of generated CSS class names. They run after initial load, after DOM mutations, and after `pushState`, `replaceState`, or `popstate` navigation. Native route blocking adds a second layer for Story allowlisting, Story viewers, Map, and exhausted creation routes.

Instagram can change text and structure at any time. The likely maintenance points are:

- final Story/Note composer button text in `CreationLimitBridge.js`;
- Story links/rings in `StoryFilter.js` and viewer controls in `StoryViewerFilter.js`;
- Activity row structure and reply wording in `NotificationFilter.js`;
- Explore headings/grids in `SearchFilter.js`;
- Map routes/labels, Reel Follow labels, and Sponsored markers in their dedicated scripts;
- authenticated-profile link discovery in `Bootstrap.js`.

Filters deliberately avoid deleting uncertain content. Notification rows are the exception: on the Activity route, candidates are hidden unless their text confidently describes a reply to one of your comments.

## Settings and sign out

Long-press the native Profile tab and choose **Settings**. Settings contains only a functioning appearance preference and Sign Out. Sign Out deliberately removes Instagram/Facebook website records from this app's WebKit data store; ordinary launches never clear them.

## App icon

The repository includes a neutral generated placeholder at `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` so builds do not fail. Replace that file with your own 1024×1024 PNG using the same filename. No Instagram trademark asset is downloaded by this project.

## Build and obtain the IPA

No local Xcode, CocoaPods, SwiftPM packages, Rust, or signing credential is required. The XcodeGen definition is `project.yml` and the workflow is `.github/workflows/build.yml`.

1. Push the repository to GitHub on `main`, or open **Actions → Build unsigned IPA → Run workflow**.
2. The `macos-26` runner installs XcodeGen, generates `Instagram.xcodeproj`, runs policy tests in the first available iPhone simulator, and builds Release for `iphoneos` with signing disabled.
3. Open the completed workflow run and download the **Instagram-IPA** artifact. It contains `Instagram.ipa`, whose internal layout is `Payload/Instagram.app`.
4. Sign/install that unsigned IPA with your existing sideloading setup.

Build logs are uploaded as **Instagram-build-logs**, including on failure when a log exists.

## Limitations

This app changes only the presentation and reachable controls in the authenticated Instagram website. It does not change Instagram's server-side Story viewer tracking, ad delivery, or account behavior. DOM-dependent enforcement should be tested after Instagram website updates; native daily accounting, persisted rolling-window state, HTTPS/host handling, and known-route blocking do not depend on DOM selectors.
