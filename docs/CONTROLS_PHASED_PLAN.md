## Controls phased plan (3D, 4 lanes, keyboard)

This document defines how player controls evolve by phase for the *Skate Knight* runner prototype (Subway Surfers / Temple Run + Skate-inspired “flow” later).

### Baseline conventions (all phases)
- **Input devices**: Keyboard (WASD + Arrow keys), optional Space/Shift/Ctrl
- **Camera**: 3rd-person chase camera
- **Movement model**: forward auto-run; player controls lateral lane selection and action timing
- **Lane model**: **4 lanes** at fixed X offsets with smooth interpolation to target lane

#### Default key map (recommended)
- **Move Left**: `A` / `Left Arrow`
- **Move Right**: `D` / `Right Arrow`
- **Jump**: `W` / `Up Arrow` / `Space`
- **Slide/Duck**: `S` / `Down Arrow`
- **Boost** (Phase 2+): `Shift`
- **Manual/Balance** (Phase 3+): `Ctrl` (or `C`)
- **Pause**: `Esc`
- **Restart Run** (Phase 1+ quality-of-life): `R`

---

## Phase 1 — Core runner controls (First Playable)
**Goal**: play a full run loop with readable inputs and reliable collision.

### Required mechanics
- **Lane change (4 lanes)**:
  - Tap left/right to move to adjacent lane (clamped to 0..3).
  - Smooth movement to lane center (no instant teleport).
- **Jump**:
  - Only while grounded.
  - Fixed jump height (tunable).
- **Slide/Duck**:
  - Only while grounded.
  - Temporary reduced collider height for “high” obstacles.
- **Forward movement**:
  - Constant forward speed with light ramp over time (tunable).

### Feel/tuning targets
- Lane change completes in ~0.10–0.20s
- Jump hang time readable; landing is forgiving
- Slide duration ~0.5–0.8s; clear silhouette change

### Acceptance criteria
- Player can survive 60–90 seconds with skill
- No “impossible” obstacle timing caused by slow/unclear inputs

---

## Phase 1.5 — Input + camera polish
**Goal**: make the controls feel consistent and predictable.

- **Input buffering**:
  - Small buffer for jump/slide (e.g., 100–150ms) so late/early presses feel fair.
- **Coyote time**:
  - Allow jump briefly after leaving ground (e.g., 80–120ms).
- **Camera assist**:
  - Stable framing; minimal jitter; camera always keeps player visible.
- **Crash/restart loop**:
  - `R` restarts run; `Esc` pause menu.

---

## Phase 2 — Boost + stamina-style resource (arcade depth)
**Goal**: add controlled bursts of speed and player agency without complexity.

### New mechanics
- **Boost meter**:
  - Fills from distance + coin streaks + clean dodges.
- **Boost activation**:
  - Hold `Shift` to spend boost.
  - Optional: during boost, widen coin pickup radius and slightly increase lane change speed.

### Acceptance criteria
- Boost feels like a tactical choice (save vs spend)
- Boost doesn’t create unavoidable obstacle chains

---

## Phase 3 — Skate-inspired balance controls (manual/grind)
**Goal**: introduce “Skate” skill expression while keeping runner readability.

### New mechanics
- **Manual mode**:
  - Hold `Ctrl` to enter manual while grounded on flat segments.
  - Balance meter drifts; correct with A/D (or Left/Right).
  - Reward: score multiplier / boost gain / coin bonus.
- **Grind**:
  - Enter grind on rail contact (optionally require holding `Ctrl`).
  - Balance uses same meter system as manual.

### UX requirements
- Balance UI must be readable at speed
- Clear audio feedback when balance is near-fail

---

## Phase 4 — Tricks (optional complexity)
**Goal**: quick trick system that doesn’t slow down runner decisions.

### Input concept (keyboard-friendly)
- **Jump + direction** at takeoff selects trick:
  - Jump only: Ollie
  - Jump + Left: Trick A
  - Jump + Right: Trick B
  - Jump + Down (optional): Grab

### Constraints
- Keep trick list small (4–6) early.
- Reward clean landings; punish spam via risk (bad landings).

---

## Phase 5 — Accessibility + customization
**Goal**: let players tailor difficulty and comfort.

- Remappable keys
- Lane-change assist (stronger snap, slower drift)
- Slide/jump buffer sliders
- Toggle “hold vs tap” for boost/manual

