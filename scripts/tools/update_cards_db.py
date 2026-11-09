import json

def update_db():
    with open('data/CARD_DATABASE.json', 'r') as f:
        data = json.load(f)
        
    cards = data['cards']
    card_map = {c['id']: c for c in cards}
    
    # 1. Update 5 Dragons
    if 'fire_dragon' in card_map:
        c = card_map['fire_dragon']
        c['ability'] = {
            "name": "Dragonfire Surge",
            "description": "When evolved: Gains +3 Attack on the turn it evolves (unleashes more damage).",
            "trigger": "on_evolve",
            "effect": "bonus_attack_on_evolve",
            "bonus_attack": 3
        }
        c['description'] = "When evolved: Gains +3 Attack on the turn it evolves."
        
    if 'wind_dragon' in card_map:
        c = card_map['wind_dragon']
        c['ability'] = {
            "name": "Gale Recoil",
            "description": "When evolved: Returns one creature on the field back to that player's hand.",
            "trigger": "on_evolve",
            "effect": "bounce_creature_on_evolve"
        }
        c['description'] = "When evolved: Returns one creature on the field back to that player's hand."
        
    if 'mechanical_dragon' in card_map:
        c = card_map['mechanical_dragon']
        c['ability'] = {
            "name": "Overclock Draw",
            "description": "Discard 1 Stone from hand (or Stone Pile) to draw 2 cards. Passive: Immune to Spells.",
            "trigger": "activated",
            "cost": {"any_stone": 1},
            "effect": "discard_stone_draw_two",
            "spell_immunity": True
        }
        c['description'] = "Discard 1 Stone to draw 2 cards. Immune to Spells."
        
    if 'ice_dragon' in card_map:
        c = card_map['ice_dragon']
        c['ability'] = {
            "name": "Glacial Freeze",
            "description": "When evolved: Freeze one enemy beast. (Freeze is temporary and wears off after 1 turn).",
            "trigger": "on_evolve",
            "effect": "freeze_enemy_on_evolve",
            "freeze_turns": 1
        }
        c['description'] = "When evolved: Freeze one enemy beast (1 turn)."
        
    if 'lightning_dragon' in card_map:
        c = card_map['lightning_dragon']
        c['ability'] = {
            "name": "Paralysis",
            "description": "Discard 1 Lightning Stone from the Stone Pile: Inflict Paralysis on target enemy beast (must flip heads at turn start to break free).",
            "trigger": "activated",
            "cost": {"lightning": 1},
            "effect": "inflict_paralysis"
        }
        c['description'] = "Discard 1 Lightning Stone: Inflict Paralysis on target enemy beast."

    # 2. Add 10 new cards
    new_cards = [
        {
            "id": "dragon_hoard",
            "name": "Dragon's Hoard",
            "card_type": "support",
            "sub_type": "item",
            "element": "neutral",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Draw 3 cards from your deck, then discard 1 card from your hand.",
            "ability": {
                "name": "Dragon's Hoard",
                "effect": "draw_three_discard_one"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "elemental_alchemy",
            "name": "Elemental Alchemy",
            "card_type": "support",
            "sub_type": "item",
            "element": "neutral",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Discard 1 Element Stone from your Stone Pile: Search your deck for 2 Element Stones and add them to your Stone Pile.",
            "ability": {
                "name": "Elemental Alchemy",
                "effect": "transmute_stones"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "draconic_resurgence",
            "name": "Draconic Resurgence",
            "card_type": "support",
            "sub_type": "item",
            "element": "neutral",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Shuffle up to 2 Dragon Beast cards from your discard pile into your deck, then draw 1 card.",
            "ability": {
                "name": "Draconic Resurgence",
                "effect": "recycle_dragons"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "call_to_arms",
            "name": "Dragon Call to Arms",
            "card_type": "support",
            "sub_type": "item",
            "element": "neutral",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Search your deck for any Stage 1 Evolved Dragon Beast and add it to your hand.",
            "ability": {
                "name": "Dragon Call to Arms",
                "effect": "search_evolved_dragon"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "elemental_transmutation",
            "name": "Elemental Transmutation",
            "card_type": "spell",
            "sub_type": "buff_spell",
            "element": "neutral",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Target friendly beast gains +2 Attack and +4 Shield HP this turn.",
            "ability": {
                "name": "Elemental Transmutation",
                "effect": "buff_attack_shield",
                "bonus_attack": 2,
                "bonus_shield": 4
            },
            "status": "CONFIRMED"
        },
        {
            "id": "solar_flare",
            "name": "Solar Flare",
            "card_type": "spell",
            "sub_type": "combat_spell",
            "element": "fire",
            "mana_cost": 2,
            "stone_cost": {},
            "description": "Deal 4 damage to target enemy beast and 2 damage to all other enemy beasts.",
            "ability": {
                "name": "Solar Flare",
                "effect": "cleave_damage",
                "damage": 4,
                "aoe_damage": 2
            },
            "status": "CONFIRMED"
        },
        {
            "id": "static_prison",
            "name": "Static Prison",
            "card_type": "spell",
            "sub_type": "control_spell",
            "element": "lightning",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Inflict Paralysis on target enemy beast (must flip heads at turn start to break free).",
            "ability": {
                "name": "Static Prison",
                "effect": "inflict_paralysis"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "frost_armor",
            "name": "Frost Armor",
            "card_type": "spell",
            "sub_type": "defense_spell",
            "element": "ice",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Target friendly beast gains +6 Shield HP. If damaged this turn, freezes the attacker for 1 turn.",
            "ability": {
                "name": "Frost Armor",
                "effect": "frost_armor",
                "bonus_shield": 6
            },
            "status": "CONFIRMED"
        },
        {
            "id": "gale_barrier",
            "name": "Gale Barrier",
            "card_type": "spell",
            "sub_type": "utility_spell",
            "element": "wind",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Return 1 friendly beast on your field to your hand (cleansing all status ailments and restoring its HP).",
            "ability": {
                "name": "Gale Barrier",
                "effect": "bounce_friendly_beast"
            },
            "status": "CONFIRMED"
        },
        {
            "id": "shadow_pact",
            "name": "Shadow Pact",
            "card_type": "spell",
            "sub_type": "utility_spell",
            "element": "shadow",
            "mana_cost": 1,
            "stone_cost": {},
            "description": "Sacrifice 1 friendly beast on your field: Draw 3 cards and gain +2 Mana this turn.",
            "ability": {
                "name": "Shadow Pact",
                "effect": "sacrifice_beast_draw_mana"
            },
            "status": "CONFIRMED"
        }
    ]
    
    # Avoid duplicate additions
    for nc in new_cards:
        if nc['id'] not in card_map:
            cards.append(nc)
            print(f"Added card {nc['id']}")
        else:
            # Update existing
            for i, existing in enumerate(cards):
                if existing['id'] == nc['id']:
                    cards[i] = nc
            print(f"Updated card {nc['id']}")
            
    with open('data/CARD_DATABASE.json', 'w') as f:
        json.dump(data, f, indent=2)
    print("CARD_DATABASE.json updated successfully!")

if __name__ == '__main__':
    update_db()
