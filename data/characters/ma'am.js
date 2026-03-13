export const maam = {
	characterId: "maam",
	name: null, // TBD - everyone just calls her "Ma'am"
	rank: "Major (ex-military, dishonorably discharged)",

	narrativeProfile: {
		age: 40,
		overview: `
			Role: Commander of megacorp courier crew. De facto mother figure. The anchor who holds
			everyone together through competence and experience. Dies at end of Act 1, forcing Max
			to step up when Ernesto declines leadership.

			Journey: No arc - she's the stable point. Professional but lax commander who maintains
			ship operations and crew morale while dealing with corporate bullshit and exhaustion.
			Brief spark of hope/attraction with Cooldude before her death.

			What makes her tick: The crew is her raison d'être. After dishonorable discharge closed
			military career paths, this found family gives her life meaning. Keeps them safe, helps
			them grow, maintains order while permitting harmless chaos.

			What she cares about most: Crew survival and growth. Getting them home safely. Maintaining
			standards without crushing spirits. Early retirement (but no family to retire to).

			What would devastate her: Losing crew members. Failing to protect them. The void of meaning
			without them. Being alone again after finding this family.
		`,

		personality: `
			World-weary, sarcastic, cynical-funny, bitter-funny. "So done" with everything - corporate
			overlords, rude clients, the unhelpful VI, the general bullshit of existence. Pragmatic
			survivor who's seen war and come out harder.

			Under pressure: Ice cold, ruthless, tactical. Seeks quickest solution to neutralize threats.
			Takes no risks with crew lives. Combat-tested nerves. The most dangerous person in the room
			despite being 120 lbs.

			Commands respect through unquestionable competence and experience. Not iron fist - people
			fall in line instinctively because this woman knows what she's doing. Ice queen on official
			business, but crew at ease around her off-duty.

			The "quite lax" thing: Max thinks she's stuck-up because she won't let duties slide. Reality:
			she permits all his shenanigans so long as they don't interfere with ship operations. Finds
			naked streaking prank funny despite being catastrophically unprofessional - "PUT YOUR GODDAMN
			CLOTHES ON" then laughs to herself later. Only sets her off when actually dangerous or
			jeopardizing mission/profit. Draws clear, well-reasoned lines that are easy to understand.

			Not a "fun" person, but brings out warmth when engaging crew to keep morale up. Enjoys Max's
			optimism - represents whimsical mindset before she knew what war was like. Appreciates Ernesto
			as devoted family man who never hits on her.
		`,

		motivation: `
			The crew. That's it. No grand ambitions left after seeing war firsthand and getting discharged.
			Higher-ranking opportunities closed. Military life behind her. This leaves void of meaning -
			the crew fills it.

			Wants early retirement but has nobody to retire to. Single because never found anyone "good
			enough" - usually the bravest, most competent person around despite being surrounded by men.
			Finds civilian men unimpressive, businessmen haughty, doctors unimpressive or married. Her
			personality isn't first-date material anyway.

			Brief spark with Cooldude - he's everything her romantic life lacked (charismatic, leaderly,
			competent). Gets flustered, maintains composure but might have Freudian slip. Dies before
			it can go anywhere.

			What keeps her going: Responsibility for crew growth and survival. Setting good example.
			Thinks she's grooming Crew #4 for leadership (wrong - it'll be Max). Doesn't see Max as
			capable leader, just tries to be positive influence.
		`,

		characterArc: `
			No traditional arc - she's the stable point that others orbit. Dies at end of Act 1 before
			she can change. Her death IS the arc trigger for Max and the crew.

			Early game: Overworked, exhausted, fed up with corporate life, but keeping ship running and
			crew together. Professional commander with surprising laxity about harmless fun. Pattern with
			Max: procrastinate → chew out → "ok ok jeez" → he does it. This gives him direction he'll
			lose when she dies.

			Meets Cooldude: Brief moment of hope, attraction, possibility. Gets red in face, tongue-tied.
			First time in years someone measured up to her standards.

			Death: Separated from squad with neutral NPC, retrieves critical intel, ambushed by NapDawg's
			men (they killed NPC at intro). Close enough to squad that rejoining seems possible. Player
			controls her in supposed-to-lose fight. Goes down fighting, overwhelmed, recognizes hopeless.
			Tries to order pullback.

			Last words (TBD which): "Pull back. That's an order." OR "Ernesto, get them out of here."
			OR "Well, shit." Unceremonious to reinforce bleak fate and "lost" feeling.
		`,

		backstory: `
			Ex-military, worked up to Major through repeated bravery and level head under pressure.
			Combat medic background - saved lives while being shot at. Knows her way around weapons
			despite non-combat role, had to fight out of jams multiple times. Training paid off.

			Dishonorable discharge: Went rogue after superiors covered up malfeasance/war crimes, or
			realized her side were the bad guys. Had to prioritize survival over morals, came out
			unscathed but changed. Reintegrating to polite society where normal folk don't get it.

			Smallest person in most rooms (120 lbs) but usually bravest and most competent. Proved
			herself repeatedly in male-dominated environment. Never found romantic equal - men either
			intimidated, unimpressive, or married.

			Took dangerous megacorp courier job for good pay. Spaceships need security clearance for
			classified tech (her military background). Wishes she'd been married/early retirement by now,
			but life didn't work out that way.
		`
	},

	characterDepth: {
		coreContradiction: `
			Appears stuck-up and strict (Max's view) but actually quite lax about harmless fun. Ice
			queen on duty, warm off-duty. Ruthless in combat but protective mother figure. Fed up with
			everything but keeps engaging crew for morale. Looking for retirement but has nothing to
			retire to.

			Strength = weakness: Competence and self-reliance mean she never found equal partner.
			Standards that made her great soldier make her lonely person.
		`,

		wantVsNeed: {
			wants: `Early retirement, equal partner (finds brief possibility in Cooldude), meaning
				beyond corporate drudgery.`,
			needs: `The crew - they give her life meaning after military career ended. She has what
				she needs (found family) but doesn't fully realize it before she dies.`
		},

		flaws: [
			`Standards too high - finds most people unimpressive, contributes to loneliness`,
			`Doesn't see Max's leadership potential - blind spot about who'll actually step up`,
			`Overworks herself - coffee addiction, bags under eyes, exhaustion`,
			`Cynicism prevents vulnerability - hard to connect romantically`,
			`Carries war trauma - has prioritized survival over morals, harder than she lets on`
		],

		strengths: [
			`Unquestionably competent - earns respect through ability, not authority`,
			`Level head under pressure - combat-tested, ruthless when needed`,
			`Good judge of character - knows Max's heart is good, appreciates Ernesto's reliability`,
			`Balances discipline with laxity - clear reasonable lines, permits harmless chaos`,
			`Protective - would die for crew (and does)`,
			`Self-aware - recognizes her limits, knows when to be ice queen vs when to warm up`
		],

		fears: `
			Losing crew members. The void of meaning without them. Dying alone. Never finding equal
			partner. The military past catching up. Failing to protect the people who depend on her.
		`
	},

	characterGrowth: {
		growthTriggers: [
			`None - she dies before growing. Her death triggers everyone else's growth.`,
			`Meeting Cooldude shows her what she's been missing romantically - brief hope before death.`
		],

		progressionBeats: {
			earlyGame: `Overworked commander keeping ship running. Fed up but professional. Enjoys crew
				interactions. Chews out Max, appreciates Ernesto, tries to mentor Crew #4. Brief spark
				with Cooldude.`,
			midGame: `Dead.`,
			lateGame: `Still dead. Crew carries her lessons forward. Max becomes leader she didn't see
				coming. Her death the catalyst for everything.`
		}
	},

	worldConnection: {
		stanceOnConflict: `
			Doesn't care about big picture - lost faith after seeing war firsthand and superiors'
			malfeasance. Just wants to complete jobs, get paid, keep crew safe. Fed up with corporate
			overlords but plays the game for the paycheck. Personal stakes only - protect her people.

			Gets casual sexism from feudal locals who presume Ernesto is leader. Irritates her but
			not enough to provoke. Picks battles carefully.
		`,

		nonCombatSkills: [
			`Polymath - handles everything Ernesto doesn't (he fixes things, she does the rest)`,
			`Navigation, negotiations, crew management`,
			`Reads trash novels and history books to dissociate`,
			`Self-care when grounded - bubble baths, massages, hair and nails (unkempt hair on long hauls bugs her)`,
			`Recognizes importance of constant drilling but enthusiasm waned with age`
		],

		quirks: [
			`Coffee addict - drinks too much`,
			`Smokes when super stressed but never in view of crew`,
			`Bags under eyes, frazzled hair in messy bun on ship`,
			`Stands straight with shoulders back in front of crew despite exhaustion`,
			`Keeps in extremely good shape despite age and exhaustion`,
			`Argues with unhelpful VI (only knows procedure, useless for novel situations)`,
			`Disabled ship cameras for privacy, tells VI she'll "look into fixing it" but never does`
		]
	},

	perception: {
		selfPerception: `
			Competent professional doing a job. Tired. Fed up. Too old for this shit but good at it.
			Aware she's become harder than she used to be. Aware she's probably dying alone. Tries to
			be good influence on younger crew even when exhausted.
		`,

		othersPerception: `
			Max: Stuck-up hardass who won't let him slack (wrong - she's lax about harmless fun).
			Ernesto: Reliable partner, appreciates her competence, comfortable silence.
			Crew #4: Mentor figure who's grooming them for leadership.
			Cooldude: Equal, attractive, possibility (hits her hard).
			General reputation: Don't fuck with the Major. She's seen some shit and will end you.
		`,

		reality: `
			Lonelier than she admits. The crew is everything to her - they fill the void left by
			military discharge and lack of family. Harder than she used to be from war trauma but
			still capable of warmth and hope (Cooldude proves this). Doesn't realize Max will be
			the one to step up as leader. Dies protecting her found family.
		`
	},

	relationships: [
		{
			characterName: "Max",
			relationshipType: "crew_commander_to_subordinate",
			dynamic: `
				She chews him out for procrastinating, he does it with "ok ok jeez." This pattern gives
				him direction. She thinks he's talented but lazy - "could do so much if you applied yourself."
				Doesn't see him as leadership material, just tries to be positive influence.

				Enjoys his optimism despite finding him tiresome sometimes. He represents whimsical mindset
				before she knew war. Permits his shenanigans (even naked streaking prank) so long as they
				don't interfere with operations. Laughs to herself about his antics later.

				Max takes her for granted - assumes she'll always be there to tell him what to do. Her
				death devastates him because he lost his anchor and the person who saw potential in him.
			`
		},
		{
			characterName: "Ernesto",
			relationshipType: "co_leads",
			dynamic: `
				Peanut butter and jelly. She's the polymath (handles everything), he's the wizard at fixing
				things. Keeps everything shipshape so she doesn't have to think about it. Perfect division
				of labor.

				Both around 40, both single (him by choice - devoted family man, her involuntarily). She
				appreciates that he's never "tryna holler" - can work comfortably without that bullshit.
				Respects his expertise, knows his heart is in the right place.

				When she dies, tells him "Ernesto, get them out of here" - trusts him to execute even
				though he won't lead. He knows what she meant to the crew.
			`
		},
		{
			characterName: "Crew #4",
			relationshipType: "mentor_to_protégé",
			dynamic: `
				TBD - she thinks she's grooming this one for leadership (wrong). Probably runs drills,
				gives tactical advice, teaches navigation/command skills. Crew #4 likely looks up to her,
				wants her approval.
			`
		},
		{
			characterName: "Cooldude",
			relationshipType: "budding_attraction_cut_short",
			dynamic: `
				He's everything her romantic life lacked - charismatic, leaderly, competent, not bad looking.
				Everything measures up to her impossible standards. Gets red in face when they meet, maintains
				composure but might have Freudian slip, tongue-tied.

				Successfully professional but the attraction is obvious to observant crew members. Brief hope,
				possibility of equal partnership. Dies before it can develop. Hits him hard too - was interested
				back. Her death reinforces the "lost" feeling.
			`
		}
	],

	combatProfile: {
		fightingStyle: `
			Tactical, ruthless, efficient. Avoidance first through positioning and footwork (she's fast).
			If forced into combat: disable and escape, not prolonged fights. Targets vulnerabilities to
			neutralize threats quickly.

			Plans meticulously but adapts when necessary. Team player, often gives tactical orders. Leads
			by positioning herself strategically, not charging in. When plan goes wrong: stays ice cold,
			recalculates, issues new orders without panic.

			Fights dirty when physical - HAS to against bigger opponents. Eye gouges, groin strikes, hamstring
			cuts to cripple movement, slash face to obscure vision. No honor in survival.
		`,

		preferredWeapons: [
			`Combat knife (Leon RE4 style) - mounted somewhere easily accessible (chest rig, belt, or boot).
			Quick deployment for close quarters. In tight spaces/grappling, more dangerous than gun. For
			120 lbs fighter: targets throat, eyes, tendons, arteries. Quick slashes to create space. Uses
			environment (corners, obstacles) to limit opponent reach advantage.`,

			`Sidearm for special/ranged attacks. Precision over power. Well-practiced despite non-combat
			role background.`
		],

		specialAbilities: [
			`"Ghost" passive - can move through cells occupied by enemies (tactical positioning, slipping
			past bigger opponents)`,

			`"Low Profile" passive - enemies deprioritize targeting her (small, fast, hard to pin down)`,

			`Disabling attacks - kit involves crippling enemy units (hamstrings, tendons, eyes) to remove
			threats without killing`,

			`High skill means precision strikes, efficient damage, rarely wastes moves`
		],

		combatPersonality: `
			Silent and focused in combat. No quips, no showboating, no unnecessary risks. Clinical efficiency.
			This is survival, not sport.

			Handles victory: Just moves on, checks crew status. Handles defeat: Tactical retreat, regroup,
			learn. No ego about it - pragmatic survivor.

			When she's dying in that supposed-to-lose fight: Stays tactical, tries to make it back to squad.
			Realizes hopeless, orders pullback to save them. Goes down fighting but accepts reality. Unceremonious
			end for someone who lived pragmatically.
		`
	},

	mechanicalStats: {
		statJustifications: {
			hp: {
				value: "low",
				growth: "low",
				narrative: `120 lbs, 40 years old. Not frail but not a tank. Compensates with speed, skill,
					and not getting hit. Low HP is the trade-off for high agility.`
			},
			strength: {
				value: "low",
				growth: "low",
				narrative: `Small frame, relies on technique over power. Fights dirty because she has to.
					Knife work is about precision, not force. Keeps in shape but physics limits her.`
			},
			skill: {
				value: "high",
				growth: "high",
				narrative: `Combat-tested veteran. Years of drilling paid off. Precision striker, efficient,
					practiced. High skill reflects experience and training. This is how she survives despite
					size disadvantage.`
			},
			luck: {
				value: "mid",
				growth: "mid",
				narrative: `Has survived this long through skill, not luck. Average luck - no plot armor.
					This is why she dies when ambushed despite competence.`
			},
			agility: {
				value: "high",
				growth: "high",
				narrative: `Fast footwork, tactical positioning, slipping through enemies. Core survival trait
					for 120 lb fighter. Ghost passive reflects this. Speed keeps her alive.`
			},
			athleticism: {
				value: "mid-high",
				growth: "mid-high",
				narrative: `Keeps in extremely good shape despite age and exhaustion. Recognizes importance
					of fitness for survival. Not peak athlete but well above average. Maintains standards.`
			},
			defense: {
				value: "mid-low",
				growth: "mid-low",
				narrative: `Can't take hits - small frame, light armor. Defense comes from not getting hit
					(agility) rather than tanking damage. Vulnerable when cornered.`
			},
			resistance: {
				value: "mid-low",
				growth: "mid-low",
				narrative: `War trauma shows some mental vulnerability despite hard exterior. Not weak, but
					carries scars. Average magical/special resistance.`
			}
		},

		growthRates: {
			// TBD - won't matter much since she dies early
			// If she were playable longer: emphasize skill/agility growth, minimal HP/STR/DEF growth
		}
	},

	voiceAndDialogue: {
		speakingStyle: `
			Sarcastic, dry, world-weary. Short efficient sentences on duty. Allows herself more warmth
			off-duty but still not chatty. Professional vocabulary, military bearing. Cynical-funny and
			bitter-funny blend - laughs at absurdity of existence.

			Deadpan delivery of sarcastic lines. Rarely raises voice - the quiet "I'm disappointed" is
			scarier than yelling. Direct, no-nonsense. Says what needs saying without sugar-coating.
		`,

		exampleDialogue: [
			`"Pull back. That's an order." - final words (one version)`,
			`"What if you HIT IT, Max??" - exasperated response to his "what if I shoot it" energy`,
			`"PUT YOUR GODDAMN CLOTHES ON" - response to naked streaking prank`,
			`Probably calls people by rank/role when annoyed, by name when warm`
		],

		exampleDialogue: [
			`Funny/Sarcastic: "Oh good, the VI's being helpful again. How did we ever survive without its
				encyclopedic knowledge of procedures we already know?"`,

			`Under pressure: "Shut up and buckle in." [calm, cold] "Helmets?" [Max: "Where are they?"]
				"Grab them." [no panic, just efficiency]`,

			`Sincere: TBD - needs example of warmth with crew, maybe talking to Ernesto about his kids or
				acknowledging Max's growth`,

			`Angry: [when genuinely dangerous situation] "That's enough. That crosses the line. You jeopardize
				this crew again and you're off my ship. Clear?"`,

			`With Cooldude: [gets red in face, momentarily flustered] "I— yes, the tactical position is...
				sound. Good work." [realizes she stuttered, composes herself] "Carry on."`,

			`Dying: "Pull back. That's an order." OR "Well, shit."
				[matter-of-fact acceptance]`
		]
	}
};

// ============================================================================
// NOTES:
// - Dies end of Act 1 in supposed-to-lose fight (player controls her)
// - Separated from squad, ambushed by NapDawg's men after retrieving intel
// - NPC with her killed at mission intro
// - Close enough to squad that rejoining seems possible initially
// - Goes down fighting, overwhelmed, orders pullback
// - Death is unceremonious to reinforce bleak fate and "lost" feeling
// - Her death triggers Max's leadership arc and crew's "what do we do now?" crisis
// ============================================================================
