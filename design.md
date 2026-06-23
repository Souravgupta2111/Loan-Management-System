# LMS Design System & Screen Specification

> **Design Philosophy:** Premium fintech aesthetic inspired by modern investment apps.
> Clean, airy layouts with generous white space, large bold typography,
> soft muted gradients, pill-shaped interactive elements, and Apple's
> iOS 26 Liquid Glass material for native depth and translucency.

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Color System](#2-color-system)
3. [Typography](#3-typography)
4. [Spacing & Layout Grid](#4-spacing--layout-grid)
5. [Component Library](#5-component-library)
6. [Liquid Glass Integration](#6-liquid-glass-integration)
7. [Animation & Motion](#7-animation--motion)
8. [LMS Borrower App — Screens](#8-lms-borrower-app--screens)
9. [LMS Staff App — Screens](#9-lms-staff-app--screens)
10. [Accessibility & HIG Compliance](#10-accessibility--hig-compliance)

---

## 1. Design Principles

| Principle | Description |
|-----------|-------------|
| **Clarity First** | Every screen answers one question. Dashboard = "How much do I owe?" Application = "What do I need to fill?" |
| **Breathing Room** | Generous padding (20-24pt), no cramped layouts. Content floats in space. |
| **Warm Minimalism** | Soft, organic colors (mints, beiges, lavenders) instead of cold corporate blues. |
| **Bold Numbers** | Financial figures are the hero — displayed in 34-48pt SF Pro Display Bold. |
| **Progressive Disclosure** | Show summary first, detail on tap. Sheets and expansions reveal more. |
| **Native Feel** | Liquid Glass, SF Symbols, haptic feedback, standard iOS gestures. |

---

## 2. Color System

### 2.1 Core Palette

```
┌─────────────────────────────────────────────────────────────┐
│  LIGHT MODE                                                 │
├─────────────────┬───────────────┬───────────────────────────┤
│  Token          │  Hex          │  Usage                    │
├─────────────────┼───────────────┼───────────────────────────┤
│  background     │  #FAFAF8      │  App background           │
│  surface        │  #FFFFFF      │  Card surfaces            │
│  surfaceMuted   │  #F5F5F0      │  Secondary cards, inputs  │
│  textPrimary    │  #1A1A1A      │  Headlines, amounts       │
│  textSecondary  │  #6B6B6B      │  Labels, captions         │
│  textTertiary   │  #9E9E9E      │  Placeholders, hints      │
│  border         │  #E8E8E4      │  Card borders, dividers   │
│  borderSubtle   │  #F0F0EC      │  Very subtle separators   │
├─────────────────┼───────────────┼───────────────────────────┤
│  ACCENT COLORS                                              │
├─────────────────┼───────────────┼───────────────────────────┤
│  accentGreen    │  #2D8B4E      │  Positive/approved states │
│  accentGreenBg  │  #E8F5EC      │  Green badge backgrounds  │
│  accentMint     │  #C8E6D0      │  Soft green tints         │
│  accentBeige    │  #F5E6C8      │  Warm highlights, charts  │
│  accentBeigeDk  │  #D4A574      │  Beige buttons, icons     │
│  accentLavender │  #E8D5F0      │  Insights, AI features    │
│  accentRed      │  #D94040      │  Overdue, rejected, error │
│  accentRedBg    │  #FDE8E8      │  Red badge backgrounds    │
│  accentAmber    │  #E8A830      │  Pending, warnings        │
│  accentAmberBg  │  #FFF3D6      │  Amber badge backgrounds  │
│  accentDark     │  #2C2C2E      │  Dark pill buttons        │
│  accentDarkText │  #FFFFFF      │  Text on dark pills       │
├─────────────────┼───────────────┼───────────────────────────┤
│  GRADIENT PRESETS                                           │
├─────────────────┼───────────────┼───────────────────────────┤
│  gradientMint   │  #F0FAF4 → #FAFAF8  │  Dashboard header   │
│  gradientBeige  │  #FDF6EC → #FAFAF8  │  Loan detail header │
│  gradientLaven  │  #F5ECF9 → #FAFAF8  │  Insights sections  │
│  gradientCard   │  #FFFFFF → #F8F8F5  │  Elevated cards     │
└─────────────────┴───────────────┴───────────────────────────┘
```

### 2.2 Dark Mode Palette

```
┌─────────────────┬───────────────┬───────────────────────────┐
│  Token          │  Hex          │  Usage                    │
├─────────────────┼───────────────┼───────────────────────────┤
│  background     │  #0E0E0E      │  App background           │
│  surface        │  #1C1C1E      │  Card surfaces            │
│  surfaceMuted   │  #2C2C2E      │  Secondary cards, inputs  │
│  textPrimary    │  #F5F5F5      │  Headlines, amounts       │
│  textSecondary  │  #A0A0A0      │  Labels, captions         │
│  textTertiary   │  #6B6B6B      │  Placeholders, hints      │
│  border         │  #3A3A3C      │  Card borders, dividers   │
│  borderSubtle   │  #2C2C2E      │  Very subtle separators   │
│  accentGreen    │  #34D058      │  Positive (brighter)      │
│  accentGreenBg  │  #1A3D2A      │  Green badge backgrounds  │
│  accentBeige    │  #D4A574      │  Warm highlights          │
│  accentBeigeDk  │  #B8935A      │  Beige buttons            │
│  accentLavender │  #C4A8D4      │  Insights                 │
│  accentRed      │  #FF6B6B      │  Overdue, errors          │
│  accentRedBg    │  #3D1A1A      │  Red badge backgrounds    │
└─────────────────┴───────────────┴───────────────────────────┘
```

### 2.3 Semantic Status Colors

| Status | Light Fg | Light Bg | Meaning |
|--------|----------|----------|---------|
| **Approved / Active / Paid** | `#2D8B4E` | `#E8F5EC` | Positive outcome |
| **Pending / Under Review** | `#E8A830` | `#FFF3D6` | Awaiting action |
| **Rejected / Overdue / Failed** | `#D94040` | `#FDE8E8` | Negative / attention |
| **Draft / Inactive** | `#6B6B6B` | `#F0F0EC` | Neutral, dormant |
| **Disbursed / Processing** | `#3B82F6` | `#EBF2FF` | In progress |
| **Closed / Completed** | `#1A1A1A` | `#F5F5F0` | Done, archived |

---

## 3. Typography

**Font Family:** SF Pro (system default — ensures HIG compliance)

```
┌──────────────────┬─────────────┬────────┬────────────────────────────┐
│  Style Name      │  Font       │  Size  │  Usage                     │
├──────────────────┼─────────────┼────────┼────────────────────────────┤
│  heroAmount      │  .bold      │  48pt  │  Dashboard total amount    │
│  largeAmount     │  .bold      │  34pt  │  Loan amount, EMI amount   │
│  sectionTitle    │  .bold      │  28pt  │  Screen titles             │
│  cardTitle       │  .semibold  │  22pt  │  Card headings             │
│  bodyLarge       │  .medium    │  17pt  │  Primary body text         │
│  bodyRegular     │  .regular   │  15pt  │  Standard body text        │
│  label           │  .medium    │  13pt  │  Form labels, captions     │
│  caption         │  .regular   │  12pt  │  Timestamps, footnotes     │
│  badge           │  .semibold  │  11pt  │  Status badges, tags       │
│  superscript     │  .medium    │  16pt  │  Decimal places on amounts │
└──────────────────┴─────────────┴────────┴────────────────────────────┘
```

### Amount Display Pattern
Financial amounts use a **split display** — the integer part is in `heroAmount` or `largeAmount`, and the decimal/paisa portion is rendered as a smaller **superscript** aligned to the top of the integer:

```
₹34,729⁶²
 ↑ 48pt    ↑ 16pt superscript (textSecondary color)
```

Implementation:
```swift
HStack(alignment: .firstTextBaseline, spacing: 0) {
    Text("₹34,729")
        .font(.system(size: 48, weight: .bold, design: .rounded))
    Text(".62")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
        .baselineOffset(20)
}
```

---

## 4. Spacing & Layout Grid

| Token | Value | Usage |
|-------|-------|-------|
| `spacingXS` | 4pt | Icon-to-text gap inside badges |
| `spacingSM` | 8pt | Between badge elements, tight groups |
| `spacingMD` | 12pt | Between items inside a card |
| `spacingLG` | 16pt | Card inner padding |
| `spacingXL` | 20pt | Section spacing, screen horizontal padding |
| `spacing2XL` | 24pt | Between major sections |
| `spacing3XL` | 32pt | Top-of-screen breathing room |
| `cornerSM` | 8pt | Small buttons, input fields |
| `cornerMD` | 12pt | Standard cards |
| `cornerLG` | 16pt | Large cards, sheets |
| `cornerXL` | 20pt | Hero cards |
| `cornerPill` | 999pt | Pill buttons, badges |

### Card Elevation
Cards use a very subtle shadow + border approach:
```swift
.background(Color.surface)
.clipShape(RoundedRectangle(cornerRadius: 16))
.shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.border, lineWidth: 0.5)
)
```

---

## 5. Component Library

### 5.1 Status Badge (Pill)

Small, pill-shaped badges for loan status, application status, etc.

```
┌──────────────────┐
│  ● Approved      │   ← Green dot + text, rounded pill
└──────────────────┘
```

- **Shape:** Capsule (fully rounded)
- **Padding:** 6pt vertical, 12pt horizontal
- **Font:** `.badge` (11pt semibold)
- **Foreground:** Semantic status foreground color
- **Background:** Semantic status background color
- **Dot:** 6pt circle, filled with foreground color, before text

### 5.2 Dark Pill Button (Primary CTA)

Inspired by the screenshot's dark "OPTIMIZE" button.

```
┌────────────────────────────┐
│       APPLY NOW →          │   ← Dark background, white text
└────────────────────────────┘
```

- **Shape:** Capsule
- **Background:** `accentDark` (#2C2C2E)
- **Foreground:** White
- **Font:** 15pt semibold, ALL CAPS with tracking +1
- **Padding:** 14pt vertical, 28pt horizontal
- **Haptic:** `.medium` impact on tap
- **Pressed state:** Scale 0.97, opacity 0.9

### 5.3 Beige Pill Button (Secondary CTA)

Inspired by the screenshot's warm "AI INSIGHTS" button.

```
┌────────────────────────────┐
│       VIEW DETAILS         │   ← Beige background, dark text
└────────────────────────────┘
```

- **Shape:** Capsule
- **Background:** `accentBeigeDk` (#D4A574)
- **Foreground:** White
- **Font:** 15pt semibold
- **Padding:** 14pt vertical, 28pt horizontal

### 5.4 Outline Pill Button (Tertiary)

```
┌────────────────────────────┐
│       Cancel               │   ← Border only, no fill
└────────────────────────────┘
```

- **Shape:** Capsule
- **Background:** Clear
- **Border:** 1pt `border` color
- **Foreground:** `textPrimary`
- **Font:** 15pt medium

### 5.5 Stat Card

Small cards showing a single financial metric with label.

```
┌──────────────────┐
│  Total Disbursed  │
│  ₹12,45,000      │
│  ↑ 12.3% ▲       │
└──────────────────┘
```

- **Background:** `surface`
- **Corner radius:** 16pt
- **Inner padding:** 16pt
- **Label:** `caption` style, `textSecondary`
- **Value:** `largeAmount` or `cardTitle` style, `textPrimary`
- **Change indicator:** Green or red pill badge below value

### 5.6 List Row Card

Standard row for loans, applications, payments in lists.

```
┌─────────────────────────────────────────────┐
│  🏠  Home Loan           ● Active     →    │
│      LMS-LN-000421                          │
│      ₹15,00,000     EMI: ₹14,250/mo        │
└─────────────────────────────────────────────┘
```

- **Background:** `surface`
- **Corner radius:** 16pt
- **Left:** SF Symbol icon in a 40x40 circle (tinted `surfaceMuted` bg)
- **Middle:** Title (17pt semibold), subtitle (13pt regular secondary), amount row
- **Right:** Status badge + chevron
- **Separator:** None (cards are separated by 12pt gap)

### 5.7 Form Input Field

```
┌─────────────────────────────────────────────┐
│  Full Name                                  │
│  ┌─────────────────────────────────────────┐│
│  │  Sourav Gupta                           ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

- **Label:** 13pt medium, `textSecondary`, positioned above field
- **Field background:** `surfaceMuted` (#F5F5F0)
- **Field corner radius:** 12pt
- **Field padding:** 14pt horizontal, 12pt vertical
- **Field text:** 17pt regular, `textPrimary`
- **Placeholder:** 17pt regular, `textTertiary`
- **Focus state:** 1.5pt border in `accentGreen`
- **Error state:** 1.5pt border in `accentRed`, error text below in 12pt `accentRed`

### 5.8 Circular Icon Button

Small circular buttons like in the top-right of the screenshot.

- **Size:** 36x36pt
- **Background:** `surfaceMuted`
- **Icon:** SF Symbol, 16pt, `textSecondary`
- **Shape:** Circle
- **Tap area:** 44x44pt minimum (HIG)

### 5.9 Bottom Action Bar

Sticky bottom bar for primary actions on detail screens.

```
┌─────────────────────────────────────────────┐
│  ₹14,250           [  PAY NOW  ]            │
│  Due Aug 15              ↑ dark pill         │
└─────────────────────────────────────────────┘
```

- **Material:** Liquid Glass `.bar` style
- **Inner padding:** 16pt horizontal, 12pt vertical
- **Left:** Amount + due date
- **Right:** Dark pill CTA
- **Positioned:** Bottom, with safe area inset respect

### 5.10 Section Header

```
My Loans                            See All →
```

- **Title:** 22pt bold, `textPrimary`
- **Action:** 15pt medium, `accentBeigeDk`
- **Spacing below:** 12pt

---

## 6. Liquid Glass Integration

> iOS 26 introduces Liquid Glass — a translucent, depth-aware material
> that adapts to the content behind it, creating a premium native feel.

### 6.1 Where to Apply Liquid Glass

| Element | Liquid Glass Style | Notes |
|---------|--------------------|-------|
| **Navigation Bar** | `.glassEffect(.regular)` on `NavigationStack` | Automatic in iOS 26 with `.navigationBarTitleDisplayMode(.inline)` |
| **Tab Bar** | `.glassEffect(.regular)` on `TabView` | Automatic in iOS 26 — both apps use tab navigation |
| **Bottom Action Bars** | `.glassEffect(.bar)` | Sticky CTAs at bottom of detail screens |
| **Floating Action Button** | `.glassEffect(.regular)` | "New Application" FAB on staff dashboard |
| **Sheet Grab Bar** | Default `.sheet` with `.presentationBackground(.ultraThinMaterial)` | Half-sheets for filters, quick actions |
| **Alert/Confirmation Dialogs** | System default | Already Liquid Glass in iOS 26 |
| **Segmented Controls** | `.glassEffect(.regular)` | Period pickers (1M, 3M, 6M, 1Y on charts) |
| **Search Bars** | `.searchable` modifier | Automatic glass in iOS 26 |

### 6.2 Where NOT to Apply Liquid Glass

- **Card surfaces** — Keep these solid white/surface. Glass cards would reduce readability of financial data.
- **Form fields** — Solid backgrounds for clear input visibility.
- **Status badges** — Solid semantic colors for instant recognition.
- **Primary content areas** — Scrollable content should be opaque for legibility.

### 6.3 Implementation Pattern

```swift
// Tab Bar gets Liquid Glass automatically in iOS 26
TabView {
    Tab("Home", systemImage: "house.fill") {
        DashboardView()
    }
    Tab("Loans", systemImage: "indianrupeesign.circle.fill") {
        LoansListView()
    }
    // ...
}
.tabViewStyle(.automatic) // Liquid Glass applied by OS

// Bottom action bar with glass
VStack {
    ScrollView { /* content */ }
    
    HStack {
        VStack(alignment: .leading) {
            Text("₹14,250").font(.title2.bold())
            Text("Due Aug 15").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button("PAY NOW") { }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentDark)
            .clipShape(Capsule())
    }
    .padding()
    .glassEffect(.bar)
}

// Navigation with large title that collapses into glass bar
NavigationStack {
    ScrollView { /* content */ }
    .navigationTitle("Dashboard")
    .navigationBarTitleDisplayMode(.large)
    // iOS 26 automatically applies Liquid Glass when title collapses
}
```

### 6.4 Liquid Glass Color Tinting

Liquid Glass can be tinted to match section themes:

```swift
// Mint-tinted glass for loan sections
.glassEffect(.regular.tint(Color.accentMint.opacity(0.3)))

// Lavender-tinted glass for insights
.glassEffect(.regular.tint(Color.accentLavender.opacity(0.3)))
```

---

## 7. Animation & Motion

### 7.1 Transitions

| Action | Animation | Duration | Curve |
|--------|-----------|----------|-------|
| Card appear (on scroll) | Fade in + slide up 8pt | 0.35s | `.spring(duration: 0.35)` |
| Tab switch | Cross-dissolve | 0.25s | `.easeInOut` |
| Sheet present | iOS default spring | System | System |
| Status change | Scale pulse 1.0→1.05→1.0 | 0.3s | `.spring(bounce: 0.3)` |
| Amount counter | Number roll animation | 0.6s | `.easeOut` |
| Pull to refresh | Custom — amount "drops" in | 0.4s | `.spring` |
| Button press | Scale 1.0→0.97 | 0.1s | `.easeOut` |
| Card selection | Border highlight + gentle scale 1.02 | 0.2s | `.spring` |

### 7.2 Haptic Feedback

| Event | Haptic Type |
|-------|-------------|
| Button tap (primary) | `.impact(.medium)` |
| Button tap (secondary) | `.impact(.light)` |
| Status change (approved) | `.notification(.success)` |
| Status change (rejected) | `.notification(.error)` |
| Pull to refresh trigger | `.impact(.rigid)` |
| Tab switch | `.selection` |
| Form validation error | `.notification(.warning)` |

### 7.3 Micro-interactions

- **Amount display:** When dashboard loads, the total outstanding amount "counts up" from 0 to actual value over 0.6s
- **Percentage badges:** Green/red arrows gently pulse once on appear
- **Progress rings:** Animate from 0 to current value with spring physics
- **Card hover (iPad):** Subtle elevation increase on pointer hover

---

## 8. LMS Borrower App — Screens

### 8.1 Tab Structure

```
┌─────────────────────────────────────────────┐
│                                             │
│              [Active Screen]                │
│                                             │
├─────────────────────────────────────────────┤
│  🏠 Home   💰 Loans   📄 Apply   👤 Profile │  ← Liquid Glass Tab Bar
└─────────────────────────────────────────────┘
```

---

### 8.2 Screen: Login / Authentication

**Purpose:** Email-based authentication (as specified).

**Layout:**

```
┌─────────────────────────────────────────────┐
│                                             │
│              [App Logo]                     │
│           Loan Management                   │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Email Address                          ││
│  │  ┌─────────────────────────────────────┐││
│  │  │  you@example.com                    │││
│  │  └─────────────────────────────────────┘││
│  │                                         ││
│  │  Password                               ││
│  │  ┌─────────────────────────────────────┐││
│  │  │  ••••••••                     👁    │││
│  │  └─────────────────────────────────────┘││
│  │                                         ││
│  │  ┌─────────────────────────────────────┐││
│  │  │          SIGN IN                    │││
│  │  └─────────────────────────────────────┘││
│  │                                         ││
│  │  Forgot Password?                       ││
│  │                                         ││
│  │  ─────── or ───────                     ││
│  │                                         ││
│  │  Don't have an account? Sign Up         ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Background: Soft gradient (mint → white)   │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Full-screen gradient background (`gradientMint`)
- Logo is a simple geometric mark (no heavy illustration)
- Card containing form fields uses `surface` with `cornerXL` (20pt)
- "SIGN IN" button is the dark pill CTA, full width
- "Forgot Password" is a text button in `accentBeigeDk`
- Keyboard-aware — card scrolls up when keyboard appears
- Sign Up screen is identical layout but with: Full Name, Email, Password, Confirm Password fields
- After sign up, a profile completion flow begins (see 8.9)

---

### 8.3 Screen: Home / Dashboard

**Purpose:** At-a-glance financial overview for the borrower.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ← Liquid Glass Nav Bar →                   │
│  Good Morning, Sourav  [🔔] [👤]            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  ░░░ gradient: mintGreen → white ░░░░░ ││
│  │                                         ││
│  │  Total Outstanding                      ││
│  │  ₹8,34,729⁶²                           ││
│  │        ↑ heroAmount (48pt bold)         ││
│  │  +₹14,250 due in 12 days               ││
│  │        ↑ caption, green pill badge      ││
│  │                                         ││
│  │  ┌──────────┐ ┌──────────┐              ││
│  │  │ 2 Active │ │ 1 Pending│              ││
│  │  │ Loans    │ │ App      │              ││
│  │  └──────────┘ └──────────┘              ││
│  │   ↑ Small stat pills (dark bg)         ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Upcoming EMI                      See All →│
│  ┌─────────────────────────────────────────┐│
│  │  🏠 Home Loan        Due Aug 15        ││
│  │     LMS-LN-000421                      ││
│  │     ₹14,250          ● On Track        ││
│  │                                         ││
│  │  [────────────████░░░░] 65% paid        ││
│  │                                         ││
│  │     ┌──────────────────┐                ││
│  │     │    PAY NOW  →    │                ││
│  │     └──────────────────┘                ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Quick Actions                              │
│  ┌─────────┐┌─────────┐┌─────────┐         │
│  │ 📄      ││ 💬      ││ 📊      │         │
│  │ Apply   ││ Message ││ EMI     │         │
│  │ Now     ││ Staff   ││ Schedule│         │
│  └─────────┘└─────────┘└─────────┘         │
│   ↑ 3-column grid of icon+label cards      │
│                                             │
│  Recent Activity                   See All →│
│  ┌─────────────────────────────────────────┐│
│  │  ↓ ₹14,250  Payment received            ││
│  │    Jul 15, 2026 • Home Loan              ││
│  ├─────────────────────────────────────────┤│
│  │  ✓ Application approved                  ││
│  │    Jul 10, 2026 • Vehicle Loan            ││
│  └─────────────────────────────────────────┘│
│                                             │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- **Hero card** at top uses `gradientMint` background with the borrower's total outstanding amount in `heroAmount` style
- Small **stat pills** (dark capsule badges) showing loan counts
- **Upcoming EMI card** is the most prominent card — includes a progress bar showing repayment % and a dark pill "PAY NOW" CTA
- **Quick Actions** are 3 rounded square cards in a grid, each with an SF Symbol and label
- **Recent Activity** is a grouped list with timeline-style left dots
- Notification bell shows a red dot if unread notifications exist
- The entire screen scrolls, nav bar collapses to Liquid Glass inline style

---

### 8.4 Screen: My Loans (List)

**Purpose:** View all active, closed, and pending loans.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  My Loans                                   │
│  ┌──────┐ ┌────────┐ ┌────────┐             │
│  │Active│ │ Closed │ │  All   │             │
│  └──────┘ └────────┘ └────────┘             │
│   ↑ Segmented control (Liquid Glass)        │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  🏠  Home Loan           ● Active   →  ││
│  │      LMS-LN-000421                      ││
│  │      ₹15,00,000     EMI: ₹14,250/mo    ││
│  │      [████████████░░░░░░] 65%           ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  🚗  Vehicle Loan        ● Pending  →  ││
│  │      LMS-LN-000422                      ││
│  │      ₹5,00,000      EMI: ₹8,900/mo     ││
│  │      [██░░░░░░░░░░░░░░░░] 8%            ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  🏢  Business Loan       ● Closed   →  ││
│  │      LMS-LN-000398                      ││
│  │      ₹3,00,000      Fully Paid ✓       ││
│  │      [████████████████████] 100%         ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Top segmented control with Liquid Glass effect to filter by status
- Each loan card is a `ListRowCard` with a progress bar showing repayment %
- Progress bar color: `accentGreen` for active, `textTertiary` for closed
- Cards are separated by 12pt spacing (no divider lines)
- Tapping a card navigates to Loan Detail (8.5)
- SF Symbol icons differ by `loan_type`: 🏠 home, 🚗 vehicle, 🏢 business, 🎓 education, 👤 personal, 🌾 agriculture

---

### 8.5 Screen: Loan Detail

**Purpose:** Deep dive into a specific loan — schedule, payments, documents.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ← Back         Home Loan           •••    │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  ░░░ gradient: beigeGradient ░░░░░░░░░ ││
│  │                                         ││
│  │  Loan Amount                            ││
│  │  ₹15,00,000⁰⁰                          ││
│  │                                         ││
│  │  ┌────────┐ ┌────────┐ ┌────────┐      ││
│  │  │₹9,75K  │ │₹5,25K  │ │ 8.5%  │      ││
│  │  │Paid    │ │Remain  │ │Rate   │      ││
│  │  └────────┘ └────────┘ └────────┘      ││
│  │                                         ││
│  │  Rate Breakdown (floating loans only):  ││
│  │  ┌─────────────────────────────────────┐││
│  │  │ Base (RBI): 6.50%  Spread: 2.00%   │││
│  │  │ Effective:  8.50%  Type: Floating   │││
│  │  └─────────────────────────────────────┘││
│  │   ↑ 3-column stat cards                ││
│  │                                         ││
│  │  LMS-LN-000421  ● Active               ││
│  │  Disbursed: Jan 15, 2025                ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌──────┐ ┌────────┐ ┌────────┐ ┌────────┐ │
│  │ EMI  │ │Payments│ │  Docs  │ │ Info   │ │
│  └──────┘ └────────┘ └────────┘ └────────┘ │
│   ↑ Horizontal scrolling tab pills         │
│                                             │
│  [Content changes based on selected tab]    │
│                                             │
│  ── EMI Schedule Tab ──                     │
│  ┌─────────────────────────────────────────┐│
│  │  Aug 2026              ● Upcoming       ││
│  │  Principal: ₹10,200                     ││
│  │  Interest:  ₹4,050                      ││
│  │  Total:     ₹14,250                     ││
│  ├─────────────────────────────────────────┤│
│  │  Jul 2026              ● Paid ✓         ││
│  │  Principal: ₹10,100                     ││
│  │  Interest:  ₹4,150                      ││
│  │  Total:     ₹14,250                     ││
│  └─────────────────────────────────────────┘│
│                                             │
├─────────────────────────────────────────────┤
│  ₹14,250              [  PAY EMI  →  ]     │
│  Due Aug 15         ← Liquid Glass Bar →   │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- **Hero area** with `gradientBeige` and the loan amount in `largeAmount`
- **3 stat cards** in a row: Paid, Remaining, Interest Rate
- **Horizontal scrollable pills** for sub-tabs (EMI, Payments, Documents, Info)
- Active pill: dark background. Inactive: surfaceMuted background
- **EMI Schedule** shows a chronological list with status badges
- **Payments** sub-tab shows payment history with mode icons (UPI, bank, cheque)
- **Documents** sub-tab shows uploaded files with download/preview actions
- **Info** sub-tab shows product details, branch, assigned officer
- **Bottom Liquid Glass bar** with amount due and "PAY EMI" dark pill button
- The `•••` menu at top-right opens a sheet with: Download Statement, Prepay, Contact Support

---

### 8.6 Screen: Apply for Loan

**Purpose:** Multi-step loan application form.

**Layout — Step Indicator:**

```
┌─────────────────────────────────────────────┐
│  ← Back         Apply for Loan              │
│                                             │
│  ●━━━━━━●━━━━━━○━━━━━━○                     │
│  Product  Details  Docs   Review            │
│                                             │
│  Step 1 content...                          │
└─────────────────────────────────────────────┘
```

**Step 1 — Select Product:**
```
┌─────────────────────────────────────────────┐
│  Choose Loan Type                           │
│                                             │
│  ┌───────────────────┐ ┌───────────────────┐│
│  │  🏠               │ │  🚗               ││
│  │  Home Loan        │ │  Vehicle Loan     ││
│  │  8.5% - 12.5%     │ │  9.2% - 14.0%     ││
│  │  Fixed/Floating    │ │  Fixed/Reducing    ││
│  │  ₹5L - ₹2Cr      │ │  ₹1L - ₹50L      ││
│  └───────────────────┘ └───────────────────┘│
│  ┌───────────────────┐ ┌───────────────────┐│
│  │  👤               │ │  🏢               ││
│  │  Personal Loan    │ │  Business Loan    ││
│  │  From 11.5%       │ │  From 10.0%       ││
│  │  ₹50K - ₹20L     │ │  ₹2L - ₹1Cr      ││
│  └───────────────────┘ └───────────────────┘│
│                                             │
│  Selected product card gets a green border  │
│  + subtle scale 1.02 animation              │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │              NEXT →                     ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Step 2 — Loan Details:**
```
┌─────────────────────────────────────────────┐
│  Loan Amount                                │
│  ┌─────────────────────────────────────────┐│
│  │  ₹ 10,00,000                            ││
│  └─────────────────────────────────────────┘│
│  ┌──────────────────────────────────────┐   │
│  │  ₹5L          ●───────────  ₹2Cr    │   │
│  └──────────────────────────────────────┘   │
│   ↑ Custom slider with amount labels        │
│                                             │
│  Tenure                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐        │
│  │ 1Y │ │ 2Y │ │ 3Y │ │ 5Y │ │10Y │        │
│  └────┘ └────┘ └────┘ └────┘ └────┘        │
│   ↑ Pill selector, selected = dark fill     │
│                                             │
│  Purpose of Loan                            │
│  ┌─────────────────────────────────────────┐│
│  │  Purchase of residential property       ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Estimated EMI: ₹14,250/mo              ││
│  │  Interest Rate: 8.5% - 12.5%            ││
│  │  Types: Fixed, Floating, Reducing        ││
│  │  Spread: 2.00% over RBI base             ││
│  │  Total Interest: ₹7,10,000              ││
│  └─────────────────────────────────────────┘│
│   ↑ Live calculation card with mint bg      │
│                                             │
│  ┌────────────┐  ┌─────────────────────────┐│
│  │   ← BACK   │  │       NEXT →           ││
│  └────────────┘  └─────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Step 3 — Documents:**
```
┌─────────────────────────────────────────────┐
│  Required Documents                         │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  📄 Identity Proof        ┌──────────┐ ││
│  │     Aadhaar / PAN / Voter │ UPLOAD ↑ │ ││
│  │                           └──────────┘ ││
│  ├─────────────────────────────────────────┤│
│  │  📄 Address Proof         ┌──────────┐ ││
│  │     Utility Bill / Rent   │ UPLOAD ↑ │ ││
│  │                           └──────────┘ ││
│  ├─────────────────────────────────────────┤│
│  │  📄 Income Proof    ✅ Uploaded         ││
│  │     salary_slip.pdf  [View] [Remove]   ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌────────────┐  ┌─────────────────────────┐│
│  │   ← BACK   │  │       NEXT →           ││
│  └────────────┘  └─────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Step 4 — Review & Submit:**
```
┌─────────────────────────────────────────────┐
│  Review Application                         │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Product        Home Loan               ││
│  │  Amount         ₹10,00,000              ││
│  │  Tenure         10 Years                ││
│  │  Interest Rate  8.50% Floating          ││
│  │  Breakdown      Base 6.50% + Spread 2.00%││
│  │  Rate Range     8.50% - 12.50%           ││
│  │  Monthly EMI    ₹14,250                 ││
│  │  Purpose        Purchase residential... ││
│  │  Documents      3 attached              ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ☐ I agree to the terms and conditions     │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │          SUBMIT APPLICATION →           ││
│  └─────────────────────────────────────────┘│
│   ↑ Dark pill, full width, haptic on tap   │
└─────────────────────────────────────────────┘
```

---

### 8.7 Screen: Notifications

**Layout:**

```
┌─────────────────────────────────────────────┐
│  Notifications                              │
│  ┌──────────┐ ┌──────────┐                  │
│  │   All    │ │  Unread  │                  │
│  └──────────┘ └──────────┘                  │
│                                             │
│  Today                                      │
│  ┌─────────────────────────────────────────┐│
│  │  ● EMI Reminder                         ││
│  │    Your Home Loan EMI of ₹14,250 is     ││
│  │    due on Aug 15. Tap to pay now.       ││
│  │    2 hours ago                          ││
│  ├─────────────────────────────────────────┤│
│  │  ● Application Update                   ││
│  │    Your Vehicle Loan application has    ││
│  │    been approved! 🎉                    ││
│  │    5 hours ago                          ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Yesterday                                  │
│  ┌─────────────────────────────────────────┐│
│  │    Payment Confirmation                 ││
│  │    ₹14,250 received for Home Loan.      ││
│  │    Reference: TXN-2026071500123         ││
│  │    Jul 15, 2026                         ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Unread notifications have a small green dot (●) before the title and slightly tinted background
- Read notifications are plain
- Grouped by date sections
- Tapping a notification navigates to relevant screen (loan detail, payment, etc.)
- Swipe to mark as read, swipe to delete

---

### 8.8 Screen: Messages

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ← Back      Chat with Support              │
│                                             │
│          ┌──────────────────────┐           │
│          │ Hello! Your loan     │           │
│          │ application is under │           │
│          │ review. We'll update │           │
│          │ you within 48hrs.    │           │
│          │          10:30 AM  ✓ │           │
│          └──────────────────────┘           │
│                                             │
│  ┌──────────────────────┐                   │
│  │ Thank you! Can I     │                   │
│  │ upload additional    │                   │
│  │ documents?           │                   │
│  │ 10:35 AM  ✓✓        │                   │
│  └──────────────────────┘                   │
│                                             │
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────┐  ┌──┐ │
│  │  Type a message...              │  │ ↑│ │
│  └─────────────────────────────────┘  └──┘ │
│   ↑ Glass-effect input bar                 │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Staff messages: right-aligned, `surfaceMuted` background
- Borrower messages: left-aligned, `accentMint` background
- Message input bar uses Liquid Glass material
- Support for text and document attachments

---

### 8.9 Screen: Profile & KYC

**Layout:**

```
┌─────────────────────────────────────────────┐
│  Profile                            Edit →  │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │       [Avatar Circle - 80pt]            ││
│  │         Sourav Gupta                    ││
│  │         sourav@email.com                ││
│  │         ● KYC Verified ✓                ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Personal Details                           │
│  ┌─────────────────────────────────────────┐│
│  │  Phone         +91 98765 43210          ││
│  │  DOB           15 Mar 1995              ││
│  │  Gender        Male                     ││
│  │  PAN           ABCDE1234F               ││
│  │  Aadhaar       XXXX XXXX 1234           ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Address                                    │
│  ┌─────────────────────────────────────────┐│
│  │  123, MG Road, Sector 15               ││
│  │  Gurgaon, Haryana - 122001             ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Employment                                 │
│  ┌─────────────────────────────────────────┐│
│  │  Type           Salaried                ││
│  │  Employer       Tech Corp Pvt Ltd       ││
│  │  Monthly Income ₹1,25,000              ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │           Sign Out                      ││
│  └─────────────────────────────────────────┘│
│   ↑ Outline pill button, red text          │
└─────────────────────────────────────────────┘
```

---

## 9. LMS Staff App — Screens

### 9.1 Tab Structure

```
┌─────────────────────────────────────────────┐
│                                             │
│              [Active Screen]                │
│                                             │
├─────────────────────────────────────────────┤
│ 📊 Dash  📋 Apps  💰 Loans  📁 More        │
│           ↑ Liquid Glass Tab Bar            │
└─────────────────────────────────────────────┘
```

---

### 9.2 Screen: Staff Login

Identical structure to borrower login but with:
- **Gradient:** `gradientLavender` (soft purple) instead of mint
- **Title:** "LMS Staff Portal"
- **Role awareness:** After login, the app detects the user's role (admin/manager/loan_officer) from `staff_profiles` and adjusts the dashboard accordingly

---

### 9.3 Screen: Staff Dashboard

**Purpose:** KPI overview, pending actions, portfolio summary.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ← Liquid Glass Nav →                       │
│  Dashboard              [🔔] [⚙️]           │
│  Good Morning, Priya (Loan Officer)         │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  ░░░ gradient: lavender → white ░░░░░░ ││
│  │                                         ││
│  │  Portfolio Value                        ││
│  │  ₹2,45,00,000⁰⁰                        ││
│  │                                         ││
│  │  ┌────────┐ ┌────────┐ ┌────────┐      ││
│  │  │  156   │ │  12    │ │  8     │      ││
│  │  │Active  │ │Pending │ │Overdue │      ││
│  │  │Loans   │ │Apps    │ │Loans   │      ││
│  │  └────────┘ └────────┘ └────────┘      ││
│  │  ↑ Stat cards: green bg, amber bg,     ││
│  │    red bg respectively                  ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Pending Actions                   See All →│
│  ┌─────────────────────────────────────────┐│
│  │  📋  Loan Application #LMS-APP-000145  ││
│  │      Rahul Sharma • Home Loan           ││
│  │      ₹15,00,000    ● Under Review      ││
│  │                                         ││
│  │  ┌────────────┐  ┌────────────────┐     ││
│  │  │  REVIEW →  │  │   QUICK VIEW   │     ││
│  │  └────────────┘  └────────────────┘     ││
│  │   ↑ Dark pill      ↑ Beige pill         ││
│  ├─────────────────────────────────────────┤│
│  │  📋  Loan Application #LMS-APP-000144  ││
│  │      Anita Desai • Vehicle Loan         ││
│  │      ₹5,00,000     ● Under Review      ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Today's Collections              ₹4,28,500│
│  ┌─────────────────────────────────────────┐│
│  │  [████████████████████░░░░] 85%         ││
│  │  ₹4,28,500 of ₹5,04,000 target         ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Overdue Alerts                    See All →│
│  ┌─────────────────────────────────────────┐│
│  │  ⚠️ Vikram Patel — 45 days overdue      ││
│  │     Home Loan ₹28,500 pending           ││
│  ├─────────────────────────────────────────┤│
│  │  ⚠️ Meena Iyer — 15 days overdue        ││
│  │     Personal Loan ₹12,800 pending       ││
│  └─────────────────────────────────────────┘│
│   ↑ Red-tinted cards for overdue items     │
│                                             │
└─────────────────────────────────────────────┘
```

**Role-Based Dashboard Differences:**

| Element | Loan Officer | Manager | Admin |
|---------|-------------|---------|-------|
| Portfolio scope | Own borrowers only | Branch-wide | Organization-wide |
| Stat cards | Active/Pending/Overdue | + Disbursements this month | + Revenue, NPA ratio |
| Actions | Review apps, collect | + Approve/reject | + System config, user mgmt |
| Collection target | Personal target | Branch target | Organization target |

---

### 9.4 Screen: Applications Queue

**Purpose:** List of all loan applications assigned to the staff member, filterable.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  Applications                               │
│  🔍 Search by name or app number...        │
│  ↑ Search bar with Liquid Glass             │
│                                             │
│  ┌────────┐┌──────┐┌────────┐┌──────┐       │
│  │Pending ││Review││Approved││ All  │       │
│  └────────┘└──────┘└────────┘└──────┘       │
│  ↑ Scrolling filter pills                   │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Rahul Sharma                 2h ago    ││
│  │  LMS-APP-000145 • Home Loan             ││
│  │  ₹15,00,000     ● Under Review         ││
│  │  Credit Score: 742  │  Income: ₹1.5L/mo ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Anita Desai                  5h ago    ││
│  │  LMS-APP-000144 • Vehicle Loan          ││
│  │  ₹5,00,000      ● Submitted            ││
│  │  Credit Score: 698  │  Income: ₹85K/mo  ││
│  └─────────────────────────────────────────┘│
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  Vikram Patel                 1d ago    ││
│  │  LMS-APP-000143 • Personal Loan         ││
│  │  ₹2,00,000      ● Rejected             ││
│  │  Credit Score: 580  │  Income: ₹40K/mo  ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

---

### 9.5 Screen: Application Review (Detail)

**Purpose:** Full detail view for staff to review and approve/reject an application.

**Layout:**

```
┌─────────────────────────────────────────────┐
│  ← Back    Application Review        •••   │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  LMS-APP-000145         ● Under Review  ││
│  │  Submitted: Jul 20, 2026                ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Applicant                                  │
│  ┌─────────────────────────────────────────┐│
│  │  [Avatar] Rahul Sharma                  ││
│  │  📱 +91 98765 43210                     ││
│  │  📧 rahul.sharma@email.com              ││
│  │  KYC: ● Verified ✓                     ││
│  │                                         ││
│  │  Employment: Salaried                   ││
│  │  Employer: Infosys Ltd                  ││
│  │  Monthly Income: ₹1,50,000             ││
│  │  Credit Score: 742 (CIBIL)              ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Loan Request                               │
│  ┌─────────────────────────────────────────┐│
│  │  Product       Home Loan                ││
│  │  Amount        ₹15,00,000               ││
│  │  Tenure        15 Years (180 months)    ││
│  │  Interest      8.50% Floating           ││
│  │  Breakdown     Base 6.50% + Spread 2.00% ││
│  │  EMI           ₹14,773/mo               ││
│  │  Purpose       Purchase residential...  ││
│  │                                         ││
│  │  Collateral    Residential Property     ││
│  │  Est. Value    ₹25,00,000               ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Documents (3)                     View All │
│  ┌─────────────────────────────────────────┐│
│  │  📄 aadhaar_front.pdf     ✅ Verified   ││
│  │  📄 salary_slip_jun.pdf   ⏳ Pending    ││
│  │  📄 property_papers.pdf   ⏳ Pending    ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Approval History                           │
│  ┌─────────────────────────────────────────┐│
│  │  ● Submitted by Rahul      Jul 20      ││
│  │  ● Assigned to Priya (LO)  Jul 20      ││
│  │  ○ Awaiting review...                   ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Staff Notes                                │
│  ┌─────────────────────────────────────────┐│
│  │  Add a note about this application...   ││
│  └─────────────────────────────────────────┘│
│                                             │
├─────────────────────────────────────────────┤
│  [  REJECT  ]    [  SEND BACK  ]  [APPROVE]│
│   ↑ Red outline  ↑ Amber outline  ↑ Green  │
│                                  dark pill  │
│   ← Liquid Glass bottom bar →              │
└─────────────────────────────────────────────┘
```

**Design Notes:**
- Approval/Rejection opens a half-sheet with a mandatory comment field
- On approval, a success animation (confetti/checkmark) plays
- On rejection, a confirmation dialog appears
- "Send Back" returns to borrower for additional info
- `•••` menu: Assign to another officer, Download PDF summary, Flag for review

---

### 9.6 Screen: All Loans (Staff View)

Similar to borrower's "My Loans" but shows ALL loans (filtered by role scope):

**Additional columns visible to staff:**
- Borrower name and contact
- Assigned officer
- Branch
- Days overdue (if applicable)
- NPA classification

**Filter options (half-sheet):**
- Status (Active, Closed, Overdue, NPA, Written Off)
- Loan type
- Branch (admin/manager only)
- Assigned officer (manager/admin only)
- Amount range
- Date range

---

### 9.7 Screen: Loan Detail (Staff View)

Same as borrower loan detail (8.5) but with additional tabs:
- **Borrower** — Full borrower profile + credit history
- **Collateral** — Collateral details, valuation, status
- **Restructure** — Restructure history (if any)
- **Audit** — Full audit trail of all actions on this loan

Bottom action bar options for staff:
- **Mark Payment** (manual recording)
- **Initiate Restructure** (for overdue loans)
- **Update Status** (close, write off, etc.)

---

### 9.8 Screen: Borrower Profiles (Staff)

**Layout:**

```
┌─────────────────────────────────────────────┐
│  Borrowers                                  │
│  🔍 Search by name, phone, or PAN...       │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  [A] Rahul Sharma            →          ││
│  │      2 Active Loans • ₹20,00,000       ││
│  │      KYC: ✓ Verified                   ││
│  ├─────────────────────────────────────────┤│
│  │  [A] Anita Desai             →          ││
│  │      1 Active Loan • ₹5,00,000         ││
│  │      KYC: ⏳ Pending                   ││
│  ├─────────────────────────────────────────┤│
│  │  [A] Vikram Patel            →          ││
│  │      1 Active Loan • ₹3,00,000         ││
│  │      KYC: ✓ Verified  ⚠️ 1 Overdue    ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

---

### 9.9 Screen: More / Settings (Staff)

```
┌─────────────────────────────────────────────┐
│  More                                       │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  👤  My Profile               →        ││
│  │  🏢  Branch Details           →        ││
│  │  📊  Reports                  →        ││
│  │  ⚙️  System Settings          →  (Admin)││
│  │  👥  User Management         →  (Admin)││
│  │  📦  Loan Products           →  (Admin)││
│  ├─────────────────────────────────────────┤│
│  │  🔔  Notification Settings    →        ││
│  │  🌙  Dark Mode               [Toggle]  ││
│  │  ❓  Help & Support           →        ││
│  ├─────────────────────────────────────────┤│
│  │  🚪  Sign Out                           ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

**Admin-Only Screens (accessible from More):**

- **System Settings:** Manage `system_configs` table (penalty configs, app-wide settings)
- **RBI Rate Management:** Update RBI repo rate — triggers automatic recalculation of all active floating-rate loans via `update_floating_loan_rates()`. Shows current rate, last changed date, and count of affected loans before confirming.
- **User Management:** View/edit staff profiles, assign roles, activate/deactivate
- **Loan Products:** Create/edit loan products with all configurable fields:
  - Rate RANGE (min/max interest rate, not a single value)
  - Multiple supported interest types per product (Fixed + Floating + Reducing)
  - Spread over RBI base rate
  - Processing fees, prepayment penalties, late penalties
  - Amount range, tenure range, collateral requirement
  - Eligibility criteria (JSONB), required documents (JSONB)

---

## 10. Accessibility & HIG Compliance

### 10.1 Apple Human Interface Guidelines Compliance

| Guideline | Implementation |
|-----------|----------------|
| **Minimum tap target** | 44x44pt for all interactive elements |
| **Dynamic Type** | All text uses relative sizing with `.font(.system())` — scales with user preference |
| **Safe Area** | All content respects safe area insets (notch, home indicator) |
| **Color contrast** | All text meets WCAG AA (4.5:1 ratio minimum) |
| **Dark Mode** | Full dark mode support with semantic color tokens |
| **VoiceOver** | All buttons, cards, and badges have `accessibilityLabel` and `accessibilityHint` |
| **Reduce Motion** | Animations respect `UIAccessibility.isReduceMotionEnabled` — fall back to simple fades |
| **Bold Text** | Font weights increase when user enables Bold Text in Settings |
| **SF Symbols** | All icons use SF Symbols for automatic sizing, weight matching, and localization |
| **Standard navigation** | NavigationStack with back button, swipe-to-go-back gesture |
| **Haptic feedback** | Contextual haptics for actions (see Section 7.2) |
| **Native components** | Use SwiftUI `DatePicker`, `Picker`, `Toggle`, `Slider` for form inputs |

### 10.2 Accessibility Labels Example

```swift
// Amount display
HStack {
    Text("₹34,729")
    Text(".62")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Total outstanding: 34 thousand 7 hundred 29 rupees and 62 paisa")

// Status badge
StatusBadge(status: .active)
    .accessibilityLabel("Loan status: Active")

// Loan card
LoanCardView(loan: loan)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Home Loan, amount 15 lakh rupees, EMI 14 thousand 250 per month, status active")
    .accessibilityHint("Double tap to view loan details")
```

### 10.3 Localization Ready

- All user-facing strings should use `LocalizedStringKey`
- Currency formatting uses `Locale.current` aware formatters
- Date formatting respects device locale
- Number formatting (lakhs vs millions) based on Indian locale (`en_IN`)

```swift
extension Decimal {
    var indianCurrencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        return formatter.string(from: self as NSDecimalNumber) ?? "₹0"
    }
}
```

---

## Appendix: File Structure for UI Layer

```
LMS/LMS/
├── App/
│   └── LMSApp.swift
├── Config/
│   └── Supabase.plist
├── Models/                    ← Already created (18 files)
├── Services/
│   └── SupabaseManager.swift  ← Already created
├── Theme/
│   ├── ColorTokens.swift      ← Color system from Section 2
│   ├── Typography.swift       ← Font styles from Section 3
│   ├── Spacing.swift          ← Spacing tokens from Section 4
│   └── Haptics.swift          ← Haptic feedback helpers
├── Components/
│   ├── StatusBadge.swift      ← Pill status badges
│   ├── DarkPillButton.swift   ← Primary CTA button
│   ├── BeigePillButton.swift  ← Secondary CTA button
│   ├── OutlinePillButton.swift
│   ├── StatCard.swift         ← Metric display card
│   ├── LoanRowCard.swift      ← List row for loans
│   ├── AmountDisplay.swift    ← Split amount with superscript
│   ├── FormField.swift        ← Styled input field
│   ├── ProgressBar.swift      ← Loan repayment progress
│   ├── SectionHeader.swift    ← Title + "See All" action
│   ├── CircleIconButton.swift
│   └── GlassBottomBar.swift   ← Liquid Glass action bar
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── AuthViewModel.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Loans/
│   │   ├── LoansListView.swift
│   │   ├── LoanDetailView.swift
│   │   ├── EMIScheduleView.swift
│   │   ├── PaymentHistoryView.swift
│   │   └── LoansViewModel.swift
│   ├── Application/
│   │   ├── ApplyLoanView.swift
│   │   ├── ProductSelectionStep.swift
│   │   ├── LoanDetailsStep.swift
│   │   ├── DocumentUploadStep.swift
│   │   ├── ReviewSubmitStep.swift
│   │   └── ApplicationViewModel.swift
│   ├── Notifications/
│   │   ├── NotificationsView.swift
│   │   └── NotificationsViewModel.swift
│   ├── Messages/
│   │   ├── MessagesView.swift
│   │   └── MessagesViewModel.swift
│   └── Profile/
│       ├── ProfileView.swift
│       ├── EditProfileView.swift
│       └── ProfileViewModel.swift
└── Navigation/
    └── MainTabView.swift

LMS Staff/LMS Staff/
├── App/
│   └── LMS_StaffApp.swift
├── Config/
│   └── Supabase.plist
├── Models/                    ← Shared with LMS
├── Services/
│   └── SupabaseManager.swift  ← Shared with LMS
├── Theme/                     ← Same as LMS (shared design system)
├── Components/                ← Same as LMS (shared components)
├── Features/
│   ├── Auth/
│   │   ├── StaffLoginView.swift
│   │   └── StaffAuthViewModel.swift
│   ├── Dashboard/
│   │   ├── StaffDashboardView.swift
│   │   └── StaffDashboardViewModel.swift
│   ├── Applications/
│   │   ├── ApplicationsQueueView.swift
│   │   ├── ApplicationReviewView.swift
│   │   └── ApplicationsViewModel.swift
│   ├── Loans/
│   │   ├── AllLoansView.swift
│   │   ├── StaffLoanDetailView.swift
│   │   └── StaffLoansViewModel.swift
│   ├── Borrowers/
│   │   ├── BorrowerListView.swift
│   │   ├── BorrowerDetailView.swift
│   │   └── BorrowerViewModel.swift
│   ├── Settings/
│   │   ├── MoreView.swift
│   │   ├── SystemSettingsView.swift  (Admin)
│   │   ├── UserManagementView.swift  (Admin)
│   │   └── LoanProductsView.swift    (Admin)
│   └── Reports/
│       ├── ReportsView.swift
│       └── ReportsViewModel.swift
└── Navigation/
    └── StaffTabView.swift
```

---

> **This document is the single source of truth for all UI/UX decisions.**
> Every screen implementation should reference this spec for colors, spacing,
> component usage, and layout structure. Deviations require updating this document first.
