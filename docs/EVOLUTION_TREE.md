# Dragon Evolution Tree — Elemental Beast TCG

All elemental dragons stem from the common ancestor **Little Dragon** (Cost: 2 Mana).

```mermaid
graph TD
    LD["Little Dragon [REMEMBERED]<br/>Cost: 2 Mana | HP: 8 | ATK: 3"]

    FD["Fire Dragon [PROVISIONAL]<br/>Cost: 2 Fire Stones<br/>HP: 16 | ATK: 7<br/>Ability: Flame Burst"]
    LDD["Lightning Dragon [PROVISIONAL]<br/>Cost: 2 Lightning Stones<br/>HP: 14 | ATK: 7<br/>Ability: Static Discharge"]
    SD["Shadow Dragon [CONFIRMED]<br/>Cost: 2 Shadow Stones<br/>HP: 15 | ATK: 6<br/>Ability: Cloak of Darkness (Spell Immune)"]
    WD["Wind Dragon [CONFIRMED]<br/>Cost: 2 Wind Stones<br/>HP: 14 | ATK: 5<br/>Ability: Gale Force (Double Attack)"]
    ID["Ice Dragon [PROVISIONAL]<br/>Cost: 2 Ice Stones<br/>HP: 15 | ATK: 5<br/>Ability: Glacial Frost (Freeze)"]
    MD["Mechanical Dragon [PROVISIONAL]<br/>Cost: 2 Mechanical Stones<br/>HP: 17 | ATK: 6<br/>Ability: Overclock (+3 ATK)"]
    WTD["Water Dragon [PROVISIONAL]<br/>Cost: 2 Water Stones<br/>HP: 18 | ATK: 4<br/>Ability: Tidal Restoration (Heal)"]

    LD -->|2 Fire Stones| FD
    LD -->|2 Lightning Stones| LDD
    LD -->|2 Shadow Stones| SD
    LD -->|2 Wind Stones| WD
    LD -->|2 Ice Stones| ID
    LD -->|2 Mechanical Stones| MD
    LD -->|2 Water Stones| WTD
```

## Evolution Rules Summary

1. Base Beast required on battlefield: `little_dragon`
2. No Mana is consumed during evolution; only matching Element Stones from the Stone Pile are deducted.
3. Evolution cures existing status ailments and refreshes maximum HP to the new dragon's printed value.
4. Evolved dragons immediately gain access to their printed activated and passive abilities.
