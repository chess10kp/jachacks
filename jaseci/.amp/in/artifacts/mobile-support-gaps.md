# Mobile Support Gaps in the Jaseci Codebase

A comprehensive audit of what's missing or incomplete in mobile support across jac-client, jac-scale admin UI, and the docs site.

---

## 1. Native Mobile Target: Android-Only, No iOS

**Location:** `jac-client/jac_client/plugin/src/targets/mobile_target.jac` and its impl

The `MobileTarget` only supports Android via Tauri. iOS is explicitly rejected:

```python
# mobile_target.impl.jac L9-19
def _normalize_mobile_platform(platform):
    if value == "android":
        return value
    raise ValueError("Unsupported mobile platform. Supported: android")
```

**Missing:**
- No `tauri ios init` / `tauri ios dev` / `tauri ios build` support (Tauri v2 supports iOS)
- No IPA artifact detection (only APK/AAB in `_find_android_artifact`)
- No Xcode project scaffolding or code-signing configuration
- No iOS simulator launch support in the `dev` flow

---

## 2. Admin Dashboard (jac-scale) — No Mobile Navigation

**Location:** `jac-scale/jac_scale/admin/ui/`

### 2a. Category Tabs Overflow

`CategoryTabs.cl.jac` renders 8 category buttons (`Authentication`, `Data`, `Operations`, `Monitoring`, `Settings`, `Integrations`, `Deployment`, `Audit`) in a horizontal flex container with **no overflow handling**:

```jsx
<div className="flex px-4 gap-1 border-t border-slate-800 bg-slate-900/50">
```

On small screens, these tabs will overflow off-screen with no `overflow-x-auto`, no scroll indicators, and no hamburger/drawer fallback.

### 2b. SubTabs Overflow

Same issue in `SubTabs.cl.jac` — the Monitoring category alone has 6 sub-tabs rendered horizontally with no scroll handling.

### 2c. No Hamburger Menu or Sidebar Drawer

The entire admin navigation uses stacked horizontal tab bars. There is no:
- Hamburger menu toggle for mobile
- Slide-out sidebar/drawer
- Bottom navigation bar (common mobile admin pattern)
- Collapsible navigation

### 2d. Header Not Responsive

`Header.cl.jac` uses `flex items-center justify-between` but has no responsive breakpoints. Username text and logout button may crowd or overlap on narrow screens.

---

## 3. Data Tables Not Mobile-Friendly

**Location:** `jac-scale/jac_scale/admin/ui/components/tables/DataTable.cl.jac`

The `DataTable` component renders a standard `<table>` with no mobile adaptations:

- No `overflow-x-auto` wrapper (only added ad-hoc in `LLMMetricsPage`)
- No stacked/card layout for small screens
- No column hiding/priority system
- No responsive column collapsing

Pages like `UsersPage` and `SSOPage` use `DataTable` without any overflow wrapper — tables will break on mobile.

---

## 4. Metrics Dashboard Hard-Coded Grid Layouts

**Location:** `jac-scale/jac_scale/admin/ui/pages/admin/monitoring/MetricsPage.cl.jac`

The main metrics page uses fixed grid layouts with no responsive breakpoints:

```jsx
<div className="grid grid-cols-4 gap-6">      // L349 — 4 columns, no md: or sm: variants
<div className="grid grid-cols-3 gap-6">      // L392 — 3 columns, no responsive fallback
<div className="grid grid-cols-3 gap-6">      // L520 — GC section, 3 columns fixed
```

On mobile, these will render as tiny unusable columns. Compare with `LLMMetricsPage` which correctly uses `grid-cols-1 md:grid-cols-2 lg:grid-cols-4`.

### Stats Grid on UsersPage

```jsx
<div className="grid grid-cols-3 gap-3 mb-4">  // L130 — no responsive prefix
```

Three stats cards will be squeezed on mobile.

---

## 5. Modal Not Mobile-Optimized

**Location:** `jac-scale/jac_scale/admin/ui/components/common/Modal.cl.jac`

The modal uses `max-w-sm` and `p-4` padding, which is reasonable, but:
- No full-screen modal option for mobile (common pattern for forms on phones)
- No swipe-to-dismiss
- No `max-h-screen overflow-y-auto` for long content that exceeds viewport
- `window.confirm()` used for destructive actions (e.g., delete user L74 in UsersPage) — unreliable on some mobile browsers/WebViews

---

## 6. PWA Runtime — Functional but Incomplete

**Location:** `jac-client/jac_client/plugin/impl/pwa_runtime.impl.jac`

### What works:
- Platform detection (iOS, Android, desktop) ✓
- iOS install guide modal ✓
- `beforeinstallprompt` capture for Android/Chrome ✓
- Re-prompt logic with exponential backoff ✓
- One responsive breakpoint at 520px ✓

### What's missing:
- **No service worker registration or offline support** — the PWA runtime handles install prompts but there's no service worker, cache strategy, or offline fallback page
- **No push notification support** — `notifications` are listed in admin integrations but no client-side push subscription
- **No app update detection** — no mechanism to detect and prompt for new service worker versions
- **No splash screen configuration** — `apple-mobile-web-app-*` meta tags not generated
- **No `theme-color` dynamic updates** — defined in `HeaderBuilder.standard_tags` but not dynamically applied per-route

---

## 7. Viewport Configuration — Minimal

**Location:** `jac-client/jac_client/plugin/client.jac` L28

Default viewport is `width=device-width,initial-scale=1`, which is correct but minimal:
- Missing `viewport-fit=cover` for notched devices (iPhone X+)
- Missing `maximum-scale=1` option to prevent unwanted zoom on form inputs
- No `<meta name="apple-mobile-web-app-capable">` in defaults
- No `<meta name="apple-mobile-web-app-status-bar-style">` in defaults

---

## 8. Touch Interactions

### No touch-specific handling in admin UI:
- No swipe gestures for navigation between categories/tabs
- No pull-to-refresh on data pages (Users, Metrics)
- No long-press context menus as alternatives to hover-dependent actions
- Buttons use `:hover` styles (via Tailwind `hover:`) which don't translate well to touch — no `:active` or tap feedback styles

### Docs site — partial:
- `landing.js` has touch/swipe handlers for the carousel (L503-530) ✓
- No touch handling elsewhere

---

## 9. No Mobile-Specific Testing

- Playwright E2E tests exist (`jac-client/jac_client/tests/test_e2e.jac`) but use desktop viewport only
- No mobile viewport configurations (`iPhone`, `Pixel`, etc.)
- No touch event simulation tests
- No visual regression tests for responsive layouts

---

## 10. Documentation Site — Good but Gaps

**Location:** `docs/docs/landing.css`

### What works:
- Comprehensive media queries at 480px, 768px, 900px breakpoints ✓
- Mobile-specific code editor sizing ✓
- Hamburger menu in `header.html` ✓

### What's missing:
- Several sections in the CSS have responsive rules **commented out** (affiliations section L1995-2180)
- The `extra.css` has minimal responsive rules (only L1228-1235)
- Run-code widget in docs may not work well on mobile (requires keyboard input)

---

## Summary Table

| Area | Status | Priority |
|------|--------|----------|
| iOS native build target | ❌ Not implemented | High |
| Admin nav (tabs overflow) | ❌ No scroll/collapse | High |
| DataTable mobile layout | ❌ No responsive handling | High |
| MetricsPage grid breakpoints | ❌ Fixed columns | High |
| Service worker / offline | ❌ Not implemented | Medium |
| Modal mobile fullscreen | ❌ Not implemented | Medium |
| Touch gestures (swipe nav) | ❌ Not implemented | Medium |
| Mobile E2E tests | ❌ Not implemented | Medium |
| Viewport notch support | ❌ Missing viewport-fit | Low |
| Apple PWA meta tags | ❌ Not generated | Low |
| Push notifications (client) | ❌ Not implemented | Low |
| Docs responsive gaps | ⚠️ Partial (commented CSS) | Low |
