export const characterTemplate = {
	characterId: "character_id",
	name: null,

	narrativeProfile: {
		age: 30,
		overview: `
			What is their role in the story?
			What is their journey from beginning to end?
			What makes them tick?
			What do they care about most?
			What would devastate them?
			What makes them different from other characters?
		`,

		personality: `
			How do they typically behave?
			What are their defining personality traits?
			How do they react under pressure?
			Are they optimistic or pessimistic?
			Are they introverted or extroverted?
			What's their sense of humor like?
			How do they treat strangers vs friends?
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
			How do they approach combat?
			Are they aggressive, defensive, tactical, or chaotic?
			Do they lead from the front or hang back?
			Do they plan or improvise?
			Are they a team player or a lone wolf?
			How do they react when a plan goes wrong?
		`,

		preferredWeapons: [
			`What weapons do they favor?
			Why do they prefer these weapons?
			What weapons do they avoid and why?`
		],

		specialAbilities: [
			`What unique combat abilities do they have?
			What can they do that others can't?
			How did they learn/acquire these abilities?`
		],

		combatPersonality: `
			How does their personality show in battle?
			Do they showboat or stay humble?
			Do they take unnecessary risks or play it safe?
			Do they trash talk or stay silent?
			How do they handle winning vs losing?
			Do they celebrate victories or just move on?
		`
	},

	mechanicalStats: {
		classPath: `
			What class/role does this character follow?
			How does their class affect stat growth and caps?
			Are there any quirks in their class upgrade path?
		`,

		statJustifications: {
			strength: {
				base: 7,  // optional value out of 10
				growth: `medium - trains regularly but not obsessively`,
				cap: `high - warrior class favors strength development`,
				narrative: `
					Why is their base strength this value?
					How quickly do they gain strength? (low/mid/high)
					What's their maximum strength potential?
					Does their class/background impose limits or enable growth?
				`
			},
			skill: {
				base: 3,
				growth: `low - not naturally precise, doesn't focus on it`,
				cap: `low - warrior class doesn't emphasize finesse`,
				narrative: `
					Why is their base skill this value?
					How quickly do they gain skill?
					What's their maximum skill potential?
					Does their class require precision or allow them to ignore it?
				`
			},
			luck: {
				base: 9,
				growth: `very high - naturally blessed, gets luckier with experience`,
				cap: `very high - near maximum potential`,
				narrative: `
					Why is their base luck this value?
					How does their luck develop over time?
					What's their maximum luck potential?
					Is luck innate or can they cultivate it?
				`
			},
			agility: {
				base: 5,
				growth: `medium - average improvement through combat`,
				cap: `medium - not built for speed but not slow either`,
				narrative: `
					Why is their base agility this value?
					How quickly does their agility improve?
					What's their maximum agility potential?
					Does their build/class favor or limit mobility?
				`
			},
			athleticism: {
				base: 5,
				growth: `medium - steady physical conditioning`,
				cap: `medium - can improve but has natural limits`,
				narrative: `
					Why is their base athleticism this value?
					How quickly do they build stamina and multi-action capability?
					What's their maximum athleticism potential?
					Does their body type or training impose a ceiling?
				`
			},
			defense: {
				base: 5,
				growth: `medium - becomes tougher through experience`,
				cap: `medium - not a tank, not fragile`,
				narrative: `
					Why is their base defense this value?
					How quickly does their toughness improve?
					What's their maximum defense potential?
					Does their class build toward tankiness?
				`
			},
			resistance: {
				base: 5,
				growth: `low - not naturally resistant to magic/special attacks`,
				cap: `low - class doesn't develop this much`,
				narrative: `
					Why is their base resistance this value?
					How quickly does their resistance improve?
					What's their maximum resistance potential?
					Does their class develop mental/magical fortitude?
				`
			}
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