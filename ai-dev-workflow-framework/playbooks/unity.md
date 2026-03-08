# Unity Game

**Architecture:** Clean Architecture with Assembly Definitions (asmdef)

## Folder structure
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
  Plugins/
tests/
  EditMode/
  PlayMode/
```

## Typical Discovery Q&A
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

## Architecture rules (Plan phase)
- Domain.asmdef: NO references (pure C#, no UnityEngine)
- Application.asmdef: references Domain only
- Infrastructure.asmdef: references Application, Domain
- Presentation.asmdef: references all above + Unity assemblies
- No MonoBehaviour in Domain or Application
- ScriptableObjects only in Presentation or Infrastructure
- Game logic testable without Play Mode (NUnit EditMode)
- No FindObjectOfType or static singletons in Domain/Application
- No `./generated/` file modifications unless explicitly asked

## Design rules (Design phase)
- UI Toolkit or Unity UI (Canvas) — pick one, don't mix
- Color palette in ScriptableObject or USS variables
- Consistent spacing and sizing across UI panels
- Test at target resolutions (mobile: 1080x1920, desktop: 1920x1080)
- CanvasScaler: Scale With Screen Size
- Minimum font size 14pt at target resolution

## Build/test
```
# EditMode tests (fast, no Play Mode):
Unity > Test Runner > EditMode > Run All

# PlayMode tests (integration):
Unity > Test Runner > PlayMode > Run All

# Verify: zero console errors, no missing prefab refs, clean scene load
```
