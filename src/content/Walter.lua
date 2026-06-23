-- Walter (GRANDPA) casual dialogue — the player's grandfather, the most built-out character.
-- TIME-OF-DAY lines (morning/midday/evening/night) are schedule-independent, so they hold up
-- while his routes are still being tuned. Activity/location-specific lines can layer on later.
--
-- These are PLACEHOLDERS in Walter's voice (gruff, warm underneath, proud of the player) — rewrite
-- freely. See journals/console-commands.md for vlWalterSay (cycles the current bucket).

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

    alreadyTalked = {
        "We've said our piece today. Go on — work won't do itself.",
        "Told you what I know. Get back to it.",
    },
})
