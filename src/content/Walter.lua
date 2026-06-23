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
-- Still PLACEHOLDERS — the voice is warm with a dry edge, NOT gruff; a few current
-- lines tip into taskmaster/scolding and should be softened. Rewrite against the bio
-- above. vlWalterSay cycles the current bucket (journals/console-commands.md).

VLCasualDialogue.register("grandpa", {
    firstMeet = "Look at you — running my farm. Your grandmother would never have believed it. ...Good to have you here, kid.",

    morning = {
        "Up with the sun. Good. The land doesn't wait.",
        "Mornin'. Plenty of daylight to waste, if you're not careful.",
        "Coffee's about the only thing older than me that still works. Get yourself some.",
    },

    midday = {
        "Right in the thick of the day. What do you need?",
        "Don't let the heat make you lazy — I'm watching.",
        "Half the day gone already. Time moves quick out here.",
    },

    evening = {
        "Day's winding down. You did alright.",
        "Sun's getting low. Reckon we both earned a sit.",
        "Get your chores closed up before dark, now.",
    },

    night = {
        "Bit late to be out, isn't it?",
        "Ought to be resting. The farm'll still be here come morning.",
        "Quiet hour, this. I like it. Don't tell anyone.",
    },

    -- Spoken only while he's out for the OCCASIONAL night woodshop visit (couldn't sleep).
    -- Delivered by WalterWalker:_maybeGreet when you approach the lit shed — addresses the late
    -- hour directly. Voiced per the bio above: weathering, the grandmother, love made by hand.
    nightWoodshop = {
        "Couldn't sleep. ...Hands get restless when the rest of me wants to quit. Easier to build something than lie there in the dark.",
        "House gets too quiet at this hour. Out here the wood keeps me company — never asks me a thing.",
        "Your grandmother used to come find me out here, nights like this one. ...Some habits outlast the reason for 'em. Go on back to bed, kid.",
    },

    alreadyTalked = {
        "We've said our piece today. Go on — work won't do itself.",
        "Told you what I know. Get back to it.",
    },
})
