// 1.0.1 
/*
you know from playing KOTR quite a bit now i realized there's a little exploit for the knockback, 
you know when someones hits you with a charged attack and you go to that rolling state in the ground where you can either attack or parry, 
as long as you're in that rolling state you dont really get increased knockback at all
[23:47] 👌 raffle 👓: so sometimes people dont fall down because they go to roll state, 
problem is i have no idea how we could get around this .. :thinking:
*/
//

#include <sourcemod> 	// always here

#include <sdkhooks>		// required for hooking player damage event
#include <sdktools>		// has many useful functions: TeleportEntity, FindEntityByClassname, etc. 

public Plugin:myinfo =
{
	name = "kotr_knockback",
	author = "Crystal",
	description = "knockback helper for raffle's kotr",
	version = "1.0.1",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

//======================================//
//										//
//			Globals						//
//										//
//======================================//

// Starting speed of player after knockback
new Float:g_fKnockback;

// Vertical angle of knockback
new Float:g_fAngle;

// array which stores 1 for players inside kb trigger, and 0 for players outside 
new g_bKnockback[MAXPLAYERS+1];

// index of kotr_knockback trigger entity
new g_triggerEnt;

// 0 - usual output, 1 - Prints more messages to server and chat
new g_bDebug;

// default SM event. Called when plugin reloads (usually only when server reloads. Also could be reloaded manually with "sm plugins reload <name>" command)
public OnPluginStart()
{
	// load settings from txt file:
	
	// write path to file into this string
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/kotr_knockback.txt");
	
	// create Handle for KeyValues and load them from file
	new Handle:kv = CreateKeyValues("kotr_knockback");
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[kotr] Settings file <%s> not found.", path);
		
		// assign default values:
		g_fKnockback = 850.0;
		g_fAngle = 0.5;
		g_bDebug = 0;
		
	}
	else
	{
		// load each value
		g_bDebug = KvGetNum(kv, "debug", 0);
		g_fKnockback = KvGetFloat(kv, "force", 850.0);
		g_fAngle = KvGetFloat(kv, "angle", 0.5);
		
		// print result
		if (g_bDebug != 0)
		{
			PrintToServer("[kotr] debug = %d", g_bDebug);
			PrintToServer("[kotr] force = %3.1f", g_fKnockback);
			PrintToServer("[kotr] angle = %3.1f", g_fAngle);
		}
	}
	CloseHandle(kv);
}

// default SM event. Called on map change, when new one already loaded.
// Also called anyway after OnPluginStart
public OnMapStart()
{
	// reset everything (map change could happen when event was in progress, we should restore all initial values)
	for (new i = 1; i <= MaxClients; i++)
		ResetClient(i);
	
	// find kotr_knockback trigger [link]
	g_triggerEnt = -1;
	
	// this while loop cycles through every trigger_multiple entity and compares their names with "kotr_knockback".
	while ((g_triggerEnt = FindEntityByClassname(g_triggerEnt, "trigger_multiple")) != -1)
	{
		decl String:strName[50];
		GetEntPropString(g_triggerEnt, Prop_Data, "m_iName", strName, sizeof(strName));

		if (strcmp(strName, "kotr_knockback") == 0)
		{
			// found trigger! hook events
			HookSingleEntityOutput(g_triggerEnt, "OnStartTouch", StartTouch_KB, false); 
			HookSingleEntityOutput(g_triggerEnt, "OnEndTouch", EndTouch_KB, false);	
			
			if (g_bDebug != 0)
				PrintToServer("Found trigger! index = %d", g_triggerEnt);
			
			break;
		}
	}
	
	// if ((no triggers found) or (no trigger_multiple has that name)) then g_triggerEnt equals -1
	if (g_triggerEnt == -1)
		PrintToServer("Trigger not found! :(");
}

// default SM event. Called on map change, before loading new map
public OnMapEnd()
{	
	// just in case, unhooking events
	if (g_triggerEnt > MaxClients)
	{
		UnhookSingleEntityOutput(g_triggerEnt, "OnStartTouch", StartTouch_KB); 
		UnhookSingleEntityOutput(g_triggerEnt, "OnEndTouch", EndTouch_KB); 
	}
}

// default SM event. 
public OnClientDisconnect(client)
{
	// if player was in knockback area -> Unhook everything
	ResetClient(client);
}

// our first function! Adds player to knockback array
AddClient(client)
{
	// checking if he is not already there, because hooking and unhooking more then once is unsafe
	if (g_bKnockback[client] < 1)
	{
		// hook player damage event for this player
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		g_bKnockback[client] = 1;
		
		if (g_bDebug != 0)
			PrintToChatAll("[kotr] Added knockback to client %d", client);
	}
}

// Remove player from knockback array
ResetClient(client)
{
	if (g_bKnockback[client] > 0)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		g_bKnockback[client] = 0;
		
		if (g_bDebug != 0)
			PrintToChatAll("[kotr] Removed knockback from client %d", client);
	}
}

// hooked StartTouch event
public StartTouch_KB(const String:output[], caller, activator, Float:delay)
{
	// caller = index of trigger
	// activator = index of touching entity

	if (!IsValidClient(activator))
		return;
	
	AddClient(activator);
	
	return;
}

// hooked EndTouch event
public EndTouch_KB(const String:output[], caller, activator, Float:delay)
{
	if (!IsValidClient(activator))
		return;
	
	ResetClient(activator);
	
	return;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	// check if this is player to player damage
	// damage <= 0 check is here because somehow BS calls this event 2 times: one is normal player1 deals 20dmg to player2, and at the sme time second: player2 deals 0dmg to player1
	if (!IsValidClient(attacker) || !IsValidClient(victim) || (damage <= 0.0))
		return Plugin_Continue;
		
	// get health of a victim
	new health = GetClientHealth(victim);
	
	// don't knockback if victim should die from damage - sometimes this teleportation keeps player alive
	if (damage >= float(health))
		return Plugin_Continue;
	
	if (g_fKnockback <= 0.0)
		return Plugin_Continue;
		
	// Start calculations:
	new Float:vecVictimPos[3];
	new Float:vecAttackerPos[3];
	
	// get positions of both players
	GetClientAbsOrigin(victim, vecVictimPos);
	GetClientAbsOrigin(attacker, vecAttackerPos);
	
	// some math
	new Float:dist = DistanceXY(vecVictimPos, vecAttackerPos); // here we don't take into account height difference between players for simplicity
	new Float:cos = (vecVictimPos[0] - vecAttackerPos[0])/dist;
	new Float:sin = (vecVictimPos[1] - vecAttackerPos[1])/dist;
	
	// combine everything into velocity vector
	new Float:vel[3];
	vel[0] = g_fKnockback * Cosine(g_fAngle) * cos;
	vel[1] = g_fKnockback * Cosine(g_fAngle) * sin;
	vel[2] = g_fKnockback * Sine(g_fAngle);
	
	// TeleportEntity 
	// first argument - entity to teleportation
	// second - target position of entity
	// third - target direction of entity
	// fourth - target velocity of entity
	//
	
	// wait 0.1 sec
	new Handle:datapack;
	CreateDataTimer(0.1, Timer_Push, datapack, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(datapack, victim);
	WritePackFloat(datapack, vel[0]);
	WritePackFloat(datapack, vel[1]);
	WritePackFloat(datapack, vel[2]);
	//CloseHandle(datapack);
	//PrintToChatAll("[KotR] delayStart");
	
	// value Plugin_Continue means game should get back to applying damage as always after that push.
	return Plugin_Continue;
}

//
public Action:Timer_Push(Handle:timer, Handle:pack)
{
	decl victim;
	new Float:vel[3];
	ResetPack(pack);
	victim = ReadPackCell(pack);
	vel[0] = ReadPackFloat(pack);
	vel[1] = ReadPackFloat(pack);
	vel[2] = ReadPackFloat(pack);
	
	//PrintToChatAll("[KotR] delayEnd: %d, (%3.2f,%3.2f,%3.2f)", victim, vel[0], vel[1], vel[2]);
	// property doesn't change if you pass NULL_VECTOR to it. 
	// So here we change only speed of player:
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel);
}
	

	

//======================================//
//										//
//			Misc. Functions				//
//										//
//======================================//
// these should be in bs_stocks.inc, but I haven't got that for 1.6 yet

stock bool:IsValidClient(client)
{
	if(1 <= client <= MaxClients)
	{
		if( IsValidEntity(client) )
		{
			if( IsClientInGame(client) )
			{
				return true;
			}
		}
	}
	return false;
}

// distance on xOy plane
stock Float:DistanceXY(Float:vec1[3], Float:vec2[3])
{	
	return SquareRoot((vec1[0]-vec2[0])*(vec1[0]-vec2[0])+(vec1[1]-vec2[1])*(vec1[1]-vec2[1]));
}