# Unit System Design Document

## Overview
This tactical RPG combines the strategic positioning and relationship systems of Fire Emblem with the type effectiveness and move customization of Pokémon. Units are highly customizable through move selection and passive abilities while maintaining the tactical depth of traditional SRPGs.

## Design Philosophy
- **Transparency over complexity**: All mechanics should be clearly visible to players
- **Meaningful choices**: Every level-up and customization option should feel impactful
- **Strategic depth**: Multiple viable approaches to unit building and team composition
- **Accessibility**: Complex systems with simple, intuitive interfaces

---

## Data Storage

### JSON-based Character Definitions
Character data is stored in JSON files for easy bulk editing and version control:
- **Location**: `/Assets/StreamingAssets/characters/`
- **Format**: One JSON file per character (e.g., `spaceman.json`, `knight.json`)
- **Loading**: JSON files are loaded at runtime into `CharacterData` objects
- **Benefits**:
  - Easy bulk editing across multiple characters
  - Clean version control diffs
  - External tool integration (spreadsheet export, validation scripts)
  - Hot reload capability during development

### Base Pool Implementation
- **Base Pool Moves/Passives**: Defined in character JSON, added to `availableMoves`/`availablePassives` at character creation
- **Always Available**: Base pool items are accessible from level 1 regardless of progression
- **Standard Allocation**: ~2 moves and ~1 passive in base pool (varies per character)

---

## Unit Data Structure

### Core Identity *(Rarely Changes)*
- **Unit Name**: Character identifier
- **Character Portrait**: Visual representation for dialogues and menus (updates with class evolution)
- **Class**: Base archetype determining available class evolution paths
- **Dual Elemental Types**: Primary and secondary type system
  - Determines weakness/resistance relationships similar to Pokémon
  - Influences move effectiveness and damage calculations
  - Secondary type can be None for single-typed units

### Progression *(Grows Over Time)*
- **Level**: Current character level (minimum: 1, all units start at level 1)
- **Experience**: Progress toward next level
- **Primary Stats**: Core attributes with growth potential
- **Available Moves**: All moves this character can potentially learn
  - Includes base pool moves (always available regardless of level)
  - Standard practice: ~2 moves in base pool at starting level
  - Can vary per character for balance/design
- **Available Passives**: All passive abilities this character can potentially learn
  - Includes base pool passives (always available regardless of level)
  - Standard practice: ~1 passive in base pool at starting level
  - Can vary per character for balance/design

### Current Loadout *(Player Customizable)*
- **Equipped Moves**: 4-slot system similar to Pokémon
  - Moves have limited uses per mission (PP-like system)
  - Function as weapons with elemental typing
- **Equipped Passives**: 4-slot system for equipped abilities
  - Includes equipment represented as passive abilities (Night Vision Goggles, etc.)
  - Can be swapped between missions

### Mission State *(Resets/Changes Per Mission)*
- **Current Health Points**: Health remaining this mission
- **Status Effects**: Temporary conditions (burn, rooted, void, etc.)
- **Currently Aiding**: Unit being carried (affects movement)

### Physical Attributes
- **Move Distance**: Base movement range in tiles
- **Constitution**: Physical build affecting rescue mechanics
- **Carry**: Constitution threshold for units this character can rescue

### Relationships
- **Support Relationships**: Bonds with other units
  - One A-support, one B-support, one C-support maximum
  - Provides combat bonuses when units are adjacent/nearby
  - Bonus effects determined by elemental type combinations

---

## Primary Stats System

### Core Stats *(From CharacterData.cs)*
- **Max Health Points**: Character's total health pool
- **Strength**: Physical attack power (for Physical damage type moves)
- **Special**: Magical/special attack power (for Special damage type moves)
- **Skill**: Hit accuracy and critical hit chance
- **Agility**: Speed/initiative and evasion chance  
- **Athleticism**: Multiple attack chance and movement efficiency
- **Defense**: Physical damage resistance
- **Resistance**: Special/magical damage resistance

### Stat Calculation Formula
```
Final Stat = Base Stat + Growth Gains + Allocated Stat Ups + Support Bonuses + Passive Bonuses + Status Modifiers
```

### Progression Mechanics
- **Growth Rates**: Percentage chance for each stat to increase on level up
- **Growth Gains**: Actual increases gained from level up RNG
- **Allocated Stat Ups**: Player-distributed points between missions
- **Stat Caps**: Class-based maximum values to prevent infinite scaling

---

## Customization Systems

### Move System *(No Equipment - Moves Only)*
- **Move Learning**: Moves unlocked at specific levels during level up
- **4-Slot Limitation**: Strategic choices about which moves to keep equipped
- **PP System**: Limited uses per mission create resource management
- **Elemental Typing**: Moves have types independent of user's type (can differ)

### Passive System *(Equipment as Passives)*
- **Passive Pool**: All learnable passive abilities per character
- **4-Slot Limitation**: Can only equip 4 passives simultaneously
- **Equipment Representation**: "Night Vision Goggles" passive instead of inventory items
- **Class-Based Access**: Each class provides unique passive library
- **Retention on Reclass**: Keep learned passives when changing classes

### Passive Characteristics
- **Persistent Effects**: Always active while equipped
- **Equipment Representation**: Items function as passive abilities
- **Conditional Triggers**: Activate under specific circumstances
- **Stacking Rules**: How multiple similar passives interact

### Passive Pool System
Each class provides access to a unique "library" of learnable passives:

**Examples by Class:**
- **Fighter**: "Heavy Armor Training", "Weapon Master", "Battle Fury", "Defensive Stance"
- **Mage**: "Mana Efficiency", "Spell Pierce", "Elemental Focus", "Counterspell"  
- **Archer**: "Eagle Eye", "Rapid Fire", "Long Shot", "Hunter's Mark"

**Mechanics:**
- Characters **retain** all learned passives when reclassing
- Characters **gain access** to new class passive pools upon reclassing
- Only **4 passives can be slotted** at once, creating strategic choices
- Encourages hybrid builds and makes reclassing strategically valuable

### Learning System
- **Level-based Acquisition**: Moves/passives unlocked at specific levels
- **Class-gated Content**: Some abilities require specific class access
- **Balanced Rewards**: Each level grants either:
  - New move access
  - New passive access
  - Allocation point for stats

---

## Combat Mechanics

### Type Effectiveness *(Dual Type System)*
- **Super Effective**: 2x damage
- **Not Very Effective**: 0.5x damage
- **Normal**: 1x damage
- **Dual Type Interaction**: Both defending types considered, effectiveness combined

### Damage Calculation *(Current Implementation)* 
```
Attack Stat = Physical moves use Strength, Special moves use Special
Defense Stat = Physical moves vs Defense, Special moves vs Resistance
Base Damage = (Move Power × Attack Stat ÷ 5) - Defense Stat
Final Damage = Base Damage × Type Effectiveness × Other Modifiers
Minimum Damage = 1 (always deal at least 1 damage)
```

### Support Bonuses
- **Adjacent Allies**: Small stat bonuses based on elemental type synergy
- **Support Rank**: Bonus magnitude based on relationship level
- **Type Combinations**: Different elemental pairings provide unique effects
  - Fire + Electric: Offensive bonuses (explosive synergy)  
  - Plant + Gravity: Movement bonuses (complementary elements)
  - Void + Occult: Special attack bonuses (dark synergy)
- **Formation Strategy**: Encourages tactical positioning for optimal bonuses

---

## Implementation Priorities

### Phase 1 (Current): Basic Combat
- Health Points, Strength, Defense stats functional
- Type effectiveness system working
- Move-based attacks with PP consumption

### Phase 2: Enhanced Stats
- Full 8-stat system integration
- Allocation point distribution UI
- Stat display and growth feedback

### Phase 3: Dual Type System
- Primary + Secondary elemental types
- Complex type effectiveness calculations
- Dual-type move interactions

### Phase 4: Move System Completion
- 4-slot move selection UI
- Move learning progression at level up
- Range and area-of-effect implementation

### Phase 5: Passive System
- 4-slot passive selection interface
- Passive learning and class-based pools
- Equipment-as-passives implementation

### Phase 6: Advanced Features
- Class evolution trees
- Support relationship system
- Status effects integration with all systems

---

## Design Decisions & Rationale

### Why Moves Replace Weapons?
- **Customization**: More flexible than fixed weapon types
- **Type System**: Enables Pokémon-style effectiveness
- **Progression**: Moves can be learned and upgraded over time
- **Balance**: Usage limits prevent overpowered strategies

### Why Fire Emblem Growth Rates?
- **Familiar System**: Proven mechanics from successful SRPGs
- **Exciting Level-ups**: Each level has potential for multiple stat gains
- **Natural Variation**: Characters develop uniquely even within same class
- **No Grinding**: Can't manipulate stats through repetitive actions
- **Clear Progression**: Transparent percentage chances for each stat gain

### Why Transparent Allocation Point System?
- **Player Agency**: Clear choices rather than hidden mechanics
- **Flexibility**: Respec system allows experimentation between missions
- **Accessibility**: No complex breeding or grinding requirements
- **Strategic Depth**: Still allows min-maxing for dedicated players

### Why Equipment as Passives?
- **Unified System**: Single customization interface
- **Flexibility**: Equipment effects can be as complex as needed
- **Balance**: Limited slots prevent overpowered combinations
- **Clarity**: All character modifications in one place
- **No Inventory**: Streamlined UI without complex item management

---

## Future Considerations

### Potential Expansions
- **Dual-type move system**: Moves with two elemental types
- **Terrain interactions**: Environmental bonuses for specific types
- **Weather effects**: Environmental impact on types/moves
- **Evolution bonuses**: Temporary powerful transformations during combat
- **Multi-target moves**: Area-of-effect abilities (future implementation)

### Technical Requirements
- **Save system**: Persistent character progression data
- **UI framework**: Complex stat and move displays
- **Animation system**: Move effects and class evolution transformations
- **Balance tools**: Easy tweaking of stats and effectiveness values

### Localization Notes
- **Stat names**: Current implementation uses clear English terms
- **Move descriptions**: Clear, concise ability explanations needed
- **Type names**: Memorable and thematic elemental categories established
- **Passive names**: Equipment-style naming for clarity ("Night Vision Goggles")