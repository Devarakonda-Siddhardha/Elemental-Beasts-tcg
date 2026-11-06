# Reconstructed Rulebook — Elemental Beast TCG

## 1. Core Philosophy

Elemental Beast TCG is an original fantasy trading card game built upon a **dual-resource system**, **Little Dragon evolution**, and **high-impact elemental fusion**. Unlike traditional TCGs with escalating mana ramps or single-pool energy systems, Elemental Beast TCG operates with fixed tactical turn mana combined with strategic elemental stone stockpiling.

---

## 2. Resource Architecture

### A. Mana System [REMEMBERED]
- **Base Mana**: Every player receives **5 Mana** at the beginning of every turn.
- **Refresh Rule**: Mana refreshes directly to 5 at the start of each player's turn.
- **No Ramp**: Mana does not increase automatically with turn count (Turn 1 has 5 Mana, Turn 10 has 5 Mana).
- **No Rollover**: Unspent Mana is lost at the end of the turn; it never carries over.
- **Usage**: Mana pays for summoning **Little Dragon** (2 Mana each), casting Spell cards, and using Support items.
- *Configurability*: The 5-Mana turn refresh is fully configurable in `res://scripts/core/rules_config.gd` to test rule variations.

### B. Element Stone Pile [CONFIRMED / REMEMBERED]
- **Separation**: Element Stones are entirely distinct from Mana. They do not spend Mana and cannot pay Mana costs.
- **Stockpile Zone**: Each player possesses a dedicated **Stone Pile** separate from their battlefield and hand.
- **Confirmed Elements**:
  1. Fire
  2. Lightning
  3. Shadow
  4. Wind
  5. Ice
  6. Mechanical
  7. Water *(Provisional)*
- **Placement [PROVISIONAL]**: In the standard ruleset, a player may play **1 Element Stone card per turn** from their hand into their Stone Pile at 0 Mana cost.
- **Stone Consumption**:
  - Evolving a Little Dragon requires spending/discarding matching stones from the Stone Pile.
  - Activating dragon abilities often discards 1 or more specific stones from the Stone Pile.
  - Paying fusion ability costs consumes matching elemental stones.
- **Discard Zone**: Expended or discarded stones go to the **Stone Discard** area.

---

## 3. Dragon Evolution [CONFIRMED / REMEMBERED]

The quintessential mechanic of the game is the transformation of the base Little Dragon into specialized elemental apex dragons.

### Evolution Step-by-Step
1. **Summon Base Form**: Player spends 2 Mana to summon Little Dragon to the battlefield.
2. **Collect Stones**: Player stockpiles the required element stones in their Stone Pile over turns.
3. **Initiate Evolution**: With Little Dragon on field and the evolution card in hand, player targets Little Dragon.
4. **Pay Stones**: The game validates the Stone Pile. For example:
   - **Shadow Dragon**: 2 Shadow Stones
   - **Wind Dragon**: 2 Wind Stones
   - **Fire Dragon**: 2 Fire Stones
   - **Lightning Dragon**: 2 Lightning Stones
   - **Ice Dragon**: 2 Ice Stones
   - **Mechanical Dragon**: 2 Mechanical Stones
5. **Transformation**: The stones leave the Stone Pile. Little Dragon evolves into the target dragon, inheriting its full printed stats, HP, Attack, and abilities.

---

## 4. Elemental Fusion [CONFIRMED]

Two compatible elemental dragons on the battlefield may merge into an extraordinary Hybrid Fusion Dragon.

### Fusion Step-by-Step
1. **Board Materials**: The player must have **both** required elemental dragons actively on their battlefield (e.g. Fire Dragon + Lightning Dragon).
2. **Initiate Fusion**: Player plays the Fusion Dragon card from hand targeting the two material dragons.
3. **Fusion Resolution**:
   - Both material dragons are merged beneath the new Fusion card as attached materials.
   - The Fusion Dragon appears on the battlefield with its colossal HP and Attack.
   - No extra Mana cost is required for the baseline fusion.

### Confirmed Fusions
- **VolcoVolt Dragon**: Fire Dragon + Lightning Dragon (30 HP / 15 ATK)
- **Spark Wraith Dragon**: Shadow Dragon + Lightning Dragon (27 HP / 13 ATK)
- **Techno Frost Dragon**: Ice Dragon + Mechanical Dragon (27 HP / 11 ATK)

---

## 5. Turn Structure [PROVISIONAL]

Each player's turn consists of 4 distinct phases:

1. **Start Phase**:
   - Mana refreshes to 5.
   - Stone placement allowance resets to 1.
   - Status effects decrement (Stun, Freeze duration reduced).
   - "Attacks used this turn" counters reset to 0.
2. **Draw Phase**:
   - Active player draws 1 card from deck (draw-out loss if deck is empty).
3. **Action Phase** (Free order):
   - Spend Mana to summon Little Dragons or cast Spells.
   - Play up to 1 Element Stone card into Stone Pile.
   - Pay stones to evolve eligible Little Dragons.
   - Fuse compatible elemental dragons.
   - Activate dragon special abilities by paying required stones.
   - Declare attacks with ready dragons against enemy dragons (or direct attack if opponent field is empty).
4. **End Phase**:
   - Unspent Mana clears to 0.
   - Hand size check (discard down to maximum 7 if exceeded).
   - Turn passes to the opposing player.

---

## 6. Status Effects [PROVISIONAL]

- **Stun**: The affected beast cannot declare attacks or activate its special abilities until the end of its controller's next turn.
- **Freeze**: The affected beast is locked in ice and cannot declare attacks until the end of its controller's next turn.
- **Spell Immunity (Passive)**: The beast cannot be targeted or affected by Spell cards.
