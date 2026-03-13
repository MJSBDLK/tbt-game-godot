export const grasker = {
	characterId: "grasker",
	name: 'Grasker',
	// test
	narrativeProfile: {
		age: 45,
		overview: `
			Role: Paragon of discipline. The middle-aged man every young man hopes to become. A true stoic.

			Core identity:
			PRIMARY - Disciplined: Decades of rigorous training, shows up every day, holds himself to
			extraordinary standards. The discipline is the foundation of everything else.

			SECONDARY - Humble: Doesn't hold others to his own standards. Quotes great leaders rather
			than claiming wisdom as his own. Became leader by showing up, not seeking glory.

			Journey: TBD

			What makes him tick: Discipline above all. Pragmatism. Respect for the craft of combat even
			though he doesn't enjoy violence itself. Humility - learns from those who came before.

			What he cares about most: TBD

			What would devastate him: TBD

			What makes him different: True stoic warrior-monk. Despite being steeped in violence from
			~20 years of hand-to-hand training and military background, he genuinely doesn't like
			fighting. Prefers to avoid it, but when necessary, ends conflicts with brutal efficiency.
			The reluctant master who earned respect through consistency, not charisma.
		`,

		personality: `
			Typical behavior: Surprisingly easy to talk to. Given the rigorous standards he holds himself
			to, you'd expect him to be completely unrelatable - but he's actually down-to-earth and
			approachable. The disciplined warrior-monk who doesn't make you feel inadequate.

			Defining traits: Doesn't hold others to his own standards - the discipline is for himself,
			not imposed on everyone else. Commands respect naturally - walk into a room and people just
			assume he's in charge. Presence earned through decades of showing up and putting in the work.

			Not a natural leader: Became one simply by being there, being reliable, being competent.
			Didn't seek leadership, just kept showing up until everyone looked to him. The reluctant
			authority figure who earned it through consistency.

			Intelligence: Average, not particularly bright. Not stupid either. Gets by on wisdom gained
			from learning everything the hard way. Reads because people of great wisdom came before him -
			respects those who walked the path first.

			Communication style: Large vocabulary comprehension, small vocabulary when speaking. Speaks
			simply and clearly. Has a repertoire of adages from great leaders (military and otherwise)
			who came before him. Quotes wisdom rather than claiming it as his own.

			Sense of humor: Not a funny guy, but will laugh at your jokes. Appreciates levity even if
			he doesn't generate it himself. Easy to be around despite the intensity he brings to his
			own training and discipline.

			Under pressure: TBD - likely stays calm, falls back on training and experience, maybe quotes
			an adage to center himself or the squad.

			Treatment of others: TBD - patient and understanding, doesn't expect others to match his
			intensity. Makes people feel comfortable despite his intimidating presence.
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
		coreIdentity: `
			PRIMARY TRAIT: Discipline - decades of rigorous training, shows up every day, holds himself
			to extraordinary standards. This is the foundation of everything else about him.

			SECONDARY TRAIT: Humility - doesn't impose his standards on others, quotes wisdom from great
			leaders rather than claiming it himself, became leader through consistency not ambition.

			TRUE STOIC: Controlled emotions even under pressure, calm in chaos, pragmatic about violence,
			accepts hardship without complaint. The warrior-monk who practices what he preaches.
		`,

		coreContradiction: `
			Seems unapproachable (disciplined stoic warrior) but surprisingly easy to talk to (humble,
			down-to-earth). You'd expect someone who holds himself to such high standards to be rigid
			with others, but he's patient and understanding.

			Steeped in violence for decades, master of combat, yet genuinely doesn't like fighting.
			Will give enemies multiple chances to surrender, but coldly efficient when elimination
			is necessary. "You can walk away" vs "You're dead" - the reluctant warrior.

			Strength = discipline, humility, stoicism. Weakness = same traits can make him slow to
			adapt when the situation demands breaking protocol or flexible thinking (relies on wisdom
			from others, not natural brilliance).
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
			`Stands with exceptional posture - military bearing, shoulders back, discipline visible
			in how he carries himself`,

			`Down-to-earth despite intimidating presence - will help with manual labor, doesn't
			pull rank or act superior`,

			`Wears practical, easy-to-move clothing - usually sleeveless to allow arm mobility.
			Function over fashion, warrior monk aesthetic`,

			`High situational awareness - constantly scanning, assessing threats, never fully relaxed
			even when calm`,

			`Bows to opponents out of respect - before matches, and even to the corpses of enemies
			who fought well. Respects the craft of combat even if he dislikes violence`
		],

		physicalAppearance: {
			build: `Leaner powerlifter build - "natty max" FFMI, 12-15% body fat. 6'0", broad shoulders.
				Huge forearms, thick fingers. The body of someone who's done a lifetime of manual labor
				plus nearly two decades of disciplined hand-to-hand training.`,

			face: `Pink nose, narrow eyes, prominent caveman brow. Head shaved save for a tuft of orange
				hair on top - standard military style for men from his planet (he's an offshoot of human
				native to where the story takes place).`,

			presence: `Calm, grounded, down-to-earth. Can shift to "killmode" at the snap of a finger -
				the transition is instant and complete. High discipline visible in posture and bearing.`
		}
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
			Avoidance first - prefers not to fight, will always attempt verbal de-escalation if the
			opportunity presents itself. Does not like violence, just happens to be steeped in it.

			When combat is unavoidable: Transitions from calm to "killmode" instantly. The shift is
			complete - high situational awareness kicks in, assesses threats, neutralizes with brutal
			efficiency. No hesitation, no wasted movement.

			Fighting approach: Explosive power specialist. Uses multi-hit, high-precision combinations.
			Fists that put holes in things. Not about endurance or wearing down opponents - about
			ending the fight quickly and decisively.

			Pragmatic about lethality: Will spare attackers if possible, but will NOT endanger himself
			or his squad to do so. If someone needs to die for the mission/squad to survive, he'll do
			it without hesitation. The discipline to make hard calls.

			Team role: TBD - likely protective positioning, uses his power to eliminate priority threats.
			Not a lone wolf, but comfortable taking point when needed.
		`,

		preferredWeapons: [
			`Hand wraps (tier 1) - traditional cloth wraps, bare-knuckle style. Protects his hands from
			bleeding during extended combat, provides minimal support to knuckles/wrists.`,

			`Why hand-to-hand: ~20 years of disciplined training, possibly military background. This is
			what he knows, what he's mastered. The body as weapon.`,

			`Class progression: TBD - might change combat styles depending on how his class develops.
			Flexibility in build to support gameplay variety.`
		],

		specialAbilities: [
			`Multi-hit combinations - signature fighting style, rapid precise strikes with explosive power`,

			`High precision strikes - targeting weak points, maximizing damage efficiency`,

			`TBD based on class progression - abilities should reflect disciplined martial artist aesthetic,
			explosive power theme, and pragmatic approach to combat`
		],

		combatPersonality: `
			Before combat: Attempts de-escalation verbally. Calm, grounded, gives opponents a chance to
			stand down. The reluctant warrior giving the enemy an out.

			During combat: Silent and focused once killmode activates. No trash talk, no showboating,
			no unnecessary flourishes. This is work that needs doing. Efficient, brutal, precise.

			After victory: Bows to opponents out of respect - even to corpses of enemies who fought well.
			Respects the craft of combat and warriors who commit fully, even if they were enemies. Does
			not celebrate - just acknowledges, then moves on.

			Honor without naivety: The bowing and respect don't mean he's soft. If you threaten his squad,
			he'll put you down without hesitation. Respect for warriors ≠ mercy for threats.
		`
	},

	mechanicalStats: {
		statJustifications: {
			hp: {
				value: "high",
				growth: "high",
				narrative: `
					High base - 45 years old but in peak condition. Lifetime of physical labor, decades of
					combat training, very high constitution. The body of a warrior-monk who's maintained
					discipline through middle age.

					High growth - continues to condition himself, learns to take hits better, improves
					durability through experience. Combined with very high constitution, he's a tank in
					hit points even without heavy armor.
				`
			},
			strength: {
				value: 10,
				growth: "mid-high",
				narrative: `
					Starts at maximum (10) - combination of lifetime manual labor, nearly 20 years of
					disciplined hand-to-hand training, and natural build. "Natty max" FFMI, leaner
					powerlifter physique. Huge forearms, thick fingers. Fists that put holes in things.

					Mid-high growth - doesn't make complete narrative sense (he's already peaked physically
					at 45), but necessary for game mechanics to keep him relevant. Could justify as
					"learning to apply strength more effectively in combat" or class progression unlocking
					new power techniques.

					Physical manifestation: Broad shoulders, exceptional upper body development, visible
					muscular definition at 12-15% body fat. The body of a disciplined warrior-monk.
				`
			},
			skill: {
				value: "high",
				growth: "high",
				narrative: `
					High base - ~20 years of disciplined training. Uses multi-hit, high-precision strikes.
					Targets weak points efficiently. Master of his craft.

					High growth - continuous refinement. Never stops training, always improving technique.
					The discipline to practice even after mastery. Combined with high strength, makes him
					a devastating precision striker who keeps getting better.
				`
			},
			luck: {
				value: "extremely low",
				growth: "low",
				narrative: `
					Extremely low base - Grasken doesn't rely on fortune. Discipline, preparation, training.
					If anything, his pragmatic worldview means he expects Murphy's Law more than lucky breaks.

					Low growth - luck just isn't his stat. He compensates through skill, strength, awareness,
					and preparation. The anti-luck build - succeeds through mastery, not chance.
				`
			},
			agility: {
				value: "average",
				growth: "slightly above average",
				narrative: `
					Average base - not slow, but at 6'0" with powerlifter build and 45 years old, he's not
					lightning fast either. Compensates with positioning, awareness, and power.

					Slightly above average growth - maintains combat effectiveness, improves reaction time
					and footwork through continued training. Enough to stay relevant, not enough to become
					a speedster.
				`
			},
			athleticism: {
				value: "average",
				growth: "high",
				narrative: `
					Average base - solid conditioning from manual labor and training, but 45 years old.
					Good baseline, not exceptional initially.

					High growth - reflects his explosive power fighting style. Multi-hit combinations,
					rapid strikes, capability for multiple attacks. His athleticism manifests as explosive
					bursts rather than sustained endurance. Growth represents mastering techniques that
					allow more attacks per turn.

					The disciplined training regimen paying off - even at 45, he maintains and improves
					through sheer commitment to the craft.
				`
			},
			defense: {
				value: "average",
				growth: "slightly below average",
				narrative: `
					Average base - tough from conditioning and very high constitution, but doesn't wear
					armor. Relies on sleeveless, practical clothing for mobility. Natural durability, not
					protective gear.

					Slightly below average growth - intentional trade-off. High HP/constitution keep him
					alive, but defense doesn't scale well. He takes hits and powers through rather than
					deflecting them. The brawler who relies on toughness over armor.
				`
			},
			resistance: {
				value: "below average",
				growth: "medium-low",
				narrative: `
					Below average base - intentional weakness. Average intelligence, pragmatic mindset
					means he's vulnerable to mental/magical attacks. The disciplined warrior-monk aesthetic
					doesn't translate to mystical resistance - he's just a very skilled human.

					Medium-low growth - improves slightly through exposure and experience, but never becomes
					strong here. This is his Achilles heel. High physical stats, low magical defense. Needs
					squad support against casters.
				`
			},
			movement: {
				value: "average",
				narrative: `
					Average movement - not slow, not fast. Positions himself well through awareness rather
					than speed. The methodical advance of a disciplined fighter who doesn't need to sprint
					across the battlefield.
				`
			},
			constitution: {
				value: "very high",
				narrative: `
					Very high constitution - the foundation of his survivability. Decades of conditioning,
					manual labor, disciplined training. Exceptional endurance, pain tolerance, ability to
					keep fighting when others would drop.

					This is why his HP is high despite average defense. He's just that tough - takes the
					hit, keeps moving. Combined with high HP growth, he becomes a meat shield who hits
					like a truck.
				`
			}
		},

		growthRates: {
			// TBD - will be tuned during playtesting
			// Summary:
			// - HIGH HP (high base, high growth) + VERY HIGH CONSTITUTION = tank without armor
			// - MAX STRENGTH (10 base, mid-high growth) = fists that put holes in things
			// - HIGH SKILL (high base, high growth) = precision multi-hit specialist
			// - EXTREMELY LOW LUCK (extremely low base, low growth) = anti-luck build, pure mastery
			// - AVERAGE AGILITY (avg base, slightly above avg growth) = not slow, not fast
			// - AVERAGE ATHLETICISM (avg base, HIGH growth) = explosive power, multi-hit combos
			// - AVERAGE DEFENSE (avg base, slightly below avg growth) = no armor, relies on HP
			// - BELOW AVERAGE RESISTANCE (below avg base, medium-low growth) = Achilles heel vs magic
			// - AVERAGE MOVEMENT = methodical positioning
			//
			// Build identity: High-HP strength/skill brawler with explosive multi-hit combos,
			// vulnerable to magic, succeeds through discipline not luck
		}
	},

	voiceAndDialogue: {
		speakingStyle: `
			Simple, direct, clear. Large vocabulary comprehension, small vocabulary when speaking.
			Doesn't waste words. Uses short sentences that get the point across.

			Quotes adages from great leaders (military and otherwise) who came before him. Respects
			the wisdom of those who walked the path first. "As [leader] said..." or similar framing.

			Calm and measured normally. No sarcasm, no quips. Sincere and straightforward. What you
			see is what you get.

			When emotional: Still controlled. Discipline shows even under stress. Might fall back on
			an adage to center himself or the squad.
		`,

		catchphrases: [
			`TBD - likely quotes from great leaders, military sayings, adages about discipline/honor/pragmatism`
		],

		exampleDialogue: [
			`Attempting de-escalation (reasonable enemy): "You can walk away. I'm giving you the chance."
			[pause] "Last chance." [gives them multiple opportunities if they seem reasonable]`,

			`Against sociopaths/those who killed innocents: "You're dead." [cold, final, no negotiation]`,

			`Under pressure: TBD - likely stays calm, maybe quotes an adage to steady himself or the squad`,

			`Being sincere: TBD - simple, direct, honest. No flowery language.`,

			`Quoting wisdom: "As [great leader] said, [relevant adage]." [humble attribution, not claiming
			wisdom as his own]`
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