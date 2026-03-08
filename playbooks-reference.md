# Project Type Playbooks

Companion reference to the **AI-Assisted Development Workflow**.

**When to use:** During **Phase 2 (Plan)**, look up your project type here for architecture rules, folder structure, and typical Q&A questions. During **Phase 3 (Design)**, check for UI/design rules specific to your project type. During **Phase 4 (Build & Test)**, use the build/test commands listed here.

Each playbook follows the same structure for consistency:
- **Architecture** — recommended pattern and dependency direction
- **Folder structure** — where files go
- **Typical Discovery Q&A** — common questions for Phase 1
- **Architecture rules** — constraints to enforce in the Plan phase
- **Design rules** — UI/UX guidance for the Design phase (if applicable)
- **Build/test commands** — what to run in the Build & Test phase

---

## .NET Web API / Service

**Architecture:** Clean (Onion) — Domain → Application → Infrastructure → API

**Folder structure:**
```
src/
  Domain/           # Entities, value objects, domain events, interfaces
  Application/      # Use cases, DTOs, validation, handlers
  Infrastructure/   # EF Core, external services, email, file storage
  Api/              # Endpoints, middleware, DI composition root
tests/
  Domain.Tests/
  Application.Tests/
  Infrastructure.Tests/
  Api.IntegrationTests/
```

**Typical Discovery Q&A:**
```
1. API style?
   a) Minimal API (recommended for .NET 8+)
   b) Controllers
2. Auth?
   a) JWT Bearer  b) Cookie  c) API key  d) None for now
3. Database?
   a) PostgreSQL  b) SQL Server  c) SQLite (dev only)
4. CQRS / MediatR or direct service injection?
   a) MediatR (recommended for complex domains)
   b) Direct service injection (simpler, fewer abstractions)
```

**Architecture rules (Plan phase):**
- Domain: zero package references — no EF Core, no ASP.NET
- Application: references only Domain
- Infrastructure: references Application + Domain
- Api: references all (composition root) but only through interfaces
- All DbContext access in Infrastructure, never in Application
- Entities use Fluent API config, not data annotations
- Microsoft.Extensions.DependencyInjection for DI
- No hardcoded connection strings or secrets — use configuration

**Design rules (Design phase):** N/A — backend only. If the API serves a frontend, the frontend project has its own playbook.

**Build/test:**
```
dotnet build --no-restore
dotnet test --no-build --verbosity normal
```

---

## Blazor WebAssembly

**Architecture:** Clean Architecture + component-based UI with MVVM-like separation

**Folder structure:**
```
src/
  Domain/
  Application/
  Infrastructure/        # HttpClient-based service implementations
  Client/                # Blazor WASM project
    Components/
      Shared/            # Layout, NavMenu, reusable components
      Features/          # Feature-based component folders
    Services/            # Client-side service interfaces + implementations
    wwwroot/
  Server/ (if hosted)    # ASP.NET host, API controllers
tests/
  Domain.Tests/
  Application.Tests/
  Client.Tests/          # bUnit component tests
```

**Typical Discovery Q&A:**
```
1. Hosting model?
   a) Standalone WASM (separate API)
   b) ASP.NET Hosted (Server + Client)
   c) Blazor Hybrid (MAUI shell)
2. State management?
   a) Cascading parameters + service injection (recommended for most)
   b) Fluxor (Redux-like, for complex state)
   c) Simple state containers
3. Component library?
   a) Custom components  b) MudBlazor  c) Radzen  d) Other
4. Auth?
   a) OIDC / Identity  b) JWT  c) None for now
```

**Architecture rules (Plan phase):**
- Clean Architecture layers same as .NET Web API
- CSS isolation (.razor.css) per component
- Prefer @bind and EventCallback over JS interop
- Each feature component: Default, Loading, Empty, Error states
- Use `<ErrorBoundary>` around feature components
- HttpClient calls go through service interfaces, not direct in components
- No business logic in components — delegate to services

**Design rules (Design phase):**
- CSS variables in wwwroot/css/app.css for theming
- Create Shared/ component for each reusable element
- Component states checklist: Default, Loading, Empty, Error, Disabled
- Responsive breakpoints: 375px (mobile), 768px (tablet), 1280px (desktop)
- Accessibility: semantic HTML, ARIA labels on custom components
- Test with browser dev tools throttled to "Slow 3G" for loading states

**Build/test:**
```
dotnet build
dotnet test
# Browser console check for WASM errors after publish
```

---

## .NET MAUI Mobile App

**Architecture:** MVVM + Clean Architecture + Shell navigation

**Folder structure:**
```
src/
  Domain/
  Application/
  Infrastructure/
  MauiApp/
    Views/                # XAML pages
    ViewModels/           # One ViewModel per View
    Services/             # Platform-specific services
    Controls/             # Custom controls
    Resources/
      Styles/             # Colors.xaml, Styles.xaml
      Fonts/
      Images/
    Platforms/             # Android/iOS specific code
    MauiProgram.cs         # DI composition root
tests/
  Domain.Tests/
  Application.Tests/
  MauiApp.Tests/
```

**Typical Discovery Q&A:**
```
1. Target platforms?
   a) Android + iOS  b) Android only  c) iOS + macOS  d) All
2. Navigation?
   a) Shell (tab + flyout, recommended)
   b) NavigationPage (stack)
   c) Custom
3. Local storage?
   a) SQLite  b) Preferences (key-value)  c) File-based  d) LiteDB
4. Offline-first?
   a) Yes — local DB with sync
   b) No — handle connectivity gracefully
5. MVVM toolkit?
   a) CommunityToolkit.Mvvm (recommended)
   b) Prism  c) ReactiveUI
```

**Architecture rules (Plan phase):**
- ViewModels never reference Views or XAML types
- ViewModels depend on Application layer interfaces, not Infrastructure
- ICommand via RelayCommand (CommunityToolkit.Mvvm)
- Navigation via Shell routes, not direct page instantiation
- Platform-specific code: `#if ANDROID` / `#if IOS` or Platforms/ folder
- No business logic in code-behind (.xaml.cs) — delegate to ViewModel
- DI registration in MauiProgram.cs

**Design rules (Design phase):**
- All colors in Resources/Styles/Colors.xaml
- All styles in Resources/Styles/Styles.xaml (implicit + explicit)
- Platform-specific values: `<OnPlatform>`, `<OnIdiom>`
- Touch targets minimum 48x48dp
- Test with both light and dark AppTheme
- Avoid hardcoded pixel values — use relative sizing
- Safe area handling (notch, bottom bar)
- Test on both Android emulator and iOS simulator

**Build/test:**
```
dotnet build
dotnet test
# Device/emulator testing:
dotnet build -t:Run -f net9.0-android
dotnet build -t:Run -f net9.0-ios
```

---

## Unity Game

**Architecture:** Clean Architecture with Assembly Definitions (asmdef)

**Folder structure:**
```
Assets/
  _Project/
    Domain/               # Pure C# — no MonoBehaviour, no UnityEngine
      Domain.asmdef
    Application/          # Use cases, game state, interfaces
      Application.asmdef  # References: Domain
    Infrastructure/       # Save system, analytics, platform services
      Infrastructure.asmdef   # References: Application, Domain
    Presentation/         # MonoBehaviours, ScriptableObjects, UI
      Presentation.asmdef     # References: all above
    Resources/
    Scenes/
    Prefabs/
  Plugins/                # Third-party assets
tests/
  EditMode/               # Fast tests, no Play Mode
  PlayMode/               # Integration tests
```

**Typical Discovery Q&A:**
```
1. Game loop?
   a) Turn-based  b) Real-time  c) Hybrid (real-time with pause)
2. Scene management?
   a) Single scene + runtime instantiation
   b) Multi-scene additive loading
   c) Scene per level
3. Input system?
   a) New Input System (action maps, recommended)
   b) Legacy Input Manager
4. State management?
   a) ScriptableObject events  b) Singleton GameManager  c) State machine
5. Save system?
   a) JSON to persistentDataPath  b) PlayerPrefs  c) Custom binary
```

**Architecture rules (Plan phase):**
- Domain.asmdef: NO references (pure C#, no UnityEngine)
- Application.asmdef: references Domain only
- Infrastructure.asmdef: references Application, Domain
- Presentation.asmdef: references all above + Unity assemblies
- No MonoBehaviour in Domain or Application
- ScriptableObjects only in Presentation or Infrastructure
- Game logic testable without Play Mode (NUnit EditMode)
- No FindObjectOfType or static singletons in Domain/Application
- No `./generated/` file modifications unless explicitly asked

**Design rules (Design phase):**
- UI Toolkit or Unity UI (Canvas) — pick one, don't mix
- Define color palette in a ScriptableObject or USS variables
- Consistent spacing and sizing across all UI panels
- Test UI at target resolutions (mobile: 1080x1920, desktop: 1920x1080)
- Responsive scaling: CanvasScaler set to Scale With Screen Size
- Accessibility: readable font sizes (min 14pt at target resolution)

**Build/test:**
```
# EditMode tests (fast, no Play Mode):
Unity > Window > General > Test Runner > EditMode > Run All

# PlayMode tests (integration):
Unity > Window > General > Test Runner > PlayMode > Run All

# Verify:
# - Zero console errors in Play Mode
# - No missing references on prefabs
# - Scene loads without null refs
# - All asmdef compile independently
```

---

## ESP32 / Embedded (PlatformIO)

**Architecture:** Layered — HAL → Services → Application → main

**Folder structure:**
```
project/
  src/
    main.cpp              # Setup + loop, wires everything
    app/                  # Application logic, state machines
    services/             # WiFi, MQTT, sensor reading, LED control
    hal/                  # Hardware abstraction (pin configs, drivers)
  include/
    config.h              # All pin assignments, thresholds, timing constants
  lib/                    # Project-specific libraries
  test/                   # Unity (C test framework) tests
  platformio.ini
```

**Typical Discovery Q&A:**
```
1. Board?
   a) ESP32-DevKitC  b) ESP32-S3  c) ESP32-C3  d) Other
2. Framework?
   a) Arduino (faster start, recommended for most)
   b) ESP-IDF (full control, FreeRTOS)
3. Connectivity?
   a) WiFi only  b) WiFi + BLE  c) BLE only  d) None
4. Communication protocol?
   a) MQTT (for IoT/home automation)  b) HTTP REST
   c) WebSocket  d) ESPNow (device-to-device)
5. Power mode?
   a) Always on (USB powered)  b) Deep sleep (battery)  c) Light sleep
```

**Architecture rules (Plan phase):**
- hal/: ONLY pin definitions and hardware-specific drivers
- services/: never directly access GPIO — go through hal/
- app/: state machines and logic — no hardware calls
- main.cpp: only wires dependencies and runs the loop
- All magic numbers in config.h (`#define` or `constexpr`)
- Pin assignments never hardcoded in logic files
- ISR handlers: minimal work, set flag, process in loop
- No blocking delays in app/ — use millis()-based timing

**Design rules (Design phase):** N/A — no UI. If the device has a display (OLED, TFT), define screen layouts and fonts in a separate display service under services/.

**Build/test:**
```
pio run                          # Build
pio run --target upload          # Flash to device
pio device monitor --baud 115200 # Serial monitor
pio test -e native               # Logic tests (no device needed)
pio test -e esp32dev             # On-device tests
```

---

## MCP Server

**Architecture:** Handler-per-tool + shared services

**Folder structure (C# / ModelContextProtocol.Server):**
```
src/
  McpServer/
    Tools/                # One class per tool
    Services/             # Shared services (file access, API clients)
    Models/               # Request/response DTOs
    Program.cs            # Host builder, DI, tool registration
tests/
  McpServer.Tests/
```

**Folder structure (TypeScript / MCP SDK):**
```
src/
  tools/                  # One file per tool
  services/
  types/
  index.ts
tests/
```

**Typical Discovery Q&A:**
```
1. Runtime?
   a) C# with ModelContextProtocol.Server (recommended for .NET projects)
   b) TypeScript with @modelcontextprotocol/sdk
   c) Python with FastMCP
2. Transport?
   a) stdio (local CLI integration)  b) SSE (remote)  c) Both
3. Tools to expose? (list each with purpose)
4. Persistent state between calls?
   a) No — stateless (recommended)  b) Yes — describe what
5. Auth?
   a) None (local only)  b) API key  c) OAuth
```

**Architecture rules (Plan phase):**
- One tool = one class/function with clear input/output schema
- Tools must not depend on each other directly
- Shared logic in services, injected via DI
- Tool descriptions clear enough for an LLM to choose when to use them
- Structured error responses, not raw exceptions
- Document all side effects in tool descriptions
- No secrets in tool code — use configuration

**Design rules (Design phase):** N/A — no UI.

**Build/test:**
```
# C#
dotnet build
dotnet test

# TypeScript
npm run build
npm test
```

---

## Static Site / Landing Page

**Architecture:** Component-based, minimal structure

**Folder structure:**
```
src/
  index.html
  css/
    variables.css          # Design tokens (colors, spacing, fonts)
    styles.css
  js/
    main.js
  assets/
    images/
    fonts/
```

**Typical Discovery Q&A:**
```
1. Build tooling?
   a) Plain HTML/CSS/JS (simplest)
   b) Vite (modules, HMR)
   c) Astro / 11ty (static site generator)
2. Sections needed? (list all)
3. Responsive approach?
   a) Mobile-first: 375 → 768 → 1280 (recommended)
   b) Desktop-first: 1440 → 768 → 375
4. Animations?
   a) Minimal (fade-in, transitions)
   b) Rich (scroll-triggered, parallax, micro-interactions)
   c) None
5. Hosting?
   a) GitHub Pages  b) Netlify / Vercel  c) Self-hosted
```

**Architecture rules (Plan phase):**
- CSS variables for all design tokens (colors, spacing, fonts)
- No inline styles — all styling in CSS files
- Semantic HTML (header, main, nav, section, footer)
- Images optimized (WebP preferred, lazy loading)
- Minimal JS — CSS-only solutions preferred for animations
- No heavy frameworks unless justified by complexity

**Design rules (Design phase):**
Phase 3 (Design) is **mandatory** for this project type — this is visual-first work.
- Define complete design direction before any code
- Color palette with CSS variables
- Font pairing (display + body) with CDN links
- Spacing scale (4px or 8px base)
- Create a full-page HTML mockup artifact for review
- Get approval before splitting into production files
- List ALL assets: icons, images, fonts, illustrations
- Interactive states on all clickable elements
- Responsive behavior at 375px, 768px, 1280px

**Build/test:**
```
# Plain HTML — open in browser, no build step
# Vite
npm run build
npm run preview

# Verify: Lighthouse audit for performance, accessibility, SEO
```
