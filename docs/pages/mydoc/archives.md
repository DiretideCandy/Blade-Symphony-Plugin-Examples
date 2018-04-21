---
title: Plugin archives
tags: [archives]
keywords: old, archives, archive
last_updated: 21.04.2018
sidebar: mydoc_sidebar
permalink: archives.html
folder: mydoc
---

## Intro
This page describes some plugins in [path].<br><br>
But be warned: some of them are not tested enough, some are not working, chaotic, broken from the start or unnecessarily overcomplicated.<br>
And almost most of them are written for (here I go again) SourceMod 1.6. 
There are many differences in newest versions of SM, but most significant changes in 1.7 were about tags.<br>
In old 1.6 plugins you will find these declarations:
```c
public Action:Test(client, args)
//
new Float:vec1[3];
new Float:vec2[3];
//
decl String:str[32];
```
instead of these from 1.7 (and newest SM tutorials):
```c
public Action Test(int client, int args)
//
float vec1[3], vec2[3];
//
char str[32];
```

## include/bsstocks.inc

[tested, safe]<br>
Library of Elmo's and Gorm's (and mine now too!) useful functions. Put it inside "Path to compile.exe"/include/ and it will be your best friend. 

## include/bs_eventBlock.inc

[tested, safe]<br>
Functions for simple event coordination. Creating invisible entity should tell other event plugins to disable their /start commands

## ActionIdTest.sp

[only for testing]<br>
Plugin prints to chat ActionId of landed attacks.<br><br>
Note on ActionId and other stuff: see it for yourself by turning sv_cheats on and then entering cl_pdump 1 into your game console 
(1 is your player's entity index when you are alone on dedicated server).
This will show you SOME of the variables you can use in your plugins. Others are in ctdump.txt file (don't remember console command for getting this list rn).
There are different ways of getting/changing those values, in each case you usually should go over every one of these ways to see which of them works (if any). 

## as.sp

[not finished]<br>
My first attempt to do an event plugin. Almost works, but has many bugs in it. Consists of constant players' ActionId tracking, nothing else to see here.

## br.sp

[laggy, not tested enough]<br>
My attempt to do a simple free_docks battle royale :) Don't remember where I stopped, I'm sure it doesn't work correctly.<br>
Also, russian comments only...

## ButtonsTest.sp

[only for testing]<br>
Plugin for printing button presses. Don't remember test results, but it can show you which player actions you can detect/disable with SM's default OnPlayerRunCmd event.

## ct_antishuri.sp

[tested, should be safe]<br>
Creates trigger_multiple entities on positions from ct_antishuri.txt. Destroys any shuriken on trigger's OnTouchEvent. <br>
Sometimes it is possible to hit players inside those at point blank range, also destroyed shuris leave their flying sounds on.

## ct_mini_heal.sp

[tested, should be safe]<br>
Commands /heal, /heal_all and /hp. Uses Gormarim's way of finding player by part of his name. 
Maybe it was easier to do with Elmo's FindPlayerByName, which is now in my bsstocks.inc.

## DamageShow.sp

[only for testing]<br>
Gorm's simple onTakeDamage test. Should print to chat any damage dealt by players.<br>
Commeent all conditions in it to print all damage.

## DeathTest.sp

[only for testing]<br>
Gorm's simple player_death event test. Should print to chat on every death.

## duel_fencing.sp

[tested, should be safe]<br>
Current version of fencing plugin for duel server. Works fine, but with minimum comments in code.

## ed.sp

[tested, safe]
Elmo's plugin for manually starting duels in ffa (1v2 and 2v2 too!). The only ancient artifact of successful use of sigscanning.<br>
Works only for linux servers.<br>
(Only duels without timelimit. Kills server if you try to apply timelimit, solution was not found)

## event_vote.sp

[not tested enough, but should be safe]<br>
Simple plugin for raffle, starts an event vote (like in Elmo's Battle Chess), teleports everyone who voted Yes to admin.<br>
Applies event block from bs_eventBlock.inc lilbrary.

## it.sp

[works, but very laggy, not safe]
Just another silly plugin with lasers. Makes ordinary duels unplayable because of lags from heavy computations on every frame.<br>

## kotr_knockback.sp, kotr_gravity.sp, kotr_vote.sp

[tested, should be safe]<br>
Plugins for raffle's KotR event. Knockbback from damage, lowered gravity and voting for event from Elmo's Battle Chess.

## Machine.sp

[Only for controlled, 'manual' events]
Gormarim's simple machine event helper. Can add particle effect to a machine's sword (which was making things a bit laggy and distracted machine player a lot:)

## OnTakeDamagev4.sp

[only for testing]<br>
More Gorm's onTakeDamage tests. This one should have more info in it.

## sf_bchess_automation_v018.sp

[tested, safe]<br>
Elmo's Auto Battle Chess plugin. Ask raffle if you need original settings file for it.
sf_bchess_automation_v018_b.sp - I added eventBlock for raffle's absp map, maybe something else.

## sf_kendo_automation_V2.sp

[tested, safe]<br>
Elmo's Kendo plugin.

## TeleportTest.sp

[only for testing]<br>
Gormarim's TeleportEntity test.
