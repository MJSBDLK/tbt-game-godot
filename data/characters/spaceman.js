export const spaceman = {
	characterId: "spaceman",
	name: null,
	nameIdeas: ['Max Stellar (not his real name)', 'Rex', 'Wade', 'Josh Abraham'],
	realName: null, // TBD - something thematically appropriate for who he becomes, but he's embarrassed by it

	narrativeProfile: {
		age: 30,
		overview: `
			Role: Deck hand (bottom-rung) turned reluctant leader. "I've had plenty of joe jobs.
			Nothing I'd call a career. Let me put it this way, I have an extensive collection of
			nametags and hairnets." Never found something worth committing to until circumstances
			force him to step up and lead a stranded crew.

			Journey: Aimless optimist (Act 1) → lost and grieving (Act 2) → budding leader (Act 3).
			Ma'am dies at end of Act 1. Ernesto declines leadership, forcing Spaceman to fill the void
			gradually over Act 2. By Act 3, settles into the role without losing his spirit.

			What makes him tick: Natural aversion to boredom. Entertains himself creatively on long
			hauls - duct tape sculptures, pranks, furniture swapping. Indefatigably optimistic with
			deflective tendencies. Not a profound thinker, just reacts.

			What he cares about most: Found family (the crew). Good times with good friends. Avoiding
			mundane routine. After Ma'am dies, protecting the people who depend on him.

			What would devastate him: Losing Ma'am (and does). Friends dying because of his decisions.
			Genuine isolation. Losing his spirit to responsibility.
		`,

		personality: `
			Flippant, glib, impetuous. Jabberjaw who fills silence. Sees humor in almost everything
			to the point of being tiresome. "What if I shoot it?" energy - acts first, thinks later
			(but not stupidly).

			Under pressure: "OH GOD WHAT DO I DO" → gets clear order → executes perfectly. Reliable
			in genuine emergencies because he processes danger properly and follows orders well. Just
			needs direction.

			Indefatigably optimistic - deflects negative thoughts instinctively. "She said I'm an
			idiot? Well she's probably ugly anyway." Doesn't honestly believe anything bad will happen
			to HIM until Ma'am dies and shatters that illusion.

			High extroversion - needs social interaction. Bugs Ernesto constantly, ignores boundaries,
			makes friends easily. Goes uncharacteristically silent when grieving (how crew knows
			something's really wrong).

			Not dumb, just uninterested in practical careers. When pressed he could actually impress
			you, but without supervision disinclined to lift a finger. "Could do so much if you
			applied yourself" type who finally applies himself when forced.
		`,

		motivation: `
			Initially: Fun, excitement, avoiding boredom. Decent megacorp pay was a godsend even with
			danger. No grand ambitions - just enjoy life without boring work.

			After Ma'am dies: "What do we do now?" Squad has no direction. Ernesto declines ("I fix
			things"), forcing Spaceman to step up. Gradually realizes he wants to keep this found
			family safe and get them home.

			What he's afraid of: Boredom, isolation. After Ma'am: making the wrong call and getting
			people killed. Becoming so serious he loses who he is.

			Breaking principles: Doesn't have strong principles initially - would do most things if
			fun or helping friends. Learning what he stands for is part of the arc.
		`,

		characterArc: `
			Act 1: Bottom-rung deck hand. Procrastinates until Ma'am chews him out, does work with
			"ok ok jeez." Good in emergencies but needs direction. About to prank Ernesto when ship
			crashes. Ma'am dies at end.

			Act 2: Darkest period. Sits in silence with Ernesto (unusual for jabberjaw). Eventually
			breaks silence with marginally helpful idea. Heartfelt but not eloquent words about Ma'am.
			"What do we do now?" Nobody steps up, so slowly he does. Learning through necessity as
			they recruit allies. One hard lesson at a time.

			Act 3: Settling into leadership. Strategic chaos vs random chaos. Still has spirit and
			humor, but tempered with judgment. Budding badass for endgame as stats flourish. Found
			the thing worth committing to.
		`,

		backstory: `
			Extensive collection of nametags and hairnets from bouncing between joe jobs. Never found
			something worth staying for - whenever things got boring or demanded too much, he'd bounce.

			Megacorp courier work as deck hand was decent pay, kind of a godsend. Became best friends
			with Ernesto. Ma'am chewed him out regularly but enjoyed his optimistic outlook - they
			bantered (not flirty; she's 40 and world-weary). He thought she was stuck-up but she was
			actually quite lax.

			Real name: TBD - something thematically appropriate for who he becomes. He's embarrassed
			by it, which is why he goes by "Max Stellar" instead. His real name is only revealed late
			in the plot - possibly when he receives a medal or commendation at end of game with his
			actual name on it. This reveal could be a moment of accepting who he's become.

			Family situation, formative experiences: TBD - leaving room for discovery. The lack of
			commitment suggests nothing ever felt worth staying for before this.
		`
	},

	characterDepth: {
		thirdRail: `TBD - Lawrence note about testing the third rail. Related to pattern of avoiding
			commitment/responsibility. Arc is about accepting responsibility without losing his spirit.`,

		coreContradiction: `
			Says he doesn't care, but fiercely loyal. Deflects with humor, but Ma'am's death devastates
			him. Avoids responsibility, but becomes the leader. His strength (optimism, quick reactions)
			enables his weakness (doesn't think through, deflects serious problems).
		`,

		wantVsNeed: {
			wants: `Fun, no responsibility, good times without commitments.`,
			needs: `Something worth committing to. To discover he's capable of more. To accept that
				responsibility isn't the death of fun - it's growing up.`
		},

		flaws: [
			`Deflects instinctively - prevents processing helpful criticism`,
			`Procrastinates on anything boring - requires external pressure to complete tasks`,
			`Acts before thinking - creates problems when careful planning needed`,
			`Never committed before - pattern is to bounce when things get hard`,
			`Optimism blinds him to danger - doesn't believe bad things will happen until they do`,
			`Bugs people past boundaries - can be tiresome`
		],

		strengths: [
			`Good in emergencies - doesn't make stupid decisions under pressure`,
			`Loyal to found family - would do anything for them`,
			`Indefatigably optimistic - keeps morale up`,
			`Creative problem solver when engaged - lateral thinking`,
			`Flourishes under combat - natural talent + forced practice = surprisingly capable`,
			`Makes friends easily - helps recruit allies`
		],

		fears: `
			Boredom. Isolation. After Ma'am: making wrong calls, failing everyone, losing his spirit
			to responsibility.
		`
	},

	characterGrowth: {
		growthTriggers: [
			`Ma'am's death - shatters optimistic illusion, forces him to sit with grief`,
			`Ernesto's refusal - "I fix things" forces Spaceman to step up`,
			`First recruit - responsible for strangers' lives now`,
			`First major decision that backfires - leadership means consequences`,
			`Crew follows without question - "wait, they're counting on me?"`,
			`Combat flourishing - discovering he's actually good at this`
		],

		progressionBeats: {
			earlyGame: `Class clown. Procrastinates, pranks. "NOTHING YET!" Pattern: needs direction.`,
			midGame: `Lost period. Silent grief. Gradually picks up slack. Resists, then accepts.
				Makes mistakes, learns lessons. Optimism returns but tempered. Skills improving.`,
			lateGame: `Settled leader. Still has spirit but with judgment. Crew follows. Stats flourished.
				Found the commitment. Balance between responsibility and fun achieved.`
		}
	},

	worldConnection: {
		stanceOnConflict: `
			Initially doesn't care about big picture - just survive and have fun. As leader, starts
			caring about "your people did this" accusation. Personal stakes (getting crew home, protecting
			allies) drive him more than ideology.
		`,

		nonCombatSkills: [
			`Creative entertainment - sculptures, pranks, improvisation`,
			`Social skills - makes friends, recruits allies`,
			`Emergency response - executes orders reliably under pressure`,
			`Varied joe job experience - jack of all trades, master of none`
		],

		quirks: [
			`"What if I shoot it?" - signature testing-things-with-weapons approach`,
			`"ok ok jeez" - response to Ma'am chewing him out`,
			`Constantly bugs Ernesto despite boundaries`,
			`"Battle chickens" - refuses correct name, recurring joke`,
			`Uncharacteristic silence when grieving - the tell something's really wrong`,
			`Plays Sudoku in his head to occupy himself on long hauls - declines to explain when asked`
		]
	},

	perception: {
		selfPerception: `
			Act 1: "Just here for good time, why take me seriously?"
			Act 2: "I have no idea what I'm doing, why is everyone looking at me?"
			Act 3: "Huh. I'm actually... doing this?" Confidence mixed with imposter syndrome.
		`,

		othersPerception: `
			Ma'am: Sees potential, enjoys his outlook, but hard on him. "I like you, kid, but knock it off."
			Ernesto: Knows his heart's in the right place. Amused, protective.
			Crew: Class clown → "wait he's handling this?" → genuine trust.
			Recruits: Only see emerging leader, helps him grow into role.
			Enemies: Underestimate the flippant guy, learn the hard way.
		`,

		reality: `
			Not dumb, just never committed. Natural talent + quick thinking emerge under pressure.
			The "could do so much" guy finally applying himself. Deflective optimism is both genuine
			and shield. Loyalty runs deeper than he'll admit. Becomes genuinely good at leading.
		`
	},

	relationships: [
		{
			characterName: "Ernesto",
			relationshipType: "best_friend",
			dynamic: `
				Best friends. Spaceman bugs him constantly, favorite person to talk AT. Ernesto tolerates
				it because he's amused and knows Spaceman's heart is right. Protective of each other.
				Language barrier (Ernesto's English is second language) but friendship transcends it.

				After Ma'am dies: Sit in silence together. Ernesto declines leadership, forcing Spaceman
				up. Quietly supports without undermining. Dynamic shifts but friendship remains core.
			`
		},
		{
			characterName: "Ma'am (Commander)",
			relationshipType: "mentor_who_dies",
			dynamic: `
				She's world-weary/sarcastic (40), he thinks she's stuck-up but she's actually lax. They
				banter (not flirty). She enjoys his optimism while chewing him out for procrastination.

				Pattern: procrastinate → chewed out → "ok ok jeez" → does it. This gives him direction.
				Takes her for granted until she dies. "What do we do now?" Devastated because lost anchor
				and the person who saw potential in him.
			`
		}],


	combatProfile: {
		fightingStyle: `
			Reactive, improvisational. "What if I shoot it?" applies to combat. Quick to act, adapts
			on fly. Good instincts, not master tactician initially. Scrappy, opportunistic. Flourishes
			under repeated combat. Leads from front by Act 3. Adapts when plans fail without freezing.
		`,

		preferredWeapons: [
			`Laser sidearm - special/elemental attacks AND melee. Enjoys using, doesn't train seriously.
			Not great shot but not bad. Flashy and fun.`,

			`Pistol whip for melee attacks - uses the sidearm as improvised melee weapon. Practical,
			scrappy, fits his improvisational style. Easy to animate (weapon already in hand). Not
			precious about equipment, uses what he has.`
		],

		specialAbilities: [
			`Elemental attacks via sidearm`,
			`TBD based on upgrade path - versatility might translate to varied abilities`,
			`High luck growth = critical hits and lucky breaks`
		],

		combatPersonality: `
			Makes quips during battle, keeps morale up. Has fun with it. Takes unnecessary risks
			sometimes (impulsive flaw). Bounces back from defeats quickly. Late game: coordinates
			others while fighting from front. Maintains irreverent humor (battle chickens) but serious
			when needed.
		`
	},

	mechanicalStats: {
		statJustifications: {
			hp: {
				value: "slightly above average",
				growth: "slightly above average",
				narrative: `Youth (30) + joe job resilience. Not frail, not tank. Growth reflects
					combat flourishing.`
			},
			strength: {
				value: "slightly above average",
				growth: "slightly above average",
				narrative: `Deck hand work requires physical capability. Not Ernesto's 9, but competent.
					Maintains relevance without dominating.`
			},
			skill: {
				value: "low",
				growth: "slightly above average",
				narrative: `KEY GROWTH STAT. Starts low (untrained) but grows above average. "Could do so
					much if you applied yourself" realized. Early game = missing attacks. Late game =
					surprisingly accurate.`
			},
			luck: {
				value: "medium",
				growth: "extremely high",
				narrative: `SIGNATURE STAT. Medium start, grows EXTREMELY high. Natural talent showing through.
					Things just work out. By endgame, luck is absurd - reflects journey from deck hand to
					leader through fortunate circumstances and ability.`
			},
			agility: {
				value: "medium",
				growth: "slightly above average",
				narrative: `Quick to react, good instincts for dodging. Fits "just reacts" combat style.
					Grows slightly above average - natural reflexes improve with combat experience.`
			},
			athleticism: {
				value: "medium",
				growth: "slightly above average",
				narrative: `Deck hand work provides solid baseline fitness. Young (30) and naturally active.
					Grows slightly above average - maintains relevance through physical conditioning.
					Not specialized, but well-rounded and capable.`
			},
			defense: {
				value: "below average",
				growth: "average",
				narrative: `Not trained for combat initially. Growth to average = learns to survive, but
					not tank (that's Ernesto). Compensates with speed and luck.`
			},
			resistance: {
				value: "slightly below average",
				growth: "slightly below average",
				narrative: `Mental/magical resistance not his strength. Remains vulnerability - compensates
					with other stats. All-arounder needs some weaknesses.`
			}
		},

		growthRates: {
			// TBD - will be tuned during playtesting
			// Targets: slightly above avg HP/STR/AGL/ATH, slightly above avg SKL from LOW base,
			// EXTREMELY HIGH LCK (signature), average DEF, slightly below avg RES
		}
	},

	voiceAndDialogue: {
		speakingStyle: `
			Casual, quick, lots of commentary. Short action-oriented sentences. Informal slang. Not
			eloquent. Upbeat and joking normally. Defensive when accused. Silent when truly devastated.
		`,

		catchphrases: [
			`"What happens if I shoot it?" - signature line`,
			`"NOTHING YET!" - defensive when accused`,
			`"ok ok jeez" - response to being chewed out`,
			`"Battle chickens" - recurring joke`,
			`"What do we do now?" - transitions from question to him answering it`
		],

		exampleDialogue: [
			`Funny: "Are those... battle chickens?" "They are combat stryx." "Battle chickens. Got it."`,
			`Under pressure: "OH GOD WHAT DO I DO—" "Shut up and buckle in." "Ok. Helmets?" "Grab 'em."`,
			`Sincere: "She was always yelling at me but... she didn't have to. Could've kicked me off.
				She didn't. And now... what do we do now?"`,
			`Defensive: "What did you do??" "NOTHING YET!" (He was about to
				cause a different, smaller disaster.)`,
			`With Ernesto: "...so I'm thinking we duct tape the—" [eye roll] "You love my ideas."`
				`I just assumed you saying nothing was permission!`
		]
	}
};

// ============================================================================
// NAME: TBD - "Josh" considered (Joshua/Moses parallel, "just joshing") but too on-nose
// Looking for alternatives from familiar games without obvious inspiration signals
//
// CORE: Wayne's World quote - "extensive collection of nametags and hairnets"
// IDENTITY: All-arounder who GROWS. Luck growth extremely high (signature).
//           Skill low→above avg (application of talent)
// ============================================================================
