# Changelog — Elemental Beasts TCG

All notable changes and architectural milestones in the reconstruction of Elemental Beasts TCG are documented here.

## [1.0.0] - 2026-11-06

### Environment & Toolchain
- Installed Godot Engine 4.3 stable official Linux x86_64 binary in `/home/antigravity/bin/godot`.
- Configured PATH and `GODOT_PATH` environment variables in user profile.
- Installed `@coding-solo/godot-mcp` MCP server globally in user space (`/home/antigravity/.npm-global/bin/godot-mcp`).
- Verified MCP server stdio JSON-RPC handshake and 14 tools (`run_project`, `create_scene`, `add_node`, etc.).

### Historical Data & Documentation
- Published `data/CARD_DATABASE.json` containing authentic transcriptions of all confirmed original cards, remembered creator rules, and provisional placeholders.
- Published `data/ELEMENT_DATABASE.json` with elemental color schemes, themes, and identity descriptions.
- Published `data/default_decks.json` containing 3 preconstructed decks ("Spark & Shadow Strike", "Volcanic Tempest", "Techno Glacial Core").
- Created `docs/ORIGINAL_CARD_ARCHIVE.md`, `docs/RECONSTRUCTED_RULEBOOK.md`, `docs/EVOLUTION_TREE.md`, `docs/FUSION_CHART.md`, and `docs/RECONSTRUCTION_ASSUMPTIONS.md`.

### Core Game Engines (GDScript)
- Implemented `rules_config.gd` providing fully customizable gameplay constants (Mana refresh, starting HP, stone rate, sickness).
- Implemented `card_data.gd` providing robust typed card representations and resource mappings.
- Implemented `mana_manager.gd` enforcing the exact 5-mana replenishment per turn with zero rollover.
- Implemented `stone_manager.gd` maintaining independent element stone piles and discards.
- Implemented `evolution_engine.gd` handling Little Dragon transformations and stone cost deductions.
- Implemented `fusion_engine.gd` executing 2-dragon battlefield fusions and material stacking.
- Implemented `ability_resolver.gd` resolving Cloak of Darkness, Gale Force, Volcanic Storm, Frosting Draw, and Wraith Surge.
- Implemented `combat_engine.gd` resolving attacks, defender trades, direct damage, and board state cleanup.
- Implemented `status_manager.gd` handling Stun, Freeze, and Spell Immunity.
- Implemented `ai_controller.gd` providing an offline rule-based AI capable of mana spending, stone collection, evolution, fusion, and tactical attacks.

### Verification & Testing
- Built automated test suite `scripts/tests/test_runner.gd` executed via `godot --headless -s` verifying all 18 mandatory requirements from Master Prompt section 9.
