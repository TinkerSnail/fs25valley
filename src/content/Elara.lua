-- Authored heart events for Elara — "the one deciding whether to stay."
--
-- Elara, late 20s. Runs the roadside produce stand at the edge of Elmcreek.
-- Left a burned-out design career in the city; tells everyone the move is
-- permanent, but keeps a sketchbook she won't show anyone and a half-packed
-- suitcase under her bed. The player's first and most accessible relationship,
-- and the ONLY romanceable villager — romance is a branch inside her beat 4,
-- not a separate meter.
--
-- Four-beat arc, one event per relationship threshold:
--   20  The Sketchbook at Dusk   — caught drawing the fields; she deflects.
--   40  The Numbers Don't Work   — admits the stand is failing; the city calls.
--   60  What's In the Book       — shows the sketchbook: it's all Elmcreek.
--   80  The Suitcase             — she unpacks. Branch: stay as friends / stay for you.
--
-- NOTE: move_npc / camera coordinates below are placeholders. Tune them in the
-- GIANTS Editor against Elmcreek once VLConfig.VILLAGER_SPAWNS.elara is filled in;
-- the dialogue is the authored content and does not depend on exact coords.

-- ---------------------------------------------------------------------------
-- Beat 1 (threshold 20) — "The Sketchbook at Dusk"  [VERTICAL SLICE]
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "elara_01",
    npcId     = "elara",
    threshold = 20,
    steps = {
        { type = "move_npc", npcId = "elara", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: field-edge mark
        { type = "camera",   x = 0, y = 2, z = -5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "elara",
          text = "Oh — hey. You're quiet for a big farmer type." },
        { type = "dialogue", speaker = "elara",
          text = "*she closes a little book against her knee, too fast* It's nothing. Just... watching the light go." },

        { type = "dialogue", speaker = "elara",
          text = "What was that you just shut?",
          choices = {
            { label = "What were you drawing?", next = "curious" },
            { label = "Sorry — didn't mean to pry.", next = "polite" },
          }
        },
        -- (unreached: a choice always jumps to a branch)
        { type = "end" },
    },
    branches = {
        curious = {
            { type = "dialogue", speaker = "elara",
              text = "Drawing? Who said anything about drawing. *a beat* ...The fields. The way the rows go gold right before dark." },
            { type = "dialogue", speaker = "elara",
              text = "Don't make it a thing. City habit I haven't shaken. It'll pass." },
            { type = "dialogue", speaker = "elara",
              text = "Go on, your cows miss you. I'll see you around, farmer." },
            { type = "end" },
        },
        polite = {
            { type = "dialogue", speaker = "elara",
              text = "*she relaxes a little* You're alright, you know that? Most folks would've grabbed for it." },
            { type = "dialogue", speaker = "elara",
              text = "It really is nothing. Old habit. Come buy something tomorrow and we'll call it even." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 2 (threshold 40) — "The Numbers Don't Work"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "elara_02",
    npcId     = "elara",
    threshold = 40,
    steps = {
        { type = "move_npc", npcId = "elara", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: the produce stand
        { type = "camera",   x = 0, y = 2, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "elara",
          text = "You caught me doing the thing I hate. Math. *taps a ledger* The stand doesn't work, by the way." },
        { type = "dialogue", speaker = "elara",
          text = "Not 'bad week' doesn't work. 'Doesn't work' doesn't work. There's a number in the city with my name next to it and it's a lot bigger than this one." },
        { type = "dialogue", speaker = "elara",
          text = "Why am I telling you this. *laughs* Because you don't say much. It's restful. And because you'd get it — you came back for your grandad's farm when your own dad ran the other way. I bolted from the city. Different roads, same stubborn hunt for a place that fits." },
        { type = "dialogue", speaker = "elara",
          text = "So. Be honest with a fellow transplant.",
          choices = {
            { label = "Then stay and make this one bigger.", next = "encourage" },
            { label = "Maybe the city's the right call.",    next = "honest" },
          }
        },
        { type = "end" },
    },
    branches = {
        encourage = {
            { type = "dialogue", speaker = "elara",
              text = "*she looks at you a second too long* ...You actually mean that. Huh." },
            { type = "dialogue", speaker = "elara",
              text = "Okay. One more season. I'm holding you to noticing if it works." },
            { type = "end" },
        },
        honest = {
            { type = "dialogue", speaker = "elara",
              text = "Yeah. That's the sensible read. *quieter* I wanted you to argue, a little. Isn't that stupid." },
            { type = "dialogue", speaker = "elara",
              text = "Forget I said it. See you tomorrow, farmer." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 3 (threshold 60) — "What's In the Book"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "elara_03",
    npcId     = "elara",
    threshold = 60,
    steps = {
        { type = "move_npc", npcId = "elara", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: creek bank
        { type = "camera",   x = 0, y = 2, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "elara",
          text = "Sit. I'm going to do something I'll regret. *she sets the sketchbook in your hands*" },
        { type = "dialogue", speaker = "elara",
          text = "Go ahead. Open it." },
        { type = "wait", duration = 1.5 },
        { type = "dialogue", speaker = "elara",
          text = "It's all here. The creek. Henryk's crooked fence. The market at six a.m. Your barn, twice." },
        { type = "dialogue", speaker = "elara",
          text = "I told myself I was sketching to remember the city. I haven't drawn the city in a year. I've been drawing home and pretending I didn't notice." },
        { type = "dialogue", speaker = "elara",
          text = "*she takes the book back gently* Don't say anything wise. Just... thanks for looking." },
        { type = "end" },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 4 (threshold 80) — "The Suitcase"   [romance branch lives here]
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "elara_04",
    npcId     = "elara",
    threshold = 80,
    steps = {
        { type = "move_npc", npcId = "elara", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Elara's porch
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "elara",
          text = "I unpacked the suitcase. The one under the bed. *she exhales* It's just a suitcase now. Empty." },
        { type = "dialogue", speaker = "elara",
          text = "I'm staying. For real this time. And I figured you should be the first to know, because you're the reason it stopped being a question." },
        { type = "dialogue", speaker = "elara",
          text = "So I have to ask you something, and you get to decide what kind of thing it is.",
          choices = {
            { label = "I'm glad you're staying. I've got your back.", next = "friends" },
            { label = "Stay. And let it be the other kind of thing.", next = "romance" },
          }
        },
        { type = "end" },
    },
    branches = {
        friends = {
            { type = "dialogue", speaker = "elara",
              text = "*she grins, and there's relief in it* Good. A friend who shows up. That's the whole game out here, isn't it." },
            { type = "dialogue", speaker = "elara",
              text = "Come on. First round of staying-in-Elmcreek coffee is on the failing produce stand." },
            { type = "end" },
        },
        romance = {
            { type = "dialogue", speaker = "elara",
              text = "*a long quiet, then a smile she doesn't fight* ...Yeah. Okay. The other kind of thing." },
            { type = "dialogue", speaker = "elara",
              text = "I was so sure this place was a waiting room. Turns out it was the destination. *softly* Turns out you were." },
            { type = "end" },
        },
    },
})
