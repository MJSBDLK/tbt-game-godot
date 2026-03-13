// Many more to come
ElementalType
0: Simple // like 'normal' - the default type.
+ Chivalric
+ Electric
+ Fire
+ Heraldic
+ Gentry
+ Gravity
+ Obsidian (special type)
+ Occult
+ Plant
<!-- + Plasma -->
+ Void

Move power
+ as a rough guide, use these values
- very low: 0-2
- low: 3
- mid-low: 5
- mid: 7
- mid-high: 9
- high: 11
- very high: 13
- extreme: 15
- cataclysmic: 17-20

DamageType
+ Physical
+ Special

StatusEffect
++ None
+ Burn - damage over time, reduced physical attack
+ ChainLightning - adjacent unit takes ½ damage, next adjacent takes ¼, ⅛, until damage < 1
+ Gravity - slows movement, hampers attacks
+ Herald (take extra damage from herald moves or whatever)
+ Rooted - stops movement
+ Void - locks a random move or passive per stack, up to 3 stacks

TargetType
+ Enemy
+ Ally
+ Self
+ Point
// These will be in arrays, e.g. [Enemy] = only target enemy,
// or [Ally, Self] = anyone on your team

AoE
+ 1: [[0,0]]
+ Basic AoE:
    [
                [0,1],
        [-1,0], [0,0], [1,0],
                [0,-1]
    ]
// Do we want each array to be a tuple with the relative coordinates and damage multiplier?
// How should we handle if a target lands on a diagonal?