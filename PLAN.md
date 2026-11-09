# Implementation Plan & Release Summary (`v1.14.0`)

## 1. Overview & Goals
1. **Fix Zoomed Card View Covering Opponent Avatar (`v1.14.0`)**:
   - In [`scenes/battle.tscn`](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/scenes/battle.tscn), moved `SelectedPanel` from `offset_top = 96.0` to `offset_top = 168.0`, providing 66px clearance below the `OpponentBar` avatar frame (`y = 102.0`). Set `PREVIEW_CARD_SCALE = 1.0` in [`scripts/ui/battle_controller.gd`](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/scripts/ui/battle_controller.gd) so inspected cards fit 1:1 inside the preview holder without clipping.
2. **First-Class Ability Activation UX**:
   - Replaced undiscoverable right-click-only mechanic with a prominent `[⚡ ABILITY]` button attached directly to all on-field beast card slots in `refresh_fields()`.
   - Added an interactive **Action Chooser Modal** (`open_beast_action_modal`) when left-clicking a beast that can both attack and use an ability:
     - `[ ⚔️ Attack Enemy ({atk} ATK) ]`
     - `[ ⚡ Activate Ability ({name}, Cost: {cost}) ]`
     - `[ ✖ Cancel ]`
   - Added interactive targeting mode (`current_action_mode = "targeting_ability"`) for abilities that target opposing beasts (such as Lightning Dragon's Paralysis).
   - Right-click remains functional as a quick power-user shortcut.
3. **10 New Supporter & Spell Cards**:
   - **Neutral Supporters (4)**:
     - `dragon_hoard`: Draw 3 cards, discard 1 card from hand.
     - `elemental_alchemy`: Discard 1 stone from stone pile, search deck for up to 2 stones to stone pile.
     - `draconic_resurgence`: Recycle up to 2 Dragon Beasts from discard into deck, draw 1 card.
     - `call_to_arms`: Search deck for an evolved Dragon Beast and add it to hand.
   - **Spells (6)**:
     - `elemental_transmutation`: Buff friendly beast with +2 ATK and +4 Shield HP.
     - `solar_flare`: Deal 4 direct damage to target and 2 cleave AOE damage to all other enemy beasts.
     - `static_prison`: Inflict Paralysis on target enemy beast.
     - `frost_armor`: Grant friendly beast +6 Shield HP.
     - `gale_barrier`: Return friendly beast to hand, fully healing and cleansing it.
     - `shadow_pact`: Sacrifice 1 friendly beast to draw 3 cards and gain 2 Mana.
4. **Dragon Ability Redesigns**:
   - **Fire Dragon**: On evolve: gains +3 Attack bonus on the turn it evolves (`beast.bonus_attack += 3`).
   - **Wind Dragon**: On evolve: returns 1 creature on the field back to that player's hand.
   - **Mechanical Dragon**: Passive spell immunity + activated ability: discard 1 stone from hand (or stone pile) to draw 2 cards.
   - **Ice Dragon**: On evolve: freeze 1 enemy beast for 1 turn (wears off after turn).
   - **Lightning Dragon**: Activated ability: discard 1 Lightning Stone from Stone Pile to inflict Paralysis on target enemy beast. Paralyzed beasts cannot attack. At the start of their turn, flip a coin: heads breaks free (`is_paralyzed = false`), tails remains paralyzed.

---

## 2. Automated Verification Suite (`test_runner.gd`)
- Added **Test 36 (`test_36_card_reworks_and_new_supporters_spells`)**:
  - `Requirement 36a`: Zoomed card preview panel is moved down (`offset_top >= 160`) avoiding opponent avatar profile.
  - `Requirement 36b`: Fire Dragon gains +3 Attack bonus on the turn it evolves.
  - `Requirement 36c`: Ice Dragon freezes 1 enemy beast for 1 turn upon evolving.
  - `Requirement 36d`: Glacial Freeze is temporary and wears off after 1 turn.
  - `Requirement 36e`: Mechanical Dragon has passive immunity to all Spell cards.
  - `Requirement 36f`: Spells targeting Mechanical Dragon fail due to spell immunity.
  - `Requirement 36g`: Mechanical Dragon discards 1 stone to draw 2 cards.
  - `Requirement 36h`: Lightning Dragon inflicts Paralysis and blocks target from attacking.
  - `Requirement 36i`: Paralysis cleansed on heads recovery coin toss.
  - `Requirement 36j-k`: All 10 new cards exist in `CARD_DATABASE.json` and have high-res artworks in `assets/art/`.
  - `Requirement 36l`: Dragon's Hoard spends 1 Mana, draws 3 cards and discards 1 card.
  - `Requirement 36m`: Elemental Alchemy discards 1 stone and adds 2 stones from deck to stone pile.
  - `Requirement 36n`: Draconic Resurgence recycles dragons into deck and draws 1 card.
  - `Requirement 36o`: Call to Arms adds an evolved dragon from deck to hand.
  - `Requirement 36p`: Static Prison spell inflicts Paralysis on target beast.
  - `Requirement 36q`: Frost Armor grants +6 Shield HP.
  - `Requirement 36r`: Gale Barrier returns friendly beast to hand fully cleansed.
  - `Requirement 36s`: Shadow Pact sacrifices beast and draws 3 cards.
- **Results**: **179 / 179 Tests Passed (100% Pass Rate, 0 Failures)**.

---

## 3. Releases & Artifacts
- **GitHub Repository**: [`Devarakonda-Siddhardha/Elemental-Beasts-tcg`](https://github.com/Devarakonda-Siddhardha/Elemental-Beasts-tcg)
- **`main` branch**: Commit `ad9d083` (pushed to origin)
- **`release-windows` branch**: Commit `ddafa14` ([`ElementalBeasts_Windows_x64.zip`](https://github.com/Devarakonda-Siddhardha/Elemental-Beasts-tcg/raw/release-windows/ElementalBeasts_Windows_x64.zip), 72.4 MB)
- **`release-apk` branch**: Commit `f72ceb1` ([`ElementalBeasts.apk`](https://github.com/Devarakonda-Siddhardha/Elemental-Beasts-tcg/raw/release-apk/ElementalBeasts.apk), 67.9 MB)
