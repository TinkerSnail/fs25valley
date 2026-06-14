-- Authored heart events for Henryk — "the one who can't let go."
--
-- Henryk, 60s. The farmer whose land borders yours. Defined by relentless
-- work — the farm is how he keeps from sitting still with his grief. Widowed.
-- His son is away at university (grad school) in the city; the boy isn't
-- estranged, but Henryk has quietly decided that once the degree's done he'll
-- never come home — so he grieves a loss that hasn't actually happened yet.
-- Distrusts newcomers on reflex, and you are a newcomer on his fence line.
--
-- FUTURE ARC (not built yet — seed planted in beat 4): as the town comes back
-- to life — younger people choosing to stay, and that softening Henryk himself —
-- the son is heartened, and his return shifts from "never" to genuinely
-- uncertain. A later beat could pay off the son actually coming home for good.
--
-- Voice: gruff, clipped, allergic to thanks and to being caught being kind.
-- Speaks in work and weather. The warmth is real but buried two layers down.
--
-- THROUGHLINE — the carpetbagger fear: everyone Henryk loves leaves the land
-- (his son, and Walter's son = your father). So his real suspicion isn't that
-- you're new, it's that you're a carpetbagger: an outsider who'll prettify
-- Walter's farm, flip it, and vanish — proving him right about the world again.
-- His arc is him slowly, grudgingly accepting that you actually mean to STAY.
--
-- Four-beat arc (the question: can he open his hands?):
--   20  The Fence Line     — names you a carpetbagger to your face; tests whether you'll bolt.
--   40  Dawn Repair        — fixes YOUR fence at dawn, but still asks if you'll sell out come spring.
--   60  His Father's Way    — teaches the old way; a flipper would never bother to learn it. The turn.
--   80  The Toolbox        — names the fear, retracts it, and calls his own son. You stayed; so can the boy.
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
          text = "I knew your grandfather. Walter and I farmed these two plots side by side the better part of forty years. My own boy's off at the university in the city — grad school now — and the way these things go, that's the last the land'll see of him. And yet here's Walter's grandkid, putting the old place back together." },
        { type = "dialogue", speaker = "henryk",
          text = "Or so it looks. I've seen your kind, friend. Inherit a place you never bled for, slap fresh paint on the barn, sell the lot to some development outfit, and you're gone before first frost. Carpetbagger. So no — you don't get an inch of my line on a smile." },
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
              text = "A man looking to flip a property fights for every square foot to pad the price. You just gave ground to keep the peace. That's not nothing. Doesn't mean I trust you yet — but it's not nothing." },
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
          text = "It's not for you. It's for the road. Big difference." },
        { type = "dialogue", speaker = "henryk",
          text = "Land doesn't care whose name's on the deed. I keep it right whether you stay or sell it out from under all of us come spring. *a beat, not quite casual* ...You planning to sell out come spring?",
          choices = {
            { label = "I'm not going anywhere, Henryk.",   next = "thank" },
            { label = "Right. For the road. Understood.",  next = "play_along" },
          }
        },
        { type = "end" },
    },
    branches = {
        thank = {
            { type = "dialogue", speaker = "henryk",
              text = "*he won't look at you* ...Plenty of folks aren't going anywhere, right up until they go. We'll see what you are come spring." },
            { type = "dialogue", speaker = "henryk",
              text = "A man fixes a fence, that's all. ...Coffee's on at six if you're up. I don't make it twice." },
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
          text = "*quietly* I tried to show my boy this once. He's off at university — screens and spreadsheets now. Said the old way was dying. I figure once he's got that degree, that's the last of him." },
        { type = "dialogue", speaker = "henryk",
          text = "Here's the thing that's been nagging me. A carpetbagger doesn't learn the wind. Takes years to pay off — no use to a man who's selling. But you keep turning up to learn it anyway." },
        { type = "dialogue", speaker = "henryk",
          text = "Maybe it's dying. But it's not dead while somebody's still doing it. So — now you know it too. *a long look* Maybe I had you wrong. Don't waste it." },
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
          text = "First day, I called you a carpetbagger to your face. Figured you'd paint Walter's barn and flip it by autumn. *he shakes his head* You're still here. Survived a spring. Then another. You stayed." },
        { type = "dialogue", speaker = "henryk",
          text = "And it got me thinking — if a stranger can come back to the land, maybe a son can too. I called my boy last week. First in a long while. He's coming for the harvest." },
        { type = "dialogue", speaker = "henryk",
          text = "He sounded... lighter. Said he'd heard the town had young blood in it again — folks your age not giving up on the place. Said maybe it isn't the dead end he'd made it out to be. *gruffly, hiding hope* We'll see. He's coming to see his old man, that's enough. You taught me that's enough." },
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
