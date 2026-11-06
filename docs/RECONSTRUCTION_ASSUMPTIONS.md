# Reconstruction Assumptions & Methodology

To faithfully reconstruct the 2024–2025 Elemental Beast TCG without adulterating verified rules or hallucinating non-existent mechanics, every gameplay parameter is strictly divided into three tiers of historical fidelity.

---

## Tier 1: Confirmed Rules & Cards [CONFIRMED]
These rules are directly visible from authentic original physical cards or transcribed records:
1. **Shadow Dragon**: 2 Shadow Stones evolution, 15 HP, 6 ATK, "Cloak of Darkness" (Immune to all Spell cards).
2. **Wind Dragon**: 2 Wind Stones evolution, 14 HP, 5 ATK, "Gale Force" (Discard 1 Stone from Stone Pile to attack twice this turn).
3. **VolcoVolt Dragon**: Fusion of Fire Dragon + Lightning Dragon, 30 HP, 15 ATK, "Volcanic Storm" (Discard 1 Fire Stone + 1 Lightning Stone: Deal 8 damage to two different opposing creatures and apply Stun).
4. **Spark Wraith Dragon**: Fusion of Shadow Dragon + Lightning Dragon, 27 HP, 13 ATK, Ability: Discard 1 Shadow Stone + 1 Lightning Stone to recover 2 Spell cards from discard pile (Lightning Spells cast free).
5. **Techno Frost Dragon**: Fusion of Ice Dragon + Mechanical Dragon, 27 HP, 11 ATK, "Frosting Draw" (Discard 1 Ice Stone + 1 Mechanical Stone: Freeze all opposing Beasts; draw 1 card per beast frozen).
6. **Compass**: Support card, printed cost 2, searches deck for an Element Stone and adds to hand.
7. **Confirmed Elements**: Fire, Lightning, Shadow, Wind, Ice, Mechanical.

---

## Tier 2: Creator Recollections [REMEMBERED]
These elements were explicitly remembered and articulated by the original creator:
1. **Dual Resource Division**: Mana and Element Stones are completely independent resource systems.
2. **5 Mana Every Turn**: Each player receives 5 Mana at the beginning of each turn; unspent Mana does not carry over; Mana does not ramp automatically per turn.
3. **Little Dragon 2 Mana**: Little Dragon costs exactly 2 Mana to summon from hand.
4. **Evolution Process**: Little Dragons on the field are evolved into elemental dragons by paying matching Element Stones from the Stone Pile.
5. **Fusion Materials on Field**: The two component elemental dragons must be on the battlefield to execute a fusion.

---

## Tier 3: Provisional Gameplay Glue [PROVISIONAL]
These parameters were introduced to make the digital reconstruction playable as a complete, competitive video game. All of these values are isolated in `res://scripts/core/rules_config.gd` so they can be adjusted as further authentic materials emerge:
1. **Stone Placement Rate**: 1 Element Stone card played from hand into Stone Pile per turn.
2. **Compass Cost**: The printed cost 2 is provisionally treated as 2 Mana.
3. **Player Life Total**: 30 HP per player.
4. **Deck Size**: Standard 30-card deck (allows fast cycling and reliable stone/evolution access).
5. **Hand Sizes**: Starting hand of 5 cards, maximum hand size of 7 cards.
6. **Battlefield Capacity**: Up to 4 active dragons per player on the field simultaneously.
7. **Summoning Sickness**: Dragons cannot attack on the turn they enter the battlefield or evolve unless granted haste (toggleable).
8. **Direct Attack Rule**: Attacking beasts may strike the opposing player directly only if the opponent controls no active beasts on the battlefield.
9. **Status Duration**: Stun and Freeze last until the end of the affected player's next turn.
10. **Placeholder Elemental Dragons**: Fire Dragon, Lightning Dragon, Ice Dragon, Mechanical Dragon, and Water Dragon are provided with balanced placeholder stats to make all three confirmed fusions fully testable.
