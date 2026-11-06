# Elemental Beasts TCG — Legacy Reborn

Reconstruction of the original 2024–2025 **Elemental Beast TCG** as a fully playable digital card game built with **Godot 4.3** and **GDScript**.

Featuring the authentic **dual-resource economy** (5-Mana fixed turn refresh + independent Element Stone Pile), **Little Dragon evolution**, and **high-impact elemental fusion**.

---

## Key Features

1. **Dual Resource Engine**:
   - **Mana**: Exactly 5 Mana replenished at the start of every turn. No ramp, no carryover. Little Dragon costs 2 Mana.
   - **Element Stone Pile**: Separate elemental resource pool (Fire, Lightning, Shadow, Wind, Ice, Mechanical, Water) used for evolutions and abilities.
2. **Dragon Evolution**:
   - Every evolutionary path originates from **Little Dragon**.
   - Pay matching stones from your Stone Pile (e.g. 2 Shadow Stones for Shadow Dragon, 2 Wind Stones for Wind Dragon) to evolve directly on the battlefield.
3. **Elemental Fusion**:
   - Merge two eligible dragons from the battlefield into an apex Hybrid Dragon (e.g. Fire + Lightning → **VolcoVolt Dragon**, Shadow + Lightning → **Spark Wraith Dragon**, Ice + Mechanical → **Techno Frost Dragon**).
4. **Authentic Abilities**:
   - **Cloak of Darkness** (Shadow Dragon): Full immunity to Spell cards.
   - **Gale Force** (Wind Dragon): Discard 1 Stone from Stone Pile to attack twice this turn.
   - **Volcanic Storm** (VolcoVolt Dragon): Discard 1 Fire + 1 Lightning Stone to deal 8 damage to two different targets and apply Stun.
   - **Frosting Draw** (Techno Frost Dragon): Discard 1 Ice + 1 Mechanical Stone to freeze all opposing beasts and draw 1 card per frozen beast.
   - **Stone Seeker** (Compass): Search deck for an Element Stone card.
5. **Multiple Game Modes**:
   - Single Player vs Offline AI
   - Local 2-Player Hotseat
   - Deck Builder & Card Collection Viewer
   - Automated Headless Verification Suite
6. **Godot MCP Integration**:
   - Pre-installed and configured with `@coding-solo/godot-mcp` for agentic AI editor and runtime control.

---

## Quick Start

### Running Automated Test Suite
Verify all 18 core requirements in headless mode:
```bash
godot --headless --path . -s res://scripts/tests/test_runner.gd
```

### Launching the Game
```bash
godot --path .
```

### Godot MCP Configuration
The environment has `@coding-solo/godot-mcp` installed globally. To connect an MCP client (Cursor, Claude Code, Cline):
```json
{
  "mcpServers": {
    "godot": {
      "command": "godot-mcp",
      "args": [],
      "env": {
        "GODOT_PATH": "/home/antigravity/bin/godot"
      }
    }
  }
}
```

---

## Documentation Links

- [Original Card Archive](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/docs/ORIGINAL_CARD_ARCHIVE.md)
- [Reconstructed Rulebook](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/docs/RECONSTRUCTED_RULEBOOK.md)
- [Evolution Tree](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/docs/EVOLUTION_TREE.md)
- [Fusion Chart](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/docs/FUSION_CHART.md)
- [Reconstruction Assumptions](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/docs/RECONSTRUCTION_ASSUMPTIONS.md)
- [Card Database (JSON)](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/data/CARD_DATABASE.json)
- [Element Database (JSON)](file:///home/antigravity/Devarakonda-Siddhardha/Elemental-Beasts-tcg/data/ELEMENT_DATABASE.json)
