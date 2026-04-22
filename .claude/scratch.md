CharacterSheet (PanelContainer, 640x360)
 └─ MainRow (HBoxContainer, separation: 12)
     ├─ LeftColumn (VBoxContainer, separation: 4, min_width: 96)
     │   ├─ Portrait (TextureRect, 96x96, expand: ignore size, stretch: keep aspect covered)
     │   ├─ TypeLabel (Label, 5px font)
     │   ├─ ClassLabel (Label, 5px font)
     │   ├─ SpecLabel (Label, 5px font)
     │   ├─ ConLabel (Label, 5px font)
     │   ├─ CarLabel (Label, 5px font)
     │   └─ Spacer (Control, v_size_flags: expand+fill)
     │
     └─ RightColumn (VBoxContainer, separation: 3, h_size_flags: expand+fill)
         ├─ NameRow (HBoxContainer, separation: 8)
         │   ├─ NameLabel (Label, 11px font)
         │   ├─ LevelLabel (Label, 8px font)
         │   └─ XPLabel (Label, 5px font, v_size_flags: shrink end)
         ├─ Separator (ColorRect, min_height: 1)
         ├─ HPSection (Control, min_height: 10)
         │   ├─ HPBarBG (ColorRect, 400x6)
         │   └─ HPBarFill (ColorRect, 400x6)
         ├─ HPLabel (Label, 5px font)
         ├─ Separator
         ├─ StatsRow (HBoxContainer, separation: 16)
         │   ├─ LeftStats (VBoxContainer, separation: 2)
         │   │   ├─ STR row (HBox: NameLabel 28px + ValueLabel 42px + BarContainer 80x8)
         │   │   ├─ SPE row
         │   │   ├─ SKL row
         │   │   └─ ATH row
         │   └─ RightStats (VBoxContainer, separation: 2)
         │       ├─ DEF row
         │       ├─ RES row
         │       └─ AGI row
         ├─ Separator
         ├─ "EQUIPPED MOVES" (Label, 5px)
         ├─ Move1Label (Label, 5px)
         ├─ Move2Label (Label, 5px)
         ├─ Move3Label (Label, 5px)
         ├─ Move4Label (Label, 5px)
         ├─ Separator
         ├─ "EQUIPPED PASSIVES" (Label, 5px)
         └─ PassivesLabel (Label, 5px, autowrap)

StatBarContainer (Control, min height: 8px)
 ├─ BarBackground (ColorRect, 2px tall, dark gray, full width = cap)
 ├─ BarGlow (ColorRect, 6px tall, centered vertically, fill width, color @ ~25% alpha)
 └─ BarFill (ColorRect, 2px tall, centered vertically, fill width, solid color)

StatRow (HBoxContainer, separation: 4)
 ├─ StatName (Label, min_width: 28, text: "STR")
 ├─ StatValue (Label, min_width: 42)
 └─ BarContainer (Control, min_size: 80x8)
     ├─ BarBG (ColorRect, 80x4, pos: 0,2, color: dark)
     └─ BarFill (ColorRect, 0x4, pos: 0,2, color: player blue)

Stat	Base	Cap

Stat    Base+Growth    Bonus    Total    Cap    Base px    Bonus px    Bonus x
HP      29             +2       31       60     21         3           20
STR     10             +1       11       25     7          3           6
SPC     6              0        6        25     4          —           —
SKL     9              +2       11       30     7          3           6
AGI     8              0        8        30     6          —           —
ATH     8              +1       9        30     6          3           5
DEF     5              0        5        25     4          —           —
RES     4              0        4        25     3          —           —

Also: CON 5, CAR 8, Move Distance 3.

Health bar colors (parametric 0.85):
#6e150d, #8e371e, #a7532d, #c17b3e, #dca452, #f4cc65, #d3cc72, #afcb80, #8cc991, #6dcbac, #45cbce

Q1. Element → injury map. Listed as minor (major)
Element	    DamageType      Injury	        Penalty
Fire	    Phys/Spc        Burn Scar	    -STR
Cold	    Phys/Spc        Frostbite	    -AGL
Electric	Phys/Spc        Nerve Damage	-SKL
Plant	    Physical        Contusion	    -ATH
Plant	    Special         Infection	    -RES
Air	        Phys/Spc        Concussion	    -SKL
Gravity	    Phys/Spc        Broken Bone 	-1 (2) Move [down to a minimum of 1]
Void	    Phys/Spc        Bends   	    1 (2) random move or passive locked each turn
Occult	    Phys/Spc        Curse	        -10 (20)% LUCK (affects all dice rolls)
Chivalric	Phys/Spc        Wound   	    -20 (40)% maxHP
Heraldic	Physical        Trauma     	    -DEF
Heraldic	Special         PTSD     	    6.25 (12.5)% chance to not act (flee) each turn after the first
Gentry	    Physical        Wound	        -20 (40)% maxHP
Gentry	    Special         Corruption	    6.25 (12.5)% chance to change to enemy faction for the turn, each turn after the first
Robo	    Physical        Laceration 	    -Healing effects reduced by 25 (50)% down to a minimum of 1 [max 99% reduction from all sources]
Robo	    Special         Hypoesthesia    -Hides health bar if health over 50 (0)%
Simple	    Physical        Trauma	        -DEF
Simple	    Special         Amnesia	        -SPC
Obsidian	Physical        Crystallization -Removes primary (and secondary) elemental type (this might be a positive and that's fine!)
Obsidian	Special         Corruption   	6.25 (12.5)% chance to change to enemy faction for the turn, each turn after the first

character sprite indices
9: ogre
2: ernesto
8: blood mage
4: gravcap
6: elfpirate
7: napdawg
5: maam
0: grasker
1: spaceman
3: orcpage