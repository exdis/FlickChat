"""Builds Words.lua's word and word-pair counts: every word of a full English dictionary (SCOWL), counted from
Tatoeba's English sentences, plus Tatoeba's own common words and the chat words below.

python tools/build_words.py <eng_sentences.tsv.bz2> <scowl.txt> [pair minimum]
Tatoeba: https://tatoeba.org/en/downloads (per language, English).
SCOWL: https://app.aspell.net/create?max_size=60&spelling=US&max_variant=0&diacritic=strip&special=hacker
    &download=wordlist&encoding=utf-8&format=inline (size 60, the spell checkers' default).
"""
import bz2
import re
import sys
from collections import Counter, defaultdict

SOURCE, SCOWL = sys.argv[1], sys.argv[2]
# A follower counts from this many times after its word; rarer ones fall to the smoothing.
PAIR_MIN = int(sys.argv[3]) if len(sys.argv) > 3 else 2
OUT = "Words.lua"
# Tatoeba words outside the dictionary come in from this many uses (slang, newer words); fewer is mostly typos.
OUTSIDE_MIN = 5
# Tatoeba is mostly about Tom and Mary: a name counts no more than the word at this rank.
NAME_RANK = 1000
# The most common words (and every short one) are the decoder's quick list; the rest it searches as text.
CORE = 12000
LETTERS = ["abc", "def", "ghi", "jklm", "nop", "qrs", "tuv", "wxyz"]
DIGIT = {c: str(g + 1) for g, letters in enumerate(LETTERS) for c in letters}

TOKEN = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)*")
CONTRACTION = re.compile(r"(n't|'ll|'re|'ve|'d|'m)$")

# Chat words the sentences lack or rank too low, by how often chat uses them: the count of the word at that rank.
CHAT = {
    150: "ok lol ty np thx yeah yep nope pls plz u ur gg brb omw lfg inc",
    600: """lfm wts wtb oom rez res afk gl hf dps tank tanks healer heals heal inv invite pst idk btw imo gz grats
    ding ready rdy sec mob mobs adds aggro pull pulling wipe wiped loot quest quests dungeon dungeons raid guild
    party group boss buff buffs mana drink drinking food gold silver copper vendor repair hearth summon portal
    mount mounted flight trade sell buy item items gear bag bags bank mail auction xp exp lvl level levels leveling
    healing tanking priest warrior mage rogue hunter warlock druid paladin shaman horde alliance orc troll tauren
    undead human dwarf gnome elf elves kk ofc tho cya ttyl wb nvm ffs omg wtf haha lmao""",
    4000: """dm wc sfk bfd stocks gnomer sm rfk rfd ulda zf mara brd lbrs ubrs strat scholo dme ony mc bwl zg aq
    naxx rfc cath gy lib arms tele ss bop boe bis ench enchant enchanting herb herbs ore mats craft crafting
    alchemy blacksmith tailor tailoring skinning mining fishing cooking leatherworking engineering pvp bg bgs
    honor duel spec respec talent talents controller controllers gamepad gamepads addon addons keybind keybinds
    hotkey hotkeys macro macros debuff debuffs aoe cc nerf nerfed noob noobs toon toons alt alts transmog mog
    lag laggy respawn respawns emote emotes ui minimap healthstone soulstone tbh rofl hehe xd dc dced relog
    thumbstick thumbsticks dpad Stormwind Ironforge Darnassus Orgrimmar Undercity Azeroth Kalimdor Elwynn
    Westfall Redridge Duskwood Stranglethorn Barrens Ashenvale Tanaris""",
}

counts, capmid, lowmid = Counter(), Counter(), Counter()
pairs = Counter()
with bz2.open(SOURCE, "rt", encoding="utf-8") as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 3:
            continue
        tokens = TOKEN.findall(parts[2].replace("’", "'"))
        prev = "<s>"
        for i, tok in enumerate(tokens):
            low = tok.lower()
            counts[low] += 1
            if i:
                if tok[0].isupper():
                    capmid[low] += 1
                else:
                    lowmid[low] += 1
            pairs[(prev, low)] += 1
            prev = low

with open(SCOWL, encoding="utf-8") as f:
    text = f.read()
dictionary = text[text.index("\n---\n") + 5:].split()

# A dictionary word's shape: lowercase, or the capital form when the dictionary has only that one.
shape = {}
for word in dictionary:
    low = word.lower()
    if word == low or low not in shape:
        shape[low] = word


def capital(low):
    """Mostly capitalized mid-sentence (names, days, I) shows capitalized; lowercase when written both ways."""
    mid = capmid[low] + lowmid[low]
    if low in shape and shape[low] == low:
        return mid >= 3 and capmid[low] / mid > 0.9
    return mid >= 3 and capmid[low] / mid > 0.6


ranked = [w for w, _ in counts.most_common()]
name_cap = counts[ranked[NAME_RANK]]
words, forms, scale = {}, {}, {}
for low, form in shape.items():
    if "'" in low and not CONTRACTION.search(low) and counts[low] < 3:
        continue
    if len(low) == 1 and low not in ("a", "i"):
        continue
    if form != low and lowmid[low] > capmid[low]:
        form = low
    is_name = (form != low or capital(low)) and low != "i"
    words[low] = max(1, min(counts[low], name_cap) if is_name else counts[low])
    if is_name and counts[low] > name_cap:
        scale[low] = name_cap / counts[low]
    if form != low:
        forms[low] = form
    elif capital(low):
        forms[low] = low[0].upper() + low[1:]
for low in ranked:
    if counts[low] < OUTSIDE_MIN:
        break
    if low not in words and len(low) <= 16 and not capital(low):
        words[low] = counts[low]
by_rank = sorted(words.values(), reverse=True)
for rank, chat in CHAT.items():
    for w in chat.split():
        low = w.lower()
        words[low] = max(words.get(low, 0), by_rank[rank])
        if w != low:
            forms[low] = w
        else:
            forms.pop(low, None)

# Words the repo's commit checks refuse in a tracked file, one per line, when the list is there.
LEAVE_OUT = "dev/leave_out.txt"
try:
    with open(LEAVE_OUT, encoding="utf-8") as f:
        for w in f.read().split():
            words.pop(w.lower(), None)
except FileNotFoundError:
    pass

ranked_all = sorted(words, key=lambda w: (-words[w], w))
order = [w for i, w in enumerate(ranked_all) if i < CORE or len(w.replace("'", "")) < 3]
index = {w: i + 1 for i, w in enumerate(order)}
index["<s>"] = 0
# Each common word's followers: how often it is followed at all and by how many different words (all of them, for
# the smoothing), then the common words seen after it at least PAIR_MIN times, likeliest first. A name's pairs
# shrink by as much as its count did ("Tom" starts a third of Tatoeba's sentences).
followers = defaultdict(list)
context_total, context_kinds = Counter(), Counter()
for (a, b), c in pairs.items():
    if a not in index:
        continue
    c = c * scale.get(a, 1) * scale.get(b, 1)
    context_total[a] += c
    context_kinds[a] += 1
    if b in index and b != "<s>" and int(c) >= PAIR_MIN:
        followers[a].append((int(c), index[b]))
kept = 0
for a in followers:
    followers[a].sort(key=lambda f: (-f[0], f[1]))
    kept += len(followers[a])


def key_of(word):
    return "".join(DIGIT[c] for c in word.lower() if c != "'")


# Blocks: a three-digit key's words alone, longer keys by their first four digits.
buckets = defaultdict(list)
for w in ranked_all:
    if w not in index:
        key = key_of(w)
        buckets[key[:4]].append((key, -words[w], forms.get(w, w)))

MARK = "-- Data: tools/build_words.py writes everything below this line.\n"
code = open(OUT, encoding="utf-8").read()
code = code[:code.index(MARK)] if MARK in code else code
with open(OUT, "w", encoding="utf-8", newline="\n") as out:
    out.write(code)
    out.write(MARK)
    out.write("-- Word counts, then each word's followers (by the word lines' numbers; 0 starts a message): times\n")
    out.write("-- followed, by how many different words, then follower and count pairs, likeliest first.\n")
    out.write("-- Words from SCOWL and Tatoeba's English sentences, counts from Tatoeba (see CREDITS.txt).\n")
    out.write("ns.WORD_DATA = [[\n")
    for w in order:
        out.write(f"{forms.get(w, w)} {words[w]}\n")
    out.write("]]\n\nns.PAIR_DATA = {\n")
    for a in sorted(context_total, key=lambda w: index[w]):
        items = " ".join(f"{b} {c}" for c, b in followers[a])
        out.write(f'[{index[a]}] = "{int(context_total[a])} {context_kinds[a]} {items}",\n')
    out.write("}\n\n")
    out.write("-- The rarer words by key (letters layout): a three-digit key alone, longer ones by their first four;\n")
    out.write("-- lines of key, word, count.\n")
    out.write("ns.RARE_DATA = {\n")
    for head in sorted(buckets):
        out.write(f'["{head}"] = [[\n\n')
        for key, neg, form in sorted(buckets[head]):
            out.write(f"{key} {form} {-neg}\n")
        out.write("]],\n")
    out.write("}\n")
print(len(order), "common words,", sum(len(b) for b in buckets.values()), "rarer in", len(buckets), "blocks,",
      kept, "pairs; biggest block", max(len(b) for b in buckets.values()))
print("top:", " ".join(forms.get(w, w) for w in order[:60]))
