export const gravityCaptain = {
	characterId: "gravityCaptain",
	name: null,

	narrativeProfile: {
		age: '???',  // Unknown - possibly ancient, possibly ageless, possibly irrelevant
		overview: `
			The Gravity Captain is one of the last living masters of gravitational magic.
			He's a fragile, ancient scholar who has sacrificed his body for ultimate magical power.

			His role: The squad's strategic anchor - controls battlefields through gravity manipulation.
			Commands respect through sheer magical power despite his physical frailty.

			What makes him tick: The pursuit of perfect understanding of gravitational forces.
			What he cares about: Protecting his knowledge, ensuring gravity magic doesn't die with him.
			What would devastate him: Being rendered helpless, unable to protect others with his power.

			What makes him different: He's a pure glass cannon - devastating offense, zero defense.
			Most mages balance power with survivability. He went all-in on destructive capability.
			Lives on the edge of death constantly, compensating with incredible tactical awareness.
		`,

		personality: `
			Mysterious and fundamentally inhuman. His behavior doesn't follow human logic or emotional patterns.
			The helmet with too many eyes looking in different directions gives him an unnerving, alien presence.

			Can only communicate with robotic characters - whatever language/method he uses is incompatible with organic minds.
			When his words are translated by robotic squad members, they're often prescient but bizarrely off-topic.
			Might warn about "the weight of seventeen falling stars" when discussing tactics, yet somehow it proves relevant later.

			Under pressure: Becomes perfectly still, with all those eyes tracking different targets simultaneously.
			His calmness isn't human composure - it's something else entirely. No fear response recognizable to humans.

			Doesn't have human emotions - or if he does, they manifest in incomprehensible ways.
			No distinction between strangers and friends from an observable perspective.

			The squad has learned to trust his combat calls even when they make no immediate sense.
			His gravitational predictions are always correct, even if the reasoning is unknowable.

			Is he a robot? An alien organism in a suit? Something else entirely? No one knows, and he offers no answers.
		`,

		motivation: `
			What drives this character?
			What do they want more than anything?
			What are they afraid of?
			What would make them break their principles?
			What keeps them going when things get tough?
		`,

		characterArc: `
			Where do they start emotionally/mentally?
			Where do they end up?
			What's the journey between those two points?
			What key moments change them?
			Do they succeed in their growth or fail?
			What do they learn about themselves?
		`,

		backstory: `
			Where did they come from?
			What are their formative experiences?
			Why are they the way they are?
			What's their family situation?
			What's their biggest regret from their past?
			What's a memory that shaped who they are today?
		`
	},

	characterDepth: {
		coreContradiction: `
			What contradictions make them interesting?
			What do they say vs what do they do?
			What mask do they wear vs who they really are?
			What strength is also their weakness?
		`,

		wantVsNeed: {
			wants: `
				What does the character THINK they want?
				What are they actively pursuing?
			`,
			needs: `
				What does the character ACTUALLY need (even if they don't realize it)?
				What would truly make them whole/happy/fulfilled?
			`
		},

		flaws: [
			`What character flaws hold them back?
			What mistakes do they keep making?
			What blind spots do they have?
			How do they self-sabotage?
			What do they refuse to acknowledge about themselves?`
		],

		strengths: [
			`What are they genuinely good at?
			What positive qualities do they possess?
			What would their friends say they're best at?
			When do they shine?
			What makes them a valuable member of the team?`
		],

		fears: `
			What keeps them up at night?
			What would break them?
			What do they avoid at all costs?
			What's their worst nightmare scenario?
		`
	},

	characterGrowth: {
		growthTriggers: [
			`What events force them to change?
			What realizations do they have?
			Who challenges their worldview?
			What failure teaches them something important?
			What success shows them they're capable of more?`
		],

		progressionBeats: {
			earlyGame: `
				How do they act at the beginning?
				What's their role in the early story?
				What first impressions do they give?
			`,
			midGame: `
				How are they changing?
				What challenges are they facing?
				Are they resisting growth or embracing it?
				Do they take steps forward then backward?
			`,
			lateGame: `
				Who have they become by the end?
				What's different about them?
				What stays the same?
				Have they achieved their arc or failed?
				How do they view their earlier self?
			`
		}
	},

	worldConnection: {
		stanceOnConflict: `
			How do they relate to the larger conflict?
			What side are they on and why?
			Do they care about the big picture or just personal stakes?
			How did the conflict affect them personally?
			What would it take for them to switch sides or give up?
		`,

		nonCombatSkills: [
			`What are they good at outside of fighting?
			What hobbies or talents do they have?
			What surprising skill do they possess?
			What could they do if they weren't a soldier/fighter?`
		],

		quirks: [
			`What physical mannerisms do they have?
			What nervous habits do they display?
			What small details make them memorable?
			What do they do when thinking/stressed/happy?
			What's a weird habit that annoys their teammates?`
		]
	},

	perception: {
		selfPerception: `
			How do they see themselves?
			What do they believe about their own worth/abilities?
			Are they self-aware or delusional?
			What lie do they tell themselves?
		`,

		othersPerception: `
			How do others see them?
			What's their reputation?
			What do people assume about them?
			What do teammates say behind their back?
		`,

		reality: `
			What's the truth about this character?
			What will the player discover over time?
			What's hidden beneath the surface?
			What surprise does this character have in store?
		`
	},

	relationships: [
		{
			characterName: "Ernesto",
			relationshipType: "squad_member",
			dynamic: `
				How do these two characters interact?
				What's the nature of their relationship?
				What do they like about each other?
				What drives them crazy about each other?
				How has the relationship evolved?
				What would it take to break this relationship?
				What would they do for each other?
				What won't they do for each other?
			`
		}
	],

	combatProfile: {
		fightingStyle: `
			The Gravity Captain is a methodical, ranged specialist who approaches combat like a chess master.
			He stays well behind the front lines, using his gravity manipulation to control the battlefield from a distance.
			Highly tactical - he plans several moves ahead, setting up gravitational fields and positioning before unleashing devastating attacks.

			He's patient and calculating, waiting for the perfect moment to strike rather than engaging recklessly.
			His ancient age shows in his lack of mobility - he rarely moves once positioned, instead bending the battlefield to him.

			Team player by necessity - his physical frailty means he relies heavily on allies to protect him.
			When plans go wrong, he stays calm and adapts, using crowd control to buy time for repositioning.

			His greatest strength is area control - enemies must navigate his gravity wells, crush zones, and repulsion fields.
			His greatest weakness is being flanked or rushed - if the enemy closes distance, he's in serious trouble.
		`,

		preferredWeapons: [
			`Pure gravity manipulation - no physical weapons needed. His "weapon" is reality itself.`,
			`Prefers long-range gravitational strikes that can hit from across the battlefield.`,
			`Also possesses sharp appendages (blades? claws?) capable of slashing attacks.`,
			`These slashing moves deal minimal damage but have tactical utility - creating space, counterattacking when cornered.`,
			`The slashes seem almost reflexive when enemies get too close, like a defensive instinct.`,
			`Favors area-of-effect abilities that control space rather than single-target precision strikes.`
		],

		specialAbilities: [
			`GRAVITY WELL: Creates zones of intense gravitational pull that immobilize or slow enemies, crushing them over time.`,
			`SINGULARITY STRIKE: His ultimate attack - a localized black hole that deals catastrophic damage to all enemies in range.`,
			`REPULSION FIELD: Pushes enemies away, keeping melee threats at bay. Essential for his survival.`,
			`MASS MANIPULATION: Can make allies lighter (increased evasion) or enemies heavier (decreased mobility).`,
			`ORBITAL BOMBARDMENT: Launches debris or projectiles in deadly arcing trajectories using gravity.`,
			`ZERO-G ZONE: Creates areas of weightlessness that disorient enemies and disrupt formations.`,
			`These abilities were mastered over centuries of study - he's one of the few living gravity mages.`
		],

		combatPersonality: `
			In battle, he's unnaturally still - those many eyes tracking everything simultaneously.
			His translated combat communications are often cryptic but tactically sound.
			Might say "the heavier stone falls through silk" when calling for focus fire on an armored target.

			No showboating - combat seems to be pure function for him, no ego attached.
			Plays extremely safe - his physical form is fragile, and he seems aware of this limitation.

			No trash talk. Occasionally makes observations about gravitational inevitabilities that unnerve enemies.
			Victory and defeat produce no readable emotional response - just recalibration.

			When allies fall, his behavior suggests... something. Responsibility? Calculation? Impossible to tell.
			His multiple eyes fixate on the fallen for exactly 3.7 seconds, then return to combat.

			Greatest vulnerability: being isolated and swarmed. The slashing counterattacks can only do so much.
		`
	},

	mechanicalStats: {
		statJustifications: {
			strength: {
				value: 2,
				narrative: `
					EXTREMELY LOW - Whatever the Gravity Captain is, physical strength is not part of his design.
					His frame appears delicate, possibly worn, possibly never meant for physical exertion.
					Can barely manipulate physical objects without gravitational assistance.
					In gameplay, his physical attacks (including slashes) deal minimal damage.
					His entire form seems optimized for channeling gravity, not exerting force.
				`
			},
			special: {
				value: 10,
				narrative: `
					MAXIMUM - This is what he's built for. Devastating special attack power.
					Channels gravitational forces with catastrophic intensity.
					His special attacks hit like orbital strikes - black holes, gravity wells, crushing force.
					In gameplay, his special moves deal absurd damage, especially with type advantage.
					The glass cannon's cannon - trades all survivability for this overwhelming offensive stat.
					When he lands a super-effective Singularity Strike, entire enemy formations can be obliterated.
				`
			},
			skill: {
				value: 3,
				narrative: `
					LOW - His combat style doesn't rely on precision or finesse.
					Uses point-target gravity manipulation and area attacks rather than precise strikes.
					Many of his core abilities have inherently high accuracy built in.
					However, his wide type coverage (can hit enemies with many different elemental attacks) comes with a tradeoff: lower accuracy on those versatile coverage moves.
					In gameplay: some attacks are nearly guaranteed to hit, while coverage options are riskier but offer tactical flexibility.
					Those many eyes track threats, but precision isn't his game - overwhelming gravitational force is.
				`
			},
			luck: {
				value: 5,
				narrative: `
					AVERAGE - Neither particularly fortunate nor cursed.
					He doesn't believe in luck - only in gravity, mass, and acceleration.
					His long life is due to skill and caution, not cosmic favor.
					In gameplay, neutral luck means standard crit rates and no special evasion bonuses.
					"Luck is just probability poorly understood," he'd say.
				`
			},
			agility: {
				value: 4,
				narrative: `
					BELOW AVERAGE - Whatever he is, quick movement is not in his capabilities.
					Those many eyes can track threats, but his body responds slowly.
					Can't dodge physical attacks effectively - hence the reliance on repulsion fields.
					In gameplay, he often acts later in turn order and struggles to evade melee strikes.
					Movement speed is minimal - he typically remains stationary during combat.
				`
			},
			athleticism: {
				value: 2,
				narrative: `
					VERY LOW - His form shows no capacity for sustained physical activity.
					Cannot chain multiple physical actions - even the defensive slashes seem taxing.
					His entire combat methodology is built around this limitation.
					In gameplay, very limited multi-attack capability and poor stamina for physical actions.
					The body is a vessel for channeling gravity, nothing more.
				`
			},
			defense: {
				value: 3,
				narrative: `
					VERY LOW - Whatever is inside that space suit is incredibly fragile.
					The suit provides environmental protection (corrosion, heat) but no meaningful armor.
					Physical impacts bypass the suit's thin material and damage what's beneath.
					In gameplay, he takes massive damage from physical attacks.
					Survives only through positioning, crowd control, and ally protection.
				`
			},
			resistance: {
				value: 7,
				narrative: `
					ABOVE AVERAGE - The space suit provides good protection against elemental and energy-based threats.
					Resistant to heat, corrosion, magical attacks, and energy damage.
					His form (biological? mechanical?) has natural resilience to non-physical forces.
					In gameplay, he can take special attacks better than physical ones, but isn't a magic tank.
					The suit's elemental shielding gives him decent magical defense - his only defensive strength.
				`
			}
		},

		growthRates: {
			hp: 35,           // Low HP growth - stays fragile
			strength: 10,     // Virtually no strength growth - not built for physical force
			special: 60,      // Very high special growth - top-tier glass cannon mage
			skill: 20,        // Low skill growth - precision isn't his focus
			luck: 50,         // Average luck growth
			agility: 25,      // Poor agility growth - limited mobility by design
			athleticism: 15,  // Terrible athleticism growth - physically limited
			defense: 20,      // Poor defense growth - always fragile
			resistance: 50    // Above average resistance growth - elemental fortitude increases
		}
	},

	voiceAndDialogue: {
		speakingStyle: `
			How do they talk?
			What's their vocabulary like?
			Do they use slang, formal language, or something else?
			Are they sarcastic, sincere, or deadpan?
			Do they talk a lot or stay quiet?
			What words or phrases do they use often?
			How does their speech change when emotional?
		`,

		catchphrases: [
			`What phrases do they repeat?
			What would a teammate quote back to them?
			What do they say before doing something risky?`
		],

		exampleDialogue: [
			"Write a line where they're trying to be funny",
			"Write a line where they're under pressure",
			"Write a line where they're being sincere",
			"Write a line where they're angry",
			"Write a line that shows their relationship with another character"
		]
	}
};

// ============================================================================
// PRO TIPS FOR WORKING WITH AI TO DEVELOP CHARACTERS
// ============================================================================
//
// 1. ASK THE AI TO IDENTIFY CONTRADICTIONS
//    "Does this character have interesting contradictions? Suggest some based 
//    on their personality."
//
// 2. TEST DIALOGUE
//    "Write a scene where [Character] has to tell [Other Character] bad news. 
//    Does it sound right?"
//
// 3. CHALLENGE CONSISTENCY
//    "Based on this personality, would they really do [plot action]? If not, 
//    what would make sense?"
//
// 4. RELATIONSHIP DYNAMICS
//    "How would [Character A] and [Character B] interact given their personalities?"
//
// 5. USE THE 'SHOW DON'T TELL' PROMPT
//    "How would I show (not tell) that Spaceman is afraid of responsibility?"
//
// 6. STRESS TEST THE CHARACTER
//    "What would [Character] do if [extreme situation]? How would they justify it?"
//
// 7. FIND THE VOICE
//    "Rewrite this dialogue as [Character] would say it: [generic dialogue]"
//
// 8. CHECK FOR MARY SUE / GARY STU
//    "What are this character's genuine flaws that will cause problems? Are they 
//    too perfect?"
//
// 9. DEVELOP THROUGH CONFLICT
//    "What would [Character A] and [Character B] fight about? What wouldn't they 
//    compromise on?"
//
// 10. BACKSTORY INTEGRATION
//     "How does [backstory element] affect the way [Character] acts in [current 
//     situation]?"
//
// ============================================================================