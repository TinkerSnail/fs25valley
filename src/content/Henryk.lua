-- Authored heart events for Henryk — "the one who can't let go."
--
-- Henryk, 60s. The farmer whose land borders yours. Defined by relentless
-- work — the farm is how he keeps from sitting still with his grief. Widowed;
-- his son left for the city years ago and rarely calls, which Henryk reads
-- (wrongly) as the boy rejecting everything he built. Distrusts newcomers on
-- reflex, and you are a newcomer who is also on his fence line.
--
-- Voice: gruff, clipped, allergic to thanks and to being caught being kind.
-- Speaks in work and weather. The warmth is real but buried two layers down.
--
-- Four-beat arc (the question: can he open his hands?):
--   20  The Fence Line     — a border dispute he's wrong about and too proud to concede.
--   40  Dawn Repair        — you find him fixing YOUR fence at dawn; he denies it.
--   60  His Father's Way    — he teaches you the old method, the thing he couldn't give his son.
--   80  The Toolbox        — he hands you his father's tools, choosing who carries the work on.
--
-- NOTE: move_npc / camera coordinates are placeholders — tune in the GIANTS Editor.

-- ---------------------------------------------------------------------------
-- Beat 1 (threshold 20) — "The Fence Line"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "henryk_01",
    npcId     = "henryk",
    threshold = 20,
    steps = {
        { type = "move_npc", npcId = "henryk", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: shared fence line
        { type = "camera",   x = 0, y = 2, z = -5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "henryk",
          text = "That post's on my side. Has been since before you could walk. Move your wire back a foot." },
        { type = "dialogue", speaker = "henryk",
          text = "Don't give me the survey. I know this dirt better than any piece of paper does." },
        { type = "dialogue", speaker = "henryk",
          text = "Well? You going to argue, or are you going to fix it?",
          choices = {
            { label = "The survey says it's mine, Henryk.", next = "argue" },
            { label = "Fine. I'll move the wire.",          next = "concede" },
          }
        },
        { type = "end" },
    },
    branches = {
        argue = {
            { type = "dialogue", speaker = "henryk",
              text = "*a long, flat stare* ...Paper. Hmph. We'll see what the paper says when the creek floods that corner." },
            { type = "dialogue", speaker = "henryk",
              text = "You've got more spine than the last one. Doesn't mean you're right. Get off my line." },
            { type = "end" },
        },
        concede = {
            { type = "dialogue", speaker = "henryk",
              text = "*grunts, surprised* ...Huh. Alright then." },
            { type = "dialogue", speaker = "henryk",
              text = "Most newcomers want to win. You wanted to be a neighbor. That's rarer. Don't let it go to your head." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 2 (threshold 40) — "Dawn Repair"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "henryk_02",
    npcId     = "henryk",
    threshold = 40,
    steps = {
        { type = "move_npc", npcId = "henryk", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: player's broken fence, dawn
        { type = "camera",   x = 0, y = 1.9, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "henryk",
          text = "*he's crouched at your fence, hammer in hand; he stands too fast* This isn't what it looks like." },
        { type = "dialogue", speaker = "henryk",
          text = "Your rail was down. A loose rail's how stock gets onto the road and onto the news. I was passing." },
        { type = "dialogue", speaker = "henryk",
          text = "It's not for you. It's for the road. Big difference.",
          choices = {
            { label = "Thank you, Henryk. I mean it.",   next = "thank" },
            { label = "Right. For the road. Understood.", next = "play_along" },
          }
        },
        { type = "end" },
    },
    branches = {
        thank = {
            { type = "dialogue", speaker = "henryk",
              text = "*he won't look at you* Don't. A man fixes a fence, that's all. You'd have done the same." },
            { type = "dialogue", speaker = "henryk",
              text = "...Coffee's on at six if you're up. I don't make it twice." },
            { type = "end" },
        },
        play_along = {
            { type = "dialogue", speaker = "henryk",
              text = "*the corner of his mouth moves — almost* Smart. You're learning how to talk to an old man." },
            { type = "dialogue", speaker = "henryk",
              text = "Coffee's on at six. For the road, naturally." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 3 (threshold 60) — "His Father's Way"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "henryk_03",
    npcId     = "henryk",
    threshold = 60,
    steps = {
        { type = "move_npc", npcId = "henryk", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Henryk's back field
        { type = "camera",   x = 0, y = 1.9, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "henryk",
          text = "You're sowing that corner wrong. Stop. Watch my hands — don't talk, watch." },
        { type = "dialogue", speaker = "henryk",
          text = "My father did it this way. His father before him. You read the wind off the tree line, not off a screen. Like so." },
        { type = "wait", duration = 1.5 },
        { type = "dialogue", speaker = "henryk",
          text = "*quietly* I tried to show my boy this. He wanted the city. Said the old way was dying." },
        { type = "dialogue", speaker = "henryk",
          text = "Maybe it is. But it's not dead while somebody's still doing it. So. Now you know it too. Don't waste it." },
        { type = "end" },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 4 (threshold 80) — "The Toolbox"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "henryk_04",
    npcId     = "henryk",
    threshold = 80,
    steps = {
        { type = "move_npc", npcId = "henryk", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Henryk's workshop
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "henryk",
          text = "*a worn wooden toolbox sits on the bench between you* These were my father's. The handles are worn to his grip. And mine, after." },
        { type = "dialogue", speaker = "henryk",
          text = "I called my son last week. First time in two years. He's coming for the harvest. He's not coming to farm — I know that now. He's coming to see his old man. That's enough. You taught me that's enough." },
        { type = "dialogue", speaker = "henryk",
          text = "So these don't go to him. He'd put them on a shelf. I want them used.",
          choices = {
            { label = "I'll take good care of them.",        next = "accept" },
            { label = "They're yours, Henryk. Keep using them.", next = "decline" },
          }
        },
        { type = "end" },
    },
    branches = {
        accept = {
            { type = "dialogue", speaker = "henryk",
              text = "*he slides the box across the bench, slow* Then they're yours. Wear the handles down. That's how you thank a tool." },
            { type = "dialogue", speaker = "henryk",
              text = "...You're a good neighbor. There. I said it once. Don't make me say it twice." },
            { type = "end" },
        },
        decline = {
            { type = "dialogue", speaker = "henryk",
              text = "*a slow nod, something easing in his shoulders* Stubborn. Good. We'll share them, then. My bench, your hands, when these old ones give out." },
            { type = "dialogue", speaker = "henryk",
              text = "That's better than giving them away, anyhow. Means you'll keep coming round." },
            { type = "end" },
        },
    },
})
