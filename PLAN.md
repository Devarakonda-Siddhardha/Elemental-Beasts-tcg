# Implementation Plan — Game End / Victory Screen & Main Menu Thematic BGM (`v1.12.0`)

## 1. Overview & Goals
1. **Write `PLAN.md`** detailing the architecture, UI layout, audio synthesis/playback, and automated verification tests.
2. **Create a Cinematic Game End / Victory & Defeat Screen** in `scripts/ui/battle_controller.gd` triggered when `game_ended(winner, reason)` fires.
3. **Add a Thematic Main Menu Background Music (BGM) Track** that matches the dark-fantasy *Elemental Beasts TCG — Legacy Reborn* dragon portal theme, loops seamlessly on the Main Menu, and includes dedicated **BGM Mute & Volume Controls** inside `scripts/audio/sound_manager.gd`.

---

## 2. Feature 1: Cinematic Game End / Victory & Defeat Screen
Replace the basic text-only game-over banner in `BattleController._on_game_ended` with a full-screen animated **Victory / Defeat Overlay Modal (`GameEndScreen`)**:

- **Full-Screen Animated Backdrop (`GameEndScreen`, `z_index = 95`)**:
  - **Victory (Player 1 Wins)**: Deep royal obsidian-and-gold vignette with rising golden dragon embers, expanding solar shockwave rings, and a gleaming gold crest border.
  - **Defeat (Opponent Wins)**: Abyssal crimson-and-violet shadow vignette with drifting ash particles and a dramatic dark-crimson border.
- **Header Banner & Crest**:
  - Large illuminated title: **`🏆 VICTORY! — DRAGON MASTER TRIUMPHANT 🏆`** (gold) or **`💀 DEFEAT — FALLEN IN THE ARENA 💀`** (crimson), plus the victory/defeat reason subtitle.
- **MVP / Ace Dragon Card Showcase (`CardUI`)**:
  - Highlights the winning player's strongest Dragon on the battlefield (or signature Dragon) rendered as a full **`CardUI`** card on an ornate pedestal.
- **Match Summary & Duel Statistics Panel**:
  - Displays Turns Elapsed, Final Player HP vs Opponent HP, Element Stones Harnessed, Surviving Dragons on Field, and Victory Honors badge.
- **Action Buttons**:
  - **`⚔ Play Again (Rematch)`**: Immediately starts a fresh match with the same Starter Deck and mode.
  - **`🎁 Open Booster Packs`**: Transitions directly to `res://scenes/pack_opening.tscn`.
  - **`🏰 Return to Main Menu`**: Transitions cleanly to `res://scenes/main_menu.tscn`.

---

## 3. Feature 2: Main Menu Thematic Background Music (BGM)
- **Thematic BGM Track (`res://assets/audio/bgm/main_menu_theme.mp3` + Procedural Fallback)**:
  - Seamless 32-second dark-fantasy orchestral & crystal-harp loop (`D Minor -> Bb Major -> G Minor -> A7`) with deep draconic bass drones, warm choir pads, crystalline elemental arpeggios, heroic horn melody, and soft ceremonial percussion.
- **`SoundManager` BGM Player & Settings Integration**:
  - Dedicated `bgm_player: AudioStreamPlayer`, `bgm_muted: bool`, and `bgm_volume_db: float` saved in `user://audio_settings.cfg`.
  - Added **`🎵 Background Music (BGM)`** mute toggle and `0%–100%` volume slider in `SoundManager.show_audio_settings_modal`.
  - Automatically plays on `MainMenu._ready()` and loops seamlessly.

---

## 4. Verification & Testing (`scripts/tests/test_runner.gd`)
- **Requirement 34a**: Verify `res://assets/audio/bgm/main_menu_theme.mp3` exists and loads into `SoundManager`, and `SoundManager` provides `bgm_player`, `play_bgm()`, `stop_bgm()`, and BGM mute/volume controls.
- **Requirement 34b**: Verify `BattleController._on_game_ended()` creates and displays `GameEndScreen` with the Victory/Defeat title, match stats, MVP Dragon `CardUI` showcase, and `Play Again` / `Return to Main Menu` buttons.
