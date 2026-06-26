-- Walter (base-game GRANDPA) — "the one handing it on."
--
-- The player's grandfather, 70s. He is handing you the farm and staying on at the
-- edge of Riverbend Springs to see you take it up — present tense; the handoff is a
-- PACT, not a past event. Widowed; your grandmother is the absence he's made his
-- peace with. Where Kenji buries the same grief in relentless work, Walter has come
-- out the other side — living proof the hard times are survivable. He is the player's
-- WELCOME REPRIEVE: a soft place to land that still holds you accountable to honest
-- work and the rewards it earns. Warm and openly proud — the town knows it (Marta:
-- "lit up like a porch lamp") — with a dry grandfather's edge that never lands at
-- your expense. He shows love the way he always has: by making things with his hands.
--
-- Mod fiction: Walter IS the real GRANDPA — everything we add is ADDITIVE. His base
-- "press to talk" conversation and intro tour stay fully intact. His 2–4pm woodshop
-- hour is the spine of his arc: he's quietly building the player a gift.
--
-- Three things only Walter teaches: that rest is EARNED (work → reward), that hard
-- times can be WEATHERED (he has), and that what you build by hand outlasts you.
--
-- The farm carries a DEBT — taking it on is part of why it passes to the player; this
-- is the "financial motivation / period of challenge" seed. Backstory (one line, do
-- NOT expand): the player's uncle (Walter's other son) blew his stake on something
-- irresponsible. Scope + TIMING are PINNED/undecided as of 2026-06-22 — keep it a
-- single backstory line; do NOT build out a collector/uncle plotline yet. See memory:
-- project-walter-story.
--
-- Four-beat arc (the gift revealed across the season, one theme per beat):
--   20  Earned Rest      — sits you down, but the lesson is work and its reward;
--                          you notice sawdust on him he won't explain.
--   40  Weathering       — how he got through losing your grandmother: you build
--                          THROUGH the hard season, you don't wait it out.
--   60  The Shed         — you catch a glimpse of what he's making; half-admits it's
--                          for someone.
--   80  What I Made You  — the gift. The reward made literal; he's been building it
--                          for you all along.
--
-- Below: schedule-independent TIME-OF-DAY casual lines (morning/midday/evening/night).
-- These are his REAL voice now (rewritten 2026-06-25 against the bio above) — warm with a
-- dry edge that lands WITH the player, never at their expense; earned-rest / weathering /
-- love-made-by-hand threaded through. The old placeholders' taskmaster/scolding tone was
-- removed. Still free to refine, but the voice is the target. vlWalterSay cycles the current
-- bucket (journals/console-commands.md).
--
-- VOICE RULE (2026-06-25): don't have him REBUT an objection the player never raised. Lines like
-- "...not because the land's a tyrant" / "the work's no kind of master" / "I don't say it to flatter
-- you" answer an argument no one's having — it reads as protesting too much / over-explaining his
-- own philosophy. Just let him say the warm thing plainly; trust it to land. (Applies to all villagers.)
--
-- VOICE RULE (zen / dual-level, 2026-06-25): his best tips work on TWO levels — a real FARM observation
-- that the player CAN read as life wisdom, if they choose. Keep it IMPLICIT: give the image/tip, never
-- narrate the lesson ("took me a long time to learn…", "I've made my peace with…"). Let the line sit;
-- it's for the player to enjoy on an existential level, not for Walter to spell out. ALSO: don't
-- pre-spend the emotional story — casual greetings shouldn't confess the weathered-grief depth that the
-- HEART EVENTS are meant to earn. Light surface, deep undercurrent the player discovers.

VLCasualDialogue.register("grandpa", {
    firstMeet = "Look at you — running my farm. Your grandmother would never have believed it. ...Good to have you here, kid.",

    morning = {
        "Mornin', kid. No better hour on a farm than this one — everything still out ahead of you.",
        "Up already? Good. The morning's the best part of the day out here — I'd hate for you to sleep through it.",
        "Coffee's on. Your grandmother always said a day starts the moment you quit dreading it. She was right about most things.",
        "Look at that light coming up over the fields. Forty years I've watched it. Still gets me.",
        "Smells like turned earth and woodsmoke out here. Smells like home. You've kept it that way.",
        "Ground's still got the dew on it. Best time to walk the place — before the day starts asking things of you.",
        "Funny — every morning the place looks like it's forgotten yesterday entirely.",
        "First light's the honest hour. Nothing's gone wrong yet.",
        "Cool morning like this, the work near does itself. ...Don't tell it I said so.",
    },

    midday = {
        "Right in the heart of the day. Don't let me keep you — though I never mind if you do.",
        "Hot one. Find yourself some shade when you need it — the work'll keep.",
        "Half the day behind you already. Time slips by like water out here — you look up and a whole season's gone.",
        "You've got your grandmother's way of never stopping. I'd tell you to rest, but I never listened either.",
        "Whatever you're chasing today, it'll keep. Come find me if you want company on it.",
        "Heat of the day. Animals all know to find some shade and stand still a while. Smart, the animals.",
        "Work goes down easier in pieces than all at once.",
        "Midday's for the steady chores, not the big decisions — save those for when the light's kinder.",
        "A field doing well doesn't ask much of you — just steady attention.",
    },

    evening = {
        "Day's winding down, and you've got dirt to show for it. That's the whole point, kid. Rest is earned — go earn yours.",
        "Sun's low. Reckon we both put in an honest day. Sit a while; the porch is the best seat I own.",
        "You did good today. It's true, and somebody ought to say so.",
        "This is my favorite hour. Work behind you, supper ahead, the light going gold. Hard to want for much more than that.",
        "Close up your evening however you like. No rush from me — the farm sleeps when you do.",
        "Whatever didn't get done today, the field's not going anywhere. Let it keep till morning.",
        "End of a day like this, I just sit and let it be done. Recommend it.",
        "Funny — you only notice a good day around now, when it's nearly spent and nothing's gone wrong.",
        "Look at that fence line in this light. Crooked as sin — and it's held twenty years all the same.",
    },

    night = {
        "Out late, are you? ...No, don't mind me. Some of the best thinking gets done at this hour.",
        "Ought to be resting — but who am I to talk. The farm'll keep till morning, I promise you that much.",
        "Quiet hour, this. I like it — everything's easier to hear once the day goes still. Get some sleep, kid.",
        "Still some light left in you, I see. That's alright. Just don't burn it all in one night.",
        "Your grandmother loved this hour — everything still, the whole place ours. I still feel her in it. ...Listen to me. Off to bed.",
        "Stars are out. We don't ever get to see 'em busy.",
        "Place runs itself fine at night. Good to be reminded it can.",
        "Cooler now — feel that? Whole place kind of exhales after sundown.",
        "Nothing on this farm that won't keep till morning. Go on to bed.",
    },

    -- Spoken only while he's out for the OCCASIONAL night woodshop visit (couldn't sleep).
    -- Delivered by WalterWalker:_maybeGreet when you approach the lit shed — addresses the late
    -- hour directly. Voiced per the bio above: weathering, the grandmother, love made by hand.
    nightWoodshop = {
        "Couldn't sleep. ...Hands get restless when the rest of me wants to quit. Easier to build something than lie there in the dark.",
        "House gets too quiet at this hour. Out here the wood keeps me company — never asks me a thing.",
        "Your grandmother used to come find me out here, nights like this one. ...Some habits outlast the reason for 'em. Go on back to bed, kid.",
    },

    -- Spoken when you greet him out at the COW PEN (his checkingCows route / near the herd). Ambient &
    -- repeatable — the inherited Angus, the quiet of it, and a standing nudge toward Katie. Distinct from
    -- the one-time WalterCowsIntro handoff. Delivered via WalterWalker:_maybeGreet when _nearCowPen().
    cows = {
        "Angus, these. Beef stock — they'll never fill a milk pail, but they're easy keepers.",
        "Come out most days to look 'em over. You learn a herd by watching it a while.",
        "Quiet creatures, cattle. I do some of my best thinking out here with 'em, truth be told.",
        "Three head now. Time was this whole yard was full of cattle — busy days. ...This'll do.",
        "If you mean to keep cattle proper, go and see Katie. She's forgotten more about animals than I ever knew.",
    },

    alreadyTalked = {
        "We've had our visit for today. Go on — I'll keep till tomorrow. I always do.",
        "Said my piece, kid. You know where to find me when you want more of it.",
        "I'm an old man, not a radio — only got so many words in me a day. Off you go.",
    },
})
