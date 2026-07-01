-- Authored heart events for Marta - "the one who holds everyone but is held by no one."
--
-- Marta, 40s-50s. Runs the Farmer's Market in Riverbend Springs - the walk-in
-- market with the empty crates until locals supply it - plus the sunflower farm
-- out back that she works herself. Market floor out front, sunflower rows behind,
-- and a back room where she actually lives. Warm, maternal, generous to a
-- fault; always recruiting one more farmer to fill a shelf. Won't accept thanks.
-- Everyone's confidante, nobody's priority: she keeps the whole community
-- together and lives small and alone behind all that warmth.
--
-- Mod fiction: Marta IS the market. Base-game David (FARMER) lives nearby and
-- takes vanilla harvest contracts; he is a neighbor farmer, not the shopkeeper.
-- The orange-shirt ambience NPCs inside the building stay decoration; Marta is
-- who you talk to.
--
-- As the town's connective tissue, her arc ties the cast together - her finale
-- is the one scene that can put the newcomer (Elara) and the elder (Kenji) in
-- the same room.
--
-- Four-beat arc (the question: who takes care of the caretaker?):
--   20  On the House       - she over-helps you and refuses to be thanked.
--   40  The Back Room      - you glimpse the small, solitary life behind the store.
--   60  When It Falls Apart - her town event collapses and YOU step in for her.
--   80  Her Turn           - she lets you throw HER a celebration, and it gathers the valley.
--
-- NOTE: move_npc / camera coordinates are placeholders - tune in the GIANTS Editor.

-- ---------------------------------------------------------------------------
-- Beat 1 (threshold 20) - "On the House"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_01",
    npcId     = "marta",
    threshold = 20,
    steps = {
        { type = "move_npc", npcId = "marta", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Farmer's Market floor / stall
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "Oh, you look half-starved, sweetheart. Sit. No, sit, I've already got a plate made up for you in back. Don't argue with me, I run this market." },
        { type = "dialogue", speaker = "marta",
          text = "And it's on the house. New folks eat free their first season. House rule. *she glances at the empty crates* Same rule for anyone who helps me fill a shelf." },
        { type = "dialogue", speaker = "marta",
          text = "You're Walter's grandkid, aren't you, taking over his farm. Oh, that man used to sit right there and talk about you. Lit up like a porch lamp. He's so proud it's you keeping it in the family." },
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
              text = "Pay me back? Goodness. *she waves it off* Bring me something from your fields and put it out front. That's the only ledger I keep." },
            { type = "dialogue", speaker = "marta",
              text = "Now eat before it gets cold. I didn't fuss over that for nothing." },
            { type = "end" },
        },
        accept = {
            { type = "dialogue", speaker = "marta",
              text = "*she beams, genuinely pleased* There. Was that so hard? Most folks fight me on it." },
            { type = "dialogue", speaker = "marta",
              text = "You're going to do just fine here. I can always tell. Now, eat." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 2 (threshold 40) - "The Back Room"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_02",
    npcId     = "marta",
    threshold = 40,
    steps = {
        { type = "move_npc", npcId = "marta", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: back room doorway
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "Oh, you weren't supposed to see back here. *she steps half in front of the doorway* It's nothing. Just where I sleep." },
        { type = "dialogue", speaker = "marta",
          text = "A cot, a kettle, one chair. Doesn't take much when it's only you. The market floor's the big room; this is plenty." },
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
              text = "Don't worry about me, sweetheart. I worry about the whole town; somebody has to. Go on, before I get maudlin." },
            { type = "end" },
        },
        light = {
            { type = "dialogue", speaker = "marta",
              text = "*she takes the kindness in the spirit it's offered* Cozy. Yes. Let's call it cozy." },
            { type = "dialogue", speaker = "marta",
              text = "You're sweet to a tired woman. Off you go; I've got a town to feed." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 3 (threshold 60) - "When It Falls Apart"
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
          text = "I always manage. I'll manage. I just, *her voice catches*, I just need a minute where nobody needs anything from me." },
        { type = "dialogue", speaker = "marta",
          text = "I'm sorry. You shouldn't see me like this. Forget you did.",
          choices = {
            { label = "Sit down. I've got the stalls; tell me what goes where.", next = "step_in" },
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
              text = "*and then, slowly, she lets you take the hammer* ...Bunting on the left. Bless you. Nobody's ever just, taken it from my hands before." },
            { type = "end" },
        },
        relieve = {
            { type = "dialogue", speaker = "marta",
              text = "*she sits, finally, and breathes like she hasn't all day* A minute. Just one. Then I'm back." },
            { type = "dialogue", speaker = "marta",
              text = "*quietly* Thank you. Not for the fair. For seeing that I needed to sit down. Kenji would've walked right past. Elara wouldn't have noticed. You did." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 4 (threshold 80) - "Her Turn"   [the cast converges here]
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "marta_04",
    npcId     = "marta",
    threshold = 80,
    steps = {
        -- The convergence scene: Marta, and off to the side, Elara and Kenji.
        { type = "move_npc", npcId = "marta",  x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Farmer's Market, decorated for the party
        { type = "move_npc", npcId = "elara",  x = 2, y = 0, z = 0, ry = 0 },  -- TODO: stage left
        { type = "move_npc", npcId = "kenji", x = -2, y = 0, z = 0, ry = 0 }, -- TODO: stage right, awkward
        { type = "camera",   x = 0, y = 2, z = -5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "marta",
          text = "What is, *she stops in her own doorway*, the lights are mine. The good plates are out. Is that... my name on the bunting?" },
        { type = "dialogue", speaker = "elara",
          text = "Don't look at me, I just hung what they handed me. *grinning* Okay, I drew the banner. Fine." },
        { type = "dialogue", speaker = "kenji",
          text = "*gruffly, holding a covered dish, deeply uncomfortable and entirely present* Brought a pie. My wife's recipe. Don't make a thing of it." },
        { type = "dialogue", speaker = "marta",
          text = "*she presses a hand to her mouth* You got Kenji out of his field. And Elara to stand still for ten minutes. For me. I throw the parties. Nobody throws them for me." },
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
              text = "*she laughs and cries at once* Sit me down before I fall down. And somebody cut Kenji's pie before he changes his mind about staying." },
            { type = "dialogue", speaker = "kenji",
              text = "I heard that. *a pause* ...It's a good pie. Sit, Marta. We've got you tonight." },
            { type = "end" },
        },
        humble = {
            { type = "dialogue", speaker = "marta",
              text = "Only set the date. *she shakes her head, smiling* That's the most anyone's done for me in twenty years, and you'll call it nothing. You and Kenji, two of a kind." },
            { type = "dialogue", speaker = "elara",
              text = "Alright, enough, the food's getting cold and the connector finally gets to sit at her own table. Marta. The head seat's yours." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Daily greetings (Press R when no heart event is pending)
-- ---------------------------------------------------------------------------
VLCasualDialogue.register("marta", {
    firstMeet = "Well, look who wandered in. Walter's grandkid, isn't it; I'm Marta. I run the Farmer's Market, and the sunflower farm out back that keeps it in oil. Shelves are out front, and they're embarrassingly empty. If you're taking over his farm, sweetheart, we should talk about that.",

    stranger = {
        "Morning, sweetheart. Coffee's on in the back if you need it.",
        "See those empty crates? That's a invitation, not a decoration. Bring me something worth putting on a shelf.",
        "David's neighbor farm keeps him busy, bless him, but one man can't feed a whole market.",
        "You're up with the sun. Good. The market opens whether the shelves are full or not.",
        "Don't skip meals. I can tell when someone does. I keep a plate warm for regulars.",
    },

    acquaintance = {
        "There you are. I saved you a biscuit, payment in advance for your first delivery.",
        "You're settling in. Good. Walter would be pleased. The market could use a steady supplier too.",
        "Kenji came through grumbling this morning. That means he likes you. He still won't sell me a tomato.",
        "Elara mentioned you stopped at her stand. Buy from her, then bring me whatever she doesn't move. Everybody wins.",
    },

    friend = {
        "Sit a minute. You look like you could use a break from all that empty shelf guilt I keep handing out.",
        "I'm fine, I'm fine, but thank you for asking. The market's not fine. Same conversation.",
        "Town's quiet today. Too quiet. Empty crates echo, you know.",
        "You don't have to pay me back. Bring me produce. That's better than money out here.",
    },

    goodFriend = {
        "Back room's a mess, but the front's open. Story of my life.",
        "You showed up when I needed it. I haven't forgotten. Next time the shelves look bare, I might ask.",
        "Someone has to hold this town together. Might as well be me, and my suppliers.",
        "Sweetheart, when's the last time you drove a load to the market unload? Just asking. Gently.",
    },

    closeFriend = {
        "Best thing that happened to this valley was you staying, and the days you actually fill a crate.",
        "I got sat down at my own table once. Still thinking about it. The shelves looked fuller that week.",
        "You found the thread that runs through all of us. Don't stop pulling. The market needs the tug.",
    },

    alreadyTalked = {
        "We already talked today, sweetheart. Go farm something for my shelves.",
        "I'm still out among the sunflowers. Crates still empty. No rush. Some rush.",
        "Save it for tomorrow; I'll have fresh gossip and hopefully fresh produce.",
    },

    afterEvent = {
        marta_01 = {
            "Still on the house, by the way. House rule. Shelves still need filling, though.",
            "Don't you dare reach for that wallet in here. Bring me a crate instead.",
        },
        marta_02 = {
            "Back room's still small. But it's mine. Market floor's still too big for one woman.",
        },
        marta_03 = {
            "Next town event's on me. ...Mostly on me. You already know I'll ask you to haul something.",
        },
    },
})
