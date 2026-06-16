-- Authored heart events for Kenji - "the one who can't let go."
--
-- Kenji, 60s. The farmer whose land borders yours. Defined by relentless
-- work - the farm is how he keeps from sitting still with his grief. Widowed.
--
-- The son - a LAYERED REVEAL (you only learn the truth as you earn his trust):
--   * Guarded version (beat 1): "off at grad school, gone for good." Sounds
--     like distance and a chosen career.
--   * The wound (beat 3): the resentment is really INSECURITY. Kenji fears the
--     boy's leaving is a rejection not just of the farm but of HIM - that all
--     that schooling taught his son to see his father as a dumb country bumpkin.
--     The constant fighting has meant the son never got to give his side.
--   * The truth (beat 4): the opposite is true. The son deeply respects his dad
--     and went to school to make farming SAFER and more effective for people
--     like Kenji. He can't do that work from the hometown yet, so he had to
--     leave to do it - and he's desperately seeking a balance between city and
--     countryside, a life that doesn't cut off his roots. Kenji had it backwards.
-- Flaw: resentment born of insecurity. Arc: he sets it down and finally listens.
--
-- FUTURE ARC: the son could become a present NPC/beat - home for the harvest,
-- the city/countryside-balance theme paying off as the revived town gives him a
-- way to finally do his work closer to home.
--
-- Voice: gruff, clipped, allergic to thanks and to being caught being kind.
-- Speaks in work and weather. The warmth is real but buried two layers down.
--
-- THROUGHLINE - the carpetbagger fear: everyone Kenji loves leaves the land
-- (his son, and Walter's son = your father). So his real suspicion isn't that
-- you're new, it's that you're a carpetbagger: an outsider who'll prettify
-- Walter's farm, flip it, and vanish - proving him right about the world again.
-- His arc is him slowly, grudgingly accepting that you actually mean to STAY.
--
-- Four-beat arc (the question: can he open his hands?):
--   20  The Fence Line     - names you a carpetbagger to your face; tests whether you'll bolt.
--   40  Dawn Repair        - fixes YOUR fence at dawn, but still asks if you'll sell out come spring.
--   60  His Father's Way    - teaches the old way; a flipper would never bother to learn it. The turn.
--   80  The Toolbox        - names the fear, retracts it, and calls his own son. You stayed; so can the boy.
--
-- NOTE: move_npc / camera coordinates are placeholders - tune in the GIANTS Editor.

-- ---------------------------------------------------------------------------
-- Beat 1 (threshold 20) - "The Fence Line"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "kenji_01",
    npcId     = "kenji",
    threshold = 20,
    steps = {
        { type = "move_npc", npcId = "kenji", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: shared fence line
        { type = "camera",   x = 0, y = 2, z = -5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "kenji",
          text = "That post's on my side. Has been since before you could walk. Move your wire back a foot." },
        { type = "dialogue", speaker = "kenji",
          text = "I knew your grandfather. Walter and I farmed these two plots side by side the better part of forty years. My own boy's off at the university in the city - grad school now - and the way these things go, that's the last the land'll see of him. And yet here's Walter's grandkid, putting the old place back together." },
        { type = "dialogue", speaker = "kenji",
          text = "Or so it looks. I've seen your kind, friend. Inherit a place you never bled for, slap fresh paint on the barn, sell the lot to some development outfit, and you're gone before first frost. Carpetbagger. So no - you don't get an inch of my line on a smile." },
        { type = "dialogue", speaker = "kenji",
          text = "Don't give me the survey. I know this dirt better than any piece of paper does." },
        { type = "dialogue", speaker = "kenji",
          text = "Well? You going to argue, or are you going to fix it?",
          choices = {
            { label = "The survey says it's mine, Kenji.", next = "argue" },
            { label = "Fine. I'll move the wire.",          next = "concede" },
          }
        },
        { type = "end" },
    },
    branches = {
        argue = {
            { type = "dialogue", speaker = "kenji",
              text = "*a long, flat stare* ...Paper. Hmph. We'll see what the paper says when the creek floods that corner." },
            { type = "dialogue", speaker = "kenji",
              text = "You've got more spine than the last one. Doesn't mean you're right. Get off my line." },
            { type = "end" },
        },
        concede = {
            { type = "dialogue", speaker = "kenji",
              text = "*grunts, surprised* ...Huh. Alright then." },
            { type = "dialogue", speaker = "kenji",
              text = "A man looking to flip a property fights for every square foot to pad the price. You just gave ground to keep the peace. That's not nothing. Doesn't mean I trust you yet - but it's not nothing." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 2 (threshold 40) - "Dawn Repair"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "kenji_02",
    npcId     = "kenji",
    threshold = 40,
    steps = {
        { type = "move_npc", npcId = "kenji", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: player's broken fence, dawn
        { type = "camera",   x = 0, y = 1.9, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "kenji",
          text = "*he's crouched at your fence, hammer in hand; he stands too fast* This isn't what it looks like." },
        { type = "dialogue", speaker = "kenji",
          text = "Your rail was down. A loose rail's how stock gets onto the road and onto the news. I was passing." },
        { type = "dialogue", speaker = "kenji",
          text = "It's not for you. It's for the road. Big difference." },
        { type = "dialogue", speaker = "kenji",
          text = "Land doesn't care whose name's on the deed. I keep it right whether you stay or sell it out from under all of us come spring. *a beat, not quite casual* ...You planning to sell out come spring?",
          choices = {
            { label = "I'm not going anywhere, Kenji.",   next = "thank" },
            { label = "Right. For the road. Understood.",  next = "play_along" },
          }
        },
        { type = "end" },
    },
    branches = {
        thank = {
            { type = "dialogue", speaker = "kenji",
              text = "*he won't look at you* ...Plenty of folks aren't going anywhere, right up until they go. We'll see what you are come spring." },
            { type = "dialogue", speaker = "kenji",
              text = "A man fixes a fence, that's all. ...Coffee's on at six if you're up. I don't make it twice." },
            { type = "end" },
        },
        play_along = {
            { type = "dialogue", speaker = "kenji",
              text = "*the corner of his mouth moves - almost* Smart. You're learning how to talk to an old man." },
            { type = "dialogue", speaker = "kenji",
              text = "Coffee's on at six. For the road, naturally." },
            { type = "end" },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 3 (threshold 60) - "His Father's Way"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "kenji_03",
    npcId     = "kenji",
    threshold = 60,
    steps = {
        { type = "move_npc", npcId = "kenji", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Kenji's back field
        { type = "camera",   x = 0, y = 1.9, z = -4.5, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "kenji",
          text = "You're sowing that corner wrong. Stop. Watch my hands - don't talk, watch." },
        { type = "dialogue", speaker = "kenji",
          text = "My father did it this way. His father before him. You read the wind off the tree line, not off a screen. Like so." },
        { type = "wait", duration = 1.5 },
        { type = "dialogue", speaker = "kenji",
          text = "*quietly* I tried to show my boy this once. He's off at university - screens and spreadsheets now. Said the old way was dying." },
        { type = "dialogue", speaker = "kenji",
          text = "*longer pause* ...That's the tidy version, the one I tell folks. Truth is, I couldn't stomach it - a boy of mine picking a desk and a degree over this dirt. And I let him know it. Every call, he heard it." },
        { type = "dialogue", speaker = "kenji",
          text = "And underneath that - the part I don't say out loud - I'm scared it's not the farm he's turning his back on. It's me. That all that book learning taught him his old man's just a dumb dirt-grubber who never read a thing worth reading. That he's ashamed of where he comes from." },
        { type = "dialogue", speaker = "kenji",
          text = "So we fought. Said things you don't take back. Haven't really spoken since the spring - and the quiet's let me imagine the worst of him. Resentment's a poor crop, friend. Grows fast and feeds no one." },
        { type = "dialogue", speaker = "kenji",
          text = "Here's the thing that's been nagging me. A carpetbagger doesn't learn the wind. Takes years to pay off - no use to a man who's selling. But you keep turning up to learn it anyway." },
        { type = "dialogue", speaker = "kenji",
          text = "Maybe it's dying. But it's not dead while somebody's still doing it. So - now you know it too. *a long look* Maybe I had you wrong. Don't waste it." },
        { type = "end" },
    },
})

-- ---------------------------------------------------------------------------
-- Beat 4 (threshold 80) - "The Toolbox"
-- ---------------------------------------------------------------------------
VLEventSequencer.registerEvent({
    id        = "kenji_04",
    npcId     = "kenji",
    threshold = 80,
    steps = {
        { type = "move_npc", npcId = "kenji", x = 0, y = 0, z = 0, ry = 0 },  -- TODO: Kenji's workshop
        { type = "camera",   x = 0, y = 1.8, z = -4, lookAt = { x = 0, y = 1, z = 0 } },

        { type = "dialogue", speaker = "kenji",
          text = "*a worn wooden toolbox sits on the bench between you* These were my father's. The handles are worn to his grip. And mine, after." },
        { type = "dialogue", speaker = "kenji",
          text = "First day, I called you a carpetbagger to your face. Figured you'd paint Walter's barn and flip it by autumn. *he shakes his head* You're still here. Survived a spring. Then another. You stayed." },
        { type = "dialogue", speaker = "kenji",
          text = "And it got me thinking. All this time I told myself I was angry he left. *shakes his head slow* No. I was angry he didn't want what I wanted for him. That's a father's failing, not a son's. The resentment was always mine to carry, not his to earn." },
        { type = "dialogue", speaker = "kenji",
          text = "So I set it down and called him. First time since the spring. Picked up on the second ring, like he'd been waiting by the phone the whole while. And this time - I shut my mouth and let him talk." },
        { type = "dialogue", speaker = "kenji",
          text = "All this time I thought that degree meant he looked down on me. *his voice catches* Turns out the fool boy went and got it FOR me. Studying how to make this work safer, the machines less likely to take a man's arm, the soil last longer. For farms like mine. Old men like me. He can't do that work from here yet - so he had to go do it out there." },
        { type = "dialogue", speaker = "kenji",
          text = "Says he's been trying to figure how to have both - the work out there and his roots back here - and I was so busy being wounded I never once let him say it. Forty years a stubborn old fool. He's coming for the harvest. To see his old man. *quietly* That's more than enough. You taught me that's enough." },
        { type = "dialogue", speaker = "kenji",
          text = "So these don't go to him. He'd put them on a shelf. I want them used.",
          choices = {
            { label = "I'll take good care of them.",        next = "accept" },
            { label = "They're yours, Kenji. Keep using them.", next = "decline" },
          }
        },
        { type = "end" },
    },
    branches = {
        accept = {
            { type = "dialogue", speaker = "kenji",
              text = "*he slides the box across the bench, slow* Then they're yours. Wear the handles down. That's how you thank a tool." },
            { type = "dialogue", speaker = "kenji",
              text = "...You're a good neighbor. There. I said it once. Don't make me say it twice." },
            { type = "end" },
        },
        decline = {
            { type = "dialogue", speaker = "kenji",
              text = "*a slow nod, something easing in his shoulders* Stubborn. Good. We'll share them, then. My bench, your hands, when these old ones give out." },
            { type = "dialogue", speaker = "kenji",
              text = "That's better than giving them away, anyhow. Means you'll keep coming round." },
            { type = "end" },
        },
    },
})
