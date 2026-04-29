## Skate Knight — Phase 1 (Ancient Castle Ruins) Prototype

### Phase 1 asset checklist (3D, cel‑shaded anime, **4 lanes**, keyboard)

#### Folder layout (Godot)
- `assets/characters/`
- `assets/props_castle/`
- `assets/track_modules/`
- `assets/vfx/`
- `assets/ui/`
- `assets/audio/`
- `materials/`
- `scenes/`
- `scripts/`

#### Player (3D)
- **Hero character (1)**: rigged `.glb`, anime proportions, readable silhouette
- **Skateboard (1)**: deck + trucks + wheels (separate mesh OK)
- **Animation clips (minimum)**
  - Ride loop
  - Lean left / lean right (or blendspace)
  - Jump + land
  - Slide/duck
  - Crash/fall (end run)
  - (Optional for Phase 1+) Grind loop, manual loop, 2–4 trick clips

#### Track / environment (Ancient castle ruins biome)
- **Track modules (12)** (snap length ~20–40m)
  - Straight short, straight long
  - Gentle curve L, gentle curve R
  - Slight up, slight down
  - Narrow corridor
  - Gap bridge‑broken chunk
  - Rail walkway chunk
  - Ramp/ledge chunk
  - “Rest” chunk (low difficulty)
- **Set dressing props (25)**
  - Cracked stone columns (3 variants)
  - Rubble piles (3)
  - Broken arches (2)
  - Wall segments (3)
  - Torches/sconces (2)
  - Hanging banners/tapestries (2)
  - Statues (2)
  - Spike fence / iron gate (2)
  - Crates/barrels (2)
  - Chains/candelabras (2)
  - Signposts / warning boards (2)
- **Backdrop**
  - Distant cliffs + ruined castle silhouette + fog plane / skybox

#### Gameplay objects (3D)
- **Lane layout**: 4 lanes centered on X, spacing ~2.0m (tunable)
- **Obstacles (6)**
  - Low rubble (jump)
  - Fallen beam (slide)
  - Full lane wall (forces lane swap)
  - Gap (jump)
  - Spikes (punish bad lane)
  - Breakable debris (optional “safe if shielded” later)
- **Pickups (3)**
  - Coin (gem shard / “relic”)
  - Boost orb (glowing rune)
  - Shield (sigil)

#### VFX (stylized)
- Coin pickup burst (ring + stars)
- Landing dust puff
- Speed lines overlay
- Boost trail
- Crash comic burst decal (optional)

#### UI (2D)
- HUD: score, distance, coins, boost bar
- Pause menu + results screen (minimal)
- Icons: coin, boost, shield

#### Audio (placeholder OK)
- Skate roll loop (stone)
- Jump/land, slide, pickup, crash
- 1 music loop

### Phase 1 implementation status
This repo includes a fresh Godot 4 project with:
- 4‑lane runner controls (A/D or ←/→), jump (W/↑/Space), slide (S/↓)
- Modular chunk spawner (placeholder)
- Basic obstacles + pickups (placeholder)
- Minimal HUD

To swap in Itch.io assets later:
- Replace placeholder meshes in `scenes/track/` and `scenes/props/`
- Keep collision shapes + socket transforms stable

