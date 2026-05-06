# Skate Knight — Game Design Document (GDD)

**Project**: Skate Knight  
**Genre**: 3D endless runner (lane-based)  
**Platform**: PC (Windows), keyboard first  
**Engine**: Godot 4.6  
**Version**: Draft v1 (living document)  

---

## High concept
You are the **Skate Knight**, sprinting across an endless ruined bridge/track on skates. Dodge debris and beams by **changing lanes**, **jumping**, and **sliding** while collecting coins and grabbing occasional powerups to push your run farther.

---

## Design pillars
- **Readable at speed**: Clear silhouettes, strong contrast, predictable lane layout.
- **Simple inputs, skill mastery**: Few actions, tight timing windows, high execution ceiling.
- **Constant forward momentum**: The world streams in; the player is always moving.
- **Satisfying feedback**: Coins, UI callouts, sound cues, and “crash” clarity.
- **Stylized atmosphere**: Foggy distance + toon shading for a moody, graphic look.

---

## Target player experience
Players should quickly understand:
- “I’m always moving forward.”
- “Obstacles are avoided by lane swap / jump / slide.”
- “Coins and powerups make the run feel rewarding.”

The run should feel:
- **Fast**, but fair.
- **Cleanly readable** at a glance.
- **Retryable** (quick restart, short time to fun).

---

## Core gameplay loop
1. **Run forward automatically** on a repeating track.
2. **React** to incoming obstacles (lane swap / jump / slide).
3. **Collect** coins for score/reward.
4. **Pick up** powerups periodically for temporary advantages.
5. **Crash** ends the run → show results → restart.

---

## Controls (keyboard)
These match the current input setup in the project.

- **Move left**: `A` / Left Arrow  
- **Move right**: `D` / Right Arrow  
- **Jump**: `W` / Space / Up Arrow  
- **Slide**: `S` / Down Arrow  
- **Boost**: `Shift` (reserved/partial feature depending on build)  
- **Pause**: `Esc`  

---

## Player mechanics
### Movement model
- **Forward motion**: Automatic forward speed that ramps up over time.
- **Lanes**: Discrete lane positions (default 4 lanes) with smooth interpolation to target lane.

### Actions
- **Lane change**
  - Trigger: tap left/right.
  - Behavior: moves toward target lane at `lane_change_speed`.
  - Goal: crisp side movement without overshoot.

- **Jump**
  - Trigger: jump input while grounded and not sliding.
  - Behavior: sets vertical velocity; gravity pulls down.
  - Purpose: clear low rubble and hit coin lines.

- **Slide**
  - Trigger: slide input while grounded.
  - Behavior: temporary reduced collider/visual height.
  - Purpose: pass under high beams.

### Fail condition
- **Crash on obstacle hit** (non-floor collision). Run ends immediately (with a short debounce).

---

## Obstacles & track
### Track chunking
- The track is assembled from repeating **chunks** spawned ahead of the player and culled behind.
- A “floating origin” style rebase may be used to avoid precision issues in long runs.

### Obstacle types (current)
- **Low rubble**: avoid by lane change or jump (depending on placement).
- **High beam**: avoid by lane change or slide.

### Difficulty ramp (current direction)
- Over time, obstacle spawn chance increases toward a max value.
- Optional future ramp: speed increases, obstacle spacing tightens, multi-threat patterns appear.

---

## Coins, scoring, and progression
### Coins
- Coins appear in trails aligned to lanes, sometimes with height variation for context.
- Collecting coins increases a **coin counter** and can influence score.

### Score (recommended model)
- **Distance score**: grows continuously with distance traveled (primary score).
- **Coin bonus**: coins add a smaller additive bonus.
- **Combo / streak (future)**: reward clean dodges or consecutive coin pickups.

### Meta progression (future)
- Cosmetic unlocks (colors, trails), simple upgrades (magnet radius, starting speed), or daily challenges.

---

## Powerups (current)
Powerups spawn periodically ahead of the player and last a fixed duration.

- **Magnet**
  - Pulls nearby coins toward the player.
- **Invincible**
  - Lets the player break/despawn obstacles on contact; may award bonus coins.
- **Double coins**
  - Coin pickups grant 2× for the duration.

---

## UI / UX
### In-run HUD
- **Coins**
- **Score**
- **Distance**

### Pause menu
- Resume
- Restart
- Quit

### Start screen (current)
- Acts as the entry point and can show a short preview of the main scene.

### Game over
- Show run over state and prompt for restart.
- Recommended add: run summary (distance, coins, score) + “Best” stats.

---

## Audio
### Music
- One looping track (title + in-run, or separate tracks).

### SFX (current direction)
- Jump
- Coin pickup
- Powerup pickup
- Crash
- UI click

---

## Visual style
- **Toon shading** for environment + props.
- **Foggy atmosphere** (distance fog / volumetric fog) to create mood and control long-range readability.
- **Materials**
  - Bridge/track uses a dark grey brick/stone look.
  - Obstacles are high-contrast red to read quickly.

---

## Level design principles (endless runner patterns)
- **Single-decision beats** early (one obstacle to react to).
- **Two-decision beats** mid (obstacle + coin choice, or obstacle chain).
- **Pattern language**: teach recognizable shapes (e.g., “beam then rubble”).
- **Fairness rules**
  - Ensure reaction time at top speed.
  - Avoid unavoidable combinations across all lanes.
  - Keep silhouettes distinct and readable through fog/lighting.

---

## Technical overview (current architecture)
- **Main scene**: player, camera rig, chunk spawner, run manager, HUD, pause/menu layers.
- **Chunk spawner**: instantiates track chunks ahead, randomizes lanes, coin trails, obstacle jitter, timed powerups.
- **Player controller**: lane movement, jump/slide physics, collision crash handling, powerup timers.
- **Autoloads**: music + sfx singletons.

---

## Known risks / constraints
- **Readability vs fog**: too much fog can make obstacles unfair; tune fog depth + contrast.
- **Procedural spawning fairness**: randomization must preserve avoidability; use spacing rules and pattern sets.
- **Performance**: keep mesh/overdraw reasonable; prefer instancing and cull behind quickly.

---

## Playtest checklist (quick)
- Can a new player survive 20–30 seconds on first try?
- Do players understand slide vs jump within 1–2 runs?
- Are obstacle hitboxes intuitive?
- Do coins feel reachable and rewarding (sound + UI)?
- Does difficulty ramp feel “earned,” not random?

---

## Roadmap (suggested)
### MVP (core runner)
- Tight movement feel, stable spawn/cull, clear obstacles, basic HUD, restart loop.

### Next
- Pattern-based obstacle sets, better run summary, more powerups, improved audio feedback.

### Polish
- Visual effects (dust trails, impact flashes), accessibility settings (invert, color contrast), optimization.

