# FlickChat

A controller keyboard for chat in World of Warcraft: Forever. Each stick has four boxes of letters. Flick toward the box that holds your next letter and FlickChat works out the word, like T9 predictive text on an old phone, and usually has it before you finish spelling it.

Open chat from the game's controller menu and the keyboard comes with it. A short lesson runs the first time, and a one-minute typing practice shows your words a minute. Settings open with the controller alone: from the keyboard, press Y for the wheel, turn to its last page and pick Settings; or pick FlickChat in the game's Options, on the AddOns tab. /flick options opens them too.

It guesses words in English, Spanish, Portuguese, French, German, Italian and Russian. It follows your game's language, and Typing language in the settings picks another. The interface follows the game's language independently of the typing language.

It needs the game's controller mode and the IM chat style (Options, Social, Chat Style). FlickChat offers the switch if you are on Classic style.

## Русский язык

Установите `FlickChat` и папку `Packs/FlickChat_ruRU` как два отдельных аддона:

```text
Interface/AddOns/
  FlickChat/
    FlickChat.toc
    ...
  FlickChat_ruRU/
    FlickChat_ruRU.toc
    Words.lua
```

На русском клиенте интерфейс и язык ввода выбираются автоматически. На другом клиенте откройте `/flick options` и переключите **Typing language** на **Русский**. Язык интерфейса при этом остаётся языком игры.

Поддерживаются все 33 буквы, включая **ё**, алфавитная раскладка и раскладка с гласными слева, ввод по буквам, русское обучение, тренировка и отдельное запоминание слов для каждого языка. Словарь содержит около 94 тысяч слов, игровые термины и сокращения. Для английских слов и сокращений переключайте язык ввода на English.

## Rebuilding the Russian dictionary

`tools/build_pack.py` also supports `ruRU`. Download `rus_sentences.tsv.bz2` from [Tatoeba](https://downloads.tatoeba.org/exports/per_language/rus/rus_sentences.tsv.bz2), the LDNOOBW `ru` list as `ldnoobw/ru.txt`, and the four Russian Wago tables as `wago/{Map,AreaTable,ChrClasses,ChrRaces}_ruRU.csv` under a downloads folder (URLs and table details are in the script). Then run:

```sh
python tools/build_pack.py ruRU <downloads-folder>
lua tools/tests/smoke_test.lua .
```

The generated pack includes its Cyrillic layouts so precomputed prediction keys and the runtime keyboard use the same alphabet. `tools/ruRU-sources.sha256` records the input snapshot used for the committed pack (2026-11-14); the download URLs are rolling exports, so newer inputs may produce a different dictionary. Run `sha256sum -c <addon-folder>/tools/ruRU-sources.sha256` from the downloads folder to check that snapshot. See `CREDITS.txt` for the data licenses.

## Links

Get it on [CurseForge](https://www.curseforge.com/wow/addons/flickchat).

Report a problem or ask for something under **Issues**.
