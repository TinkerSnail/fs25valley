-- Authored heart events for Marta — "the one who holds everyone but is held by no one."
--
-- Marta, 40s-50s. Runs the general store / diner — the town's social hub and
-- information broker; organizes every Riverbend Springs event. Warm, maternal, generous
-- to a fault, won't accept thanks. Everyone's confidante, nobody's priority:
-- she keeps the whole community together and lives small and alone in the back
-- room behind all that warmth. The loneliness of the connector.
--
-- As the town's connective tissue, her arc ties the cast together — her finale
-- is the one scene that can put the newcomer (Elara) and the elder (Henryk) in
-- the same room.
--
-- Four-beat arc (the question: who takes care of the caretaker?):
--   20  On the House       — she over-helps you and refuses to be thanked.
--   40  The Back Room      — you glimpse the small, solitary life behind the store.
--   60  When It Falls Apart — her town event collapses and YOU step in for her.
--   80  Her Turn           — she lets you throw HER a celebration, and it gathers the valley.
--
-- NOTE: move_npc / camera coordinates are placeholders — tune in the GIANTS Editor.

-- ---------------------------------------------------------------------------
-- Beat 1 (threshold 20) — "On the House"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_01",
    npcId     = "marta",
    threshold = 20,
    steps = {
        { type = "move_npc", npcId = "marta", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: store counter
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "Oh, you look half-starved, sweetheart. Sit. No, sit — I've already got a plate coming. Don't argue with me, I run a diner." },
        { type = "dialogue", speaker = "marta",
          text = "And it's on the house. New folks eat free their first season. House rule." },
        { type = "dialogue", speaker = "marta",
          text = "You're Walter's grandkid, aren't you — taking over his farm. Oh, that man used to sit right there and talk about you. Lit up like a porch lamp. He's so proud it's you keeping it in the family." },
        { type = "dialogue", speaker = "marta",
          text = "Don't you dare reach for that wallet.",
          choices = {
            { label = "At least let me pay you back somehow.", next = "repay" },
            { label = "Thank you, Marta. That's kind.",        next = "accept" },
          }
        },
        { type = "end" },
    },
    branches = {
        repay = {
            { type = "dialogue", speaker = "marta",
              text = "Pay me back? Goodness. *she waves it off* You'll pass it along to the next lost soul who wanders in. That's the only ledger I keep." },
            { type = "dialogue", speaker = "marta",
              text = "Now eat before it gets cold. I didn't fuss over that for nothing." },
            { type = "end" },
        },
        accept = {
            { type = "dialogue", speaker = "marta",
              text = "*she beams, genuinely pleased* There. Was that so hard? Most folks fight me on it." },
            { type = "dialogue", speaker = "marta",
              text = "You're going to do just fine here. I can always tell. Now — eat." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 2 (threshold 40) — "The Back Room"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_02",
    npcId     = "marta",
    threshold = 40,
    steps = {
        { type = "move_npc", npcId = "marta", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: back room doorway
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "Oh — you weren't supposed to see back here. *she steps half in front of the doorway* It's nothing. Just where I sleep." },
        { type = "dialogue", speaker = "marta",
          text = "A cot, a kettle, one chair. Doesn't take much when it's only you. The store's the big room; this is plenty." },
        { type = "dialogue", speaker = "marta",
          text = "*a small laugh that doesn't quite land* Listen to me. Everyone's got their whole life out front and I've got mine in a closet. Don't mind me.",
          choices = {
            { label = "One chair's a lonely number, Marta.", next = "gentle" },
            { label = "It suits you. Cozy.",                  next = "light" },
          }
        },
        { type = "end" },
    },
    branches = {
        gentle = {
            { type = "dialogue", speaker = "marta",
              text = "*the brightness slips for just a second* ...It is. Some nights it's very lonely. I don't say that out loud, usually." },
            { type = "dialogue", speaker = "marta",
              text = "Don't worry about me, sweetheart. I worry about the whole town — somebody has to. Go on, before I get maudlin." },
            { type = "end" },
        },
        light = {
            { type = "dialogue", speaker = "marta",
              text = "*she takes the kindness in the spirit it's offered* Cozy. Yes. Let's call it cozy." },
            { type = "dialogue", speaker = "marta",
              text = "You're sweet to a tired woman. Off you go — I've got a town to feed." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 3 (threshold 60) — "When It Falls Apart"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_03",
    npcId     = "marta",
    threshold = 60,
    steps = {
        { type = "move_npc", npcId = "marta", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: town square, harvest fair setup
        { type = "camera",   x = 0, y = 1.9, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "*she's surrounded by half-built fair stalls, flour on her sleeve, near tears and hiding it* The caterer cancelled. The bunting's tangled. And I'm one woman, and the fair is tonight." },
        { type = "dialogue", speaker = "marta",
          text = "I always manage. I'll manage. I just — *her voice catches* — I just need a minute where nobody needs anything from me." },
        { type = "dialogue", speaker = "marta",
          text = "I'm sorry. You shouldn't see me like this. Forget you did.",
          choices = {
            { label = "Sit down. I've got the stalls — tell me what goes where.", next = "step_in" },
            { label = "Then take the minute. I'll hold the fort.",                next = "relieve" },
          }
        },
        { type = "end" },
    },
    branches = {
        step_in = {
            { type = "dialogue", speaker = "marta",
              text = "*she stares at you like the words don't compute* You'd... but the fair isn't yours to fix." },
            { type = "dialogue", speaker = "marta",
              text = "*and then, slowly, she lets you take the hammer* ...Bunting on the left. Bless you. Nobody's ever just — taken it from my hands before." },
            { type = "end" },
        },
        relieve = {
            { type = "dialogue", speaker = "marta",
              text = "*she sits, finally, and breathes like she hasn't all day* A minute. Just one. Then I'm back." },
            { type = "dialogue", speaker = "marta",
              text = "*quietly* Thank you. Not for the fair. For seeing that I needed to sit down. Henryk would've walked right past. Elara wouldn't have noticed. You did." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 4 (threshold 80) — "Her Turn"   [the cast converges here]
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_04",
    npcId     = "marta",
    threshold = 80,
    steps = {
        -- The convergence scene: Marta, and off to the side, Elara and Henryk.
        { type = "move_npc", npcId = "marta",  x = 0, y = 0, z = 0, ry = 0 },  -- TODO: diner, decorated
        { type = "move_npc", npcId = "elara",  x = 2, y = 0, z = 0, ry = 0 },  -- TODO: stage left
        { type = "move_npc", npcId = "henryk", x = -2, y = 0, z = 0, ry = 0 }, -- TODO: stage right, awkward
        { type = "camera",   x = 0, y = 2, z = -5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "What is — *she stops in her own doorway* — the lights are mine. The good plates are out. Is that... my name on the bunting?" },
        { type = "dialogue", speaker = "elara",
          text = "Don't look at me, I just hung what they handed me. *grinning* Okay, I drew the banner. Fine." },
        { type = "dialogue", speaker = "henryk",
          text = "*gruffly, holding a covered dish, deeply uncomfortable and entirely present* Brought a pie. My wife's recipe. Don't make a thing of it." },
        { type = "dialogue", speaker = "marta",
          text = "*she presses a hand to her mouth* You got Henryk out of his field. And Elara to stand still for ten minutes. For me. I throw the parties. Nobody throws them for me." },
        { type = "dialogue", speaker = "marta",
          text = "*to you, eyes shining* This is your doing. You found the thread that runs through all of us and you... pulled us into one room.",
          choices = {
            { label = "You hold this whole town together. Tonight it holds you.", next = "warm" },
            { label = "Everyone here just wanted to thank you. I only set the date.", next = "humble" },
          }
        },
        { type = "end" },
    },
    branches = {
        warm = {
            { type = "dialogue", speaker = "marta",
              text = "*she laughs and cries at once* Sit me down before I fall down. And somebody cut Henryk's pie before he changes his mind about staying." },
            { type = "dialogue", speaker = "henryk",
              text = "I heard that. *a pause* ...It's a good pie. Sit, Marta. We've got you tonight." },
            { type = "end" },
        },
        humble = {
            { type = "dialogue", speaker = "marta",
              text = "Only set the date. *she shakes her head, smiling* That's the most anyone's done for me in twenty years, and you'll call it nothing. You and Henryk, two of a kind." },
            { type = "dialogue", speaker = "elara",
              text = "Alright, enough — the food's getting cold and the connector finally gets to sit at her own table. Marta. The head seat's yours." },
            { type = "end" },
        },
    },
})
