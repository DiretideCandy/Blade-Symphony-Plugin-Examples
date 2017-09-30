---
title: Knockback plugin
tags: [plugin, knockback, kotr]
keywords: plugin, knockback, raffle, kotr
last_updated: 27.09.2017
sidebar: mydoc_sidebar
permalink: kotr_knockback.html
folder: mydoc
---

<a href="https://github.com/DiretideCandy/Blade-Symphony-Plugin-Examples/blob/master/addons/sourcemod/scripting/kotr_knockback.sp" target="_blank">.sp file for SM 1.6</a>

<br>
Simple plugin for pushing players when they receive damage from another player.

<br>
* Pushes player away from attacker
* Pushes only when player is inside trigger_multiple, provided by map


## Globals
```c
#include <sourcemod> 	// always here

#include <sdkhooks>		// required for hooking player damage event
#include <sdktools>		// has many useful functions: TeleportEntity, FindEntityByClassname, etc. 

#define PLUGIN_PREFIX "[KotR]" // without colors, because most messages will go to server console

public Plugin:myinfo =
{
	name = "kotr_knockback",
	author = "Crystal",
	description = "knockback helper for raffle's KotR",
	version = "1.0",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

// Starting speed of player after knockback push
new Float:g_fKnockback;

// Vertical angle of knockback
new Float:g_fAngle;

// array which stores 1 for players inside kb trigger, and 0 for players outside 
new g_bKnockback[MAXPLAYERS+1];

// index of kotr_knockback trigger entity
new g_triggerEnt;

// if 0 - usual output, if 1 - Prints more messages to server and chat
new g_bDebug;
```
Plugin loads values of g_fKnockback, g_fAngle and g_bDebug from a text file.

## Pushing players

To push players we need to detect damage, received by them. Luckily, Sourcemod libraries have OnTakeDamage event, therefore we don't need to monitor health of players every frame or something like that.

Action declaration pasted from libraries with some code prepared for adding pushing:

```c
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	// check if this is player-to-player damage
	if (!IsValidClient(attacker) || !IsValidClient(victim))
		return Plugin_Continue;
		
	if (damage <= 0.0)
		return Plugin_Continue;
		
	/* Begin pushing */
	
	/* End pushing */
		
	return Plugin_Continue;
}
```

This code executes right before game's code for dealing damage, and by returning Plugin_Continue value we tell Soucemod that we want game to continue executing original damage event. If we would need to prevent damage to player, we should return Plugin_Handled value.
<br>
Obvious choice for pushing players is <a href="https://sm.alliedmods.net/api/index.php?fastload=show&id=40&" target="_blank">TeleportEntity</a> function. It requires 4 arguments: entity to teleport, target position, orientation and velocity. We only need to change velocity of players, that's why we'll be passing NULL_VECTOR as target position and orientation. 

```c
	...

	/* Begin pushing */
	
	// Get positions of both players to calculate direction of push:
	new Float:vecVictimPos[3];
	new Float:vecAttackerPos[3];
	
	GetClientAbsOrigin(victim, vecVictimPos);
	GetClientAbsOrigin(attacker, vecAttackerPos);
	
	// here we don't take into account height difference between players for simplicity
	new Float:dist = DistanceXY(vecVictimPos, vecAttackerPos); 
	
	// calculate sin and cos of horizontal angle between players
	new Float:cos = (vecVictimPos[0] - vecAttackerPos[0])/dist;
	new Float:sin = (vecVictimPos[1] - vecAttackerPos[1])/dist;
	
	// spherically combine everything into velocity vector
	new Float:vel[3];
	vel[0] = g_fKnockback * Cosine(g_fAngle) * cos;
	vel[1] = g_fKnockback * Cosine(g_fAngle) * sin;
	vel[2] = g_fKnockback * Sine(g_fAngle);
	
	// change only velocity of victim player:
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel);
	
	/* End pushing */
	
	...
```

[Some pictures explaining calculations?]
<br>[Maybe add "Push!" debug message?]
<br>
OnTakeDamage action is ready, but we are not done yet! OnTakeDamage is a function, which requires to be hooked to players to be called. Let's create functions, pretty common for event plugins: one will add players to our 'event', other will remove them from it.

```c

AddClient(client)
{
	// checking if player is not already there, because hooking and unhooking more then once is unsafe
	if (g_bKnockback[client] < 1)
	{
		g_bKnockback[client] = 1;
		
		// hook player damage event for this player
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		
		if (g_bDebug != 0)
			PrintToChatAll("%s Added knockback to client %d", PLUGIN_PREFIX, client);
	}
}

ResetClient(client)
{
	if (g_bKnockback[client] > 0)
	{
		g_bKnockback[client] = 0;
		
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		
		if (g_bDebug != 0)
			PrintToChatAll("%s Removed knockback from client %d", PLUGIN_PREFIX, client);
	}
}
```
These will be called when player enters or leaves event area. 
<br>
We also add them to OnClientDisconnect event (we must reset player if he disconnected from inside event area) and to OnMapStart (to reset every player in case map change happened when event was in progress):
```c
public OnClientDisconnect(client)
{
	ResetClient(client);
}

public OnMapStart()
{
	for (new i = 1; i <= MaxClients; i++)
		ResetClient(i);
	
	/* We will return here soon */
}
```

## Entering and leaving event area

There are at least three ways to monitor presence of players in event area:
* Get player's position on every damage event. Then check if its inside a given area.
	- Available on any map
	- Area can have any shape
	- Slow (compared to other methods)
* Create trigger_multiple brush via Sourcemod, hook its OnTouch and OnEndTouch events
	- Available on any map
	- Afaik, can only have cuboid shape and {0, 0, 0} orientation
	- Requires carefulness with creating and removing entities
	- Genertes harmless server error on each brush creation
	- Fast
* Same as previous one, but create trigger_multiple on the map itself (with Hammer Editor)
	- Available only to map creators
	- Area can have any shape
	- Fast
	
This plugin uses map's kotr_knockback trigger.

