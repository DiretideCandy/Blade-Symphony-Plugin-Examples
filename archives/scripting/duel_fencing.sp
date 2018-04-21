/**
 * v1.1 
 *			- [test] changed step-off from EndTouch to OnGameFrame check
 * 			- [test] fixed grab?
 *			- [test] removed resources from dl table

*/

#include <sourcemod> 	// always here
#include <sdkhooks>		
#include <sdktools>	

#include <bsstocks>

//#include <bs_eventBlock>

#define PLUGIN_PREFIX "\x04[\x03Fencing\x04]\x03: \x04 "

#define DEFAULT_SWORD "vs_sword id_25"

#define TIMER_EQUIPMENT_TICK 1.0
#define TIMER_READY 1.6

#define MAX_ARENAS 3

#define SCORELIMIT 7

// end round reason ids
#define REASON_HIT 0
#define REASON_PLAYER_LEFT 1
#define REASON_EQUIPMENT 2	
#define REASON_HEAVY 3	
#define REASON_AIR 4	
#define REASON_ROLL 5	
#define REASON_DASH 6	
#define REASON_GRAB 7	
#define REASON_SHURI 8	
#define REASON_STEP_OFF 9
#define REASON_SWAP 10
#define REASON_DEATH 11
#define REASON_TECH 12

// soundlist indexes
#define SOUND_FENCE 0
#define SOUND_GAME 2
#define SOUND_HALT 4
#define SOUND_ONGUARD 6
#define SOUND_READY 8
#define SOUND_SCORE 10

// freeze lengths
#define FREEZE_ENDROUND 0
#define FREEZE_READY 1

public Plugin:myinfo =
{
	name = "duel_fencing",
	author = "Crystal",
	description = "Fencing! (duel server edition)",
	version = "1.0",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

//======================================//
//										//
//		  Client Globals				//
//										//
//======================================//
//new g_hookedSpawn[MAXPLAYERS + 1];
new g_isOnArena[MAXPLAYERS + 1]; // >= 0 if player is alive on arena
new g_warnings[MAXPLAYERS + 1];
new bool:g_bKillBlocked[MAXPLAYERS + 1];

//======================================//
//										//
//		  Game  Globals					//
//										//
//======================================//

new bool:g_bIsMapCorrect;
new g_arenas[MAX_ARENAS];
new g_arenasCount;
new String:g_sSounds[11][64];

new bool:g_allow_sideair;
new bool:g_allow_roll;
new bool:g_allow_dash;
new Float:g_mat_width;
new Float:g_mat_length;
new Float:g_mat_width2plusR; // g_mat_width / 2.0 + 16.0 // 32.0 == player size
new Float:g_mat_length2plusR;
//======================================//
//										//
//		  Arena  Globals				//
//										//
//======================================//
new g_players[MAX_ARENAS][2];
new g_score[MAX_ARENAS][2];
new g_arenaStatus[MAX_ARENAS]; // 0 - nothing, 1 - players alive, no fighting; 2 - fencing started
//new g_arenaTriggers[MAX_ARENAS]/*[2]*/; // 0 - mat borders, 1 - shuri/player restriction trigger?
new Float:g_arenaSignum[MAX_ARENAS]; // sign of d = Position_of_Player1.Y - Position_of_Player0.Y
new Float:g_arenaPos[MAX_ARENAS][3]; // point between two spawns

//======================================//
//										//
//		   Main Body Of Plugin			//
//										//
//======================================//
public OnPluginStart()
{
	
	//RegAdminCmd("reload_settings", CMD_ReloadSettings, ADMFLAG_ROOT);
	
	//RegConsoleCmd("test", CMD_Test/*, ADMFLAG_ROOT*/);
	AddCommandListener(KillCallback, "kill");
	 
	// hook everyone in case this was a plugin reload
	for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
		{
			//SDKHook(i, SDKHook_SpawnPost, OnSpawn);
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	
	//hook player death event
	HookEvent("player_death", Event_Player_Death);
	
	LoadResources();
}

public OnPluginEnd()
{
	// remove triigers (in case plugin being reloaded manualy)
	//if (g_bIsMapCorrect)
		//if (g_arenasCount > 0)
			//for (new i = 0; i < g_arenasCount; i++)
				//RemoveEntity(g_arenaTriggers[i]);
}

public OnMapStart()
{
	ResetGlobals();
	
	g_bIsMapCorrect = LoadSettings();
	
	if (!g_bIsMapCorrect)
		return;
	
	CreateTimer(5.0, InitServerConfig, _, TIMER_FLAG_NO_MAPCHANGE);
	
	CreateTimer(1.0, Timer_InitFencingFinder, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	DestroyHurtTriggers();
}

DestroyHurtTriggers()
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "trigger_hurt")) != -1)
	{
		decl String:strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		
		RemoveEntity(index);
	}
	return index;
}

LoadResources()
{
	// sound strings
	Format(g_sSounds[0], sizeof(g_sSounds[]), "fencingtourney/announce_fence01.wav");
	Format(g_sSounds[1], sizeof(g_sSounds[]), "fencingtourney/announce_fence02.wav");
	Format(g_sSounds[2], sizeof(g_sSounds[]), "fencingtourney/announce_game01.wav");
	Format(g_sSounds[3], sizeof(g_sSounds[]), "fencingtourney/announce_game02.wav");
	Format(g_sSounds[4], sizeof(g_sSounds[]), "fencingtourney/announce_halt01.wav");
	Format(g_sSounds[5], sizeof(g_sSounds[]), "fencingtourney/announce_halt02.wav");
	Format(g_sSounds[6], sizeof(g_sSounds[]), "fencingtourney/announce_onguard01.wav");
	Format(g_sSounds[7], sizeof(g_sSounds[]), "fencingtourney/announce_onguard02.wav");
	Format(g_sSounds[8], sizeof(g_sSounds[]), "fencingtourney/announce_ready01.wav");
	Format(g_sSounds[9], sizeof(g_sSounds[]), "fencingtourney/announce_ready02.wav");
	Format(g_sSounds[10], sizeof(g_sSounds[]), "fencingtourney/fencing_score.wav");
	
	
	// Prepare sounds (they must be on fastdl!)
	for (new i = 0; i < 11; i++)
	{
		//decl String:name[64];
		//Format(name, sizeof(name), "sound/%s", g_sSounds[i]);
		//AddFileToDownloadsTable(name);
		PrecacheSound(g_sSounds[i],true);
	}
}

public Action:InitServerConfig(Handle:timer)
{
	//ServerCommand("vs_duel_rounds 1");
	//ServerCommand("vs_duel_timelimit 0");
	//ServerCommand("bb_vote_gamemode_enable 0");
	return Plugin_Handled;
}

public OnClientDisconnect(client)
{
	//SDKUnhook(client, SDKHook_SpawnPost, OnSpawn);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	new arena = g_isOnArena[client];
	if (arena >= 0) // is alive and fencing init done
		if (g_arenaStatus[arena] > 0)
		{
			PrintToArena(arena, "Ending game.");
			ResetClient(g_players[arena][0]);
			ResetClient(g_players[arena][1]);
			ResetArena(arena);
			
		}
		
	ResetClient(client);
}

public OnClientPostAdminCheck(client)
{
	//SDKHook(client, SDKHook_SpawnPost, OnSpawn);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	ResetClient(client);
}

ResetGlobals()
{
	//g_bIsMapCorrect is not here
	for (new i = 0; i < MAX_ARENAS; i++)
		ResetArena(i);
	
	for (new i = 1; i <= MaxClients; i++)
		ResetClient(i);
}

ResetArena(arena)
{
	g_players[arena][0] = -1;
	g_players[arena][1] = -1;
	g_score[arena][0] = 0;
	g_score[arena][1] = 0;
	g_arenaStatus[arena] = 0;
}

ResetClient(client)
{
	if ((client < 1) || (client > MaxClients))
		return;
	
	// no unhooking here
	g_isOnArena[client] = -1;
	g_warnings[client] = 0;
	g_bKillBlocked[client] = true;
}

bool:LoadSettings()
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/duel_fencing.txt");
	
	// create Handle for KeyValues and load them from file
	new Handle:kv = CreateKeyValues("fencing");
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[Fencing] File <plugins/duel_fencing.txt> not found.");
		CloseHandle(kv);
		return false;
	}
	
	g_allow_sideair = bool:KvGetNum(kv, "allow_sideair", 0);
	g_allow_roll = bool:KvGetNum(kv, "allow_roll", 0);
	g_allow_dash = bool:KvGetNum(kv, "allow_dash", 0);
	g_mat_width = KvGetFloat(kv, "mat_width", 45.0);
	g_mat_width2plusR = g_mat_width/2.0 + 16.0;
	g_mat_length = 672.0;
	g_mat_length2plusR = g_mat_length/2.0 + 16.0;

	// jump to allowed maps list
	if (!KvJumpToKey(kv, "allowed_maps"))
	{
		PrintToServer("[Fencing] List of allowed maps not found.");
		CloseHandle(kv);
		return false;
	}
	decl String:mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	// jump to current map params
	if (!KvJumpToKey(kv, mapName))
	{
		PrintToServer("[Fencing] Map is not allowed.");
		CloseHandle(kv);
		return false;
	}
	
	// load settings for this map
	if (!KvGotoFirstSubKey(kv))
	{
		PrintToServer("[Fencing] No fencing arenas on this map.");
		CloseHandle(kv);
		return false;
	}
	
	g_arenasCount = 0;
	new String:duelEntName[64];
	new Float:size[3];
	size[0] = g_mat_width; //strict size: size[0] = 15.0;
	size[1] = g_mat_length;//strict size: size[1] = 520.0;
	size[2] = 150.0;

	do 
	{
		KvGetSectionName(kv, duelEntName, sizeof(duelEntName));
		new duelEnt = Entity_FindByName(duelEntName, "berimbau_duel");
		if (duelEnt < 0)
			continue;
		
		g_arenas[g_arenasCount] = duelEnt;
		KvGetVector(kv, "origin", g_arenaPos[g_arenasCount]);		
		g_arenaPos[g_arenasCount][2] += 45.0;
		
		//g_arenaTriggers[g_arenasCount] = CreateBrush("trigger_multiple", g_arenaPos[g_arenasCount], size);
		//HookSingleEntityOutput(g_arenaTriggers[g_arenasCount], "OnStartTouch", StartTouch_Mat, false);
		//HookSingleEntityOutput(g_arenaTriggers[g_arenasCount], "OnEndTouch", EndTouch_Mat, false);	
		
		g_arenaPos[g_arenasCount][2] -= 50.0;
		
		g_arenasCount++;
	} while (KvGotoNextKey(kv) && (g_arenasCount < MAX_ARENAS)) ;
	
	CloseHandle(kv);
	return true;
}

public Action:KillCallback(client, const String:command[], argc)
{
	if (g_bKillBlocked[client])
	{
		//PrintToChatAll("kill blocked!");
		return Plugin_Handled;
	}

	//PrintToChatAll("kill not blocked!");
	return Plugin_Continue;
}

public Action:OnClientCommand(client, args)
{	
	if (!g_bIsMapCorrect)
		return Plugin_Continue;

	decl String:cmd[16];
	GetCmdArg(0, cmd, sizeof(cmd));	/* Get command name */
	
	if (StrEqual(cmd, "vs_ready_duel"))
	{
		//PrintToChat(client, "%s <vs_ready_duel>", PLUGIN_PREFIX);
		ChangeEquipment(client);
			
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	//get attacker
	//new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	// end duel if it didn't end yet
	new arena = g_isOnArena[victim];
	if (arena >= 0) // is alive and fencing init done
		if ((g_arenaStatus[arena] > 0) && (g_arenaStatus[arena] < 3))
		{
			PrintToArena(arena, "Ending game.");
			
			ResetClient(g_players[arena][0]);
			ResetClient(g_players[arena][1]);
			ResetArena(arena);
			
		}
			
}

public Action:Timer_InitFencingFinder(Handle:timer)
{
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	for (new i = 0; i < g_arenasCount; i++)
	{
		if (g_arenaStatus[i] > 0)
			continue;
		
		new counter = 0;
		new players[4];
		// if status == 0 then count players in it
		for (new cl = 1; cl <= MaxClients; cl++)
			if ((g_DuelState[cl] == g_arenas[i]) && (IsValidClient(cl)) && (IsPlayerAlive(cl)))
			{
				players[counter] = cl;
				counter++;
			}
		
		if (counter == 2)
			InitFencing(i, players[0], players[1]);
		
	}
	
	
	return Plugin_Continue;
}

InitFencing(arena, p1, p2)
{
	//PrintToChatAll("%s InitFencing: arena %d, players %d and %d", PLUGIN_PREFIX, arena, p1, p2);
		
	g_arenaStatus[arena] = 1; // players alive
	
	g_isOnArena[p1] = arena;
	g_isOnArena[p2] = arena;
	
	g_players[arena][0] = p1;
	g_players[arena][1] = p2;
	
	ChangeEquipment(p1);
	ChangeEquipment(p2);
	
	new Float:pos1[3];
	new Float:pos2[3];
	GetClientAbsOrigin(p1, pos1);
	GetClientAbsOrigin(p2, pos2);
	if (pos2[1] - pos1[1] >= 1.0)
		g_arenaSignum[arena] = (pos2[1] - pos1[1]) / fAbs(pos2[1] - pos1[1]);
	else 
		g_arenaSignum[arena] = 1.0;
	
	TeleportOnGuard(arena);
	
	// start equipment check timer after 5.9 sec
	//CreateTimer(5.9, Timer_StartEquipmentTimer, arena, TIMER_FLAG_NO_MAPCHANGE);
	
	// begin onguard->ready->fence timers
	CreateTimer(7.0, Timer_OnGuard, arena, TIMER_FLAG_NO_MAPCHANGE);
	
	//PrintToChatAll("%s [DEBUG] InitDone! (arena %d)", PLUGIN_PREFIX, arena);
}

TeleportOnGuard(arena)
{
	if (g_arenaStatus[arena] <= 0)
		return;
	
	if (!IsValidClient(g_players[arena][0]))
		return;
	
	if (!IsPlayerAlive(g_players[arena][0]))
		return;
	
	if (!IsValidClient(g_players[arena][1]))
		return;
	
	if (!IsPlayerAlive(g_players[arena][1]))
		return;
	
	new Float:vec[3];
	new Float:dir[3];
	dir[0] = 20.0;
	dir[2] = 0.0;
	vec[0] = g_arenaPos[arena][0];
	vec[2] = g_arenaPos[arena][2];
	
	dir[1] = 180.0 - 90.0 * g_arenaSignum[arena];
	vec[1] = g_arenaPos[arena][1] - g_arenaSignum[arena] * 142.0; // if signum > 0 p0 to south, p1 to north
	TeleportEntity(g_players[arena][0], vec, dir, Float:{0.0, 0.0, 0.0});
	SetEntProp(g_players[arena][0], Prop_Send, "m_bKneeling", 0);
	SetEntProp(g_players[arena][0], Prop_Send, "m_iStringIndex", 0);	
	
	dir[1] = 180.0 + 90.0 * g_arenaSignum[arena];
	vec[1] = g_arenaPos[arena][1] + g_arenaSignum[arena] * 142.0;
	TeleportEntity(g_players[arena][1], vec, dir, Float:{0.0, 0.0, 0.0});
	SetEntProp(g_players[arena][1], Prop_Send, "m_bKneeling", 0);
	SetEntProp(g_players[arena][1], Prop_Send, "m_iStringIndex", 0);	
	
	//PrintToChatAll("%s [DEBUG] Teleporting! (arena %d)", PLUGIN_PREFIX, arena);
}

public Action:Timer_OnGuard(Handle:timer, any:arena)
{
	if (g_arenaStatus[arena] <= 0)
		return Plugin_Handled;
	
	//PrintToChatAll("%s [DEBUG] Timer_OnGuard fired! (arena %d)", PLUGIN_PREFIX, arena);
	new bEqFine = true;
	if (!CheckEquipment(g_players[arena][0], arena))
	{
		g_arenaStatus[arena] = 3;
		CreateTimer(3.0, Timer_Kill, g_players[arena][0], TIMER_FLAG_NO_MAPCHANGE);
		bEqFine = false;
	}	
	if (!CheckEquipment(g_players[arena][1], arena))
	{
		g_arenaStatus[arena] = 3;
		CreateTimer(3.0, Timer_Kill, g_players[arena][1], TIMER_FLAG_NO_MAPCHANGE);
		bEqFine = false;
	}
	
	if (!bEqFine)
	{
		CreateTimer(3.0, Timer_GameSound, arena, TIMER_FLAG_NO_MAPCHANGE);	
		CreateTimer(5.5, Timer_ResetArena, arena, TIMER_FLAG_NO_MAPCHANGE);	
	}
	else
	{
		SetEntityHealth(g_players[arena][0], 99);
		SetEntityHealth(g_players[arena][1], 99);
		PlaySoundToArena(arena, SOUND_ONGUARD);
		CreateTimer(TIMER_READY, Timer_Ready, arena, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

public Action:Timer_Ready(Handle:timer, any:arena)
{
	if (g_arenaStatus[arena] <= 0)
		return Plugin_Handled;
	
	//PrintToChatAll("%s [DEBUG] Timer_Ready fired! (arena %d)", PLUGIN_PREFIX, arena);
	
	// equipment checks should be done by now.		
	SetEntityHealth(g_players[arena][0], 99);
	SetEntityHealth(g_players[arena][1], 99);
	TeleportOnGuard(arena);
	PlaySoundToArena(arena, SOUND_READY);
	CreateTimer(TIMER_READY, Timer_Fence, arena, TIMER_FLAG_NO_MAPCHANGE);
	FreezePlayers(arena, FREEZE_READY);
	
	return Plugin_Handled;
}

public Action:Timer_Fence(Handle:timer, any:arena)
{
	if (g_arenaStatus[arena] <= 0)
		return Plugin_Handled;
	
	//PrintToChatAll("%s [DEBUG] Timer_Fence fired! (arena %d)", PLUGIN_PREFIX, arena);
		
	SetEntityHealth(g_players[arena][0], 99);
	SetEntityHealth(g_players[arena][1], 99);
	TeleportOnGuard(arena);
	
	// teleport somehow triggers endTouch event! start tracking it after some time:
	CreateTimer(0.5, Timer_FencingStart, arena, TIMER_FLAG_NO_MAPCHANGE);
	///!
	
	return Plugin_Handled;
}

public Action:Timer_FencingStart(Handle:timer, any:arena)
{
	if (g_arenaStatus[arena] <= 0)
		return Plugin_Handled;
	
	g_arenaStatus[arena] = 2;
	
	PlaySoundToArena(arena, SOUND_FENCE);
	PrintToArena(arena, "Fence!");
	
	return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{		
	if ((IsValidClient(attacker)) && (IsValidClient(victim)))
	{
		for(new arena = 0; arena < MAX_ARENAS; arena++)
			// if fencing started
			if (g_arenaStatus[arena] == 2)
				if ((g_players[arena][0] == victim) && (g_players[arena][1] == attacker))
				{
					//found arena, point to right player
					if (GetActId(attacker) == BS_ACTIONID_GRAB)
						EndRound(arena, REASON_GRAB, 1);
					else
						EndRound(arena, REASON_HIT, 1);
					
					return Plugin_Continue;
				}
				else if ((g_players[arena][1] == victim) && (g_players[arena][0] == attacker)) 
				{
					//found arena, point to left player
					if (GetActId(attacker) == BS_ACTIONID_GRAB)
						EndRound(arena, REASON_GRAB, 0);
					else
						EndRound(arena, REASON_HIT, 0);
					
					return Plugin_Continue;
				}
	}	
	return Plugin_Continue;
}

EndRound(arena, reason, fencer = -1)
{
	g_arenaStatus[arena] = 1; // stop fighting
	
	decl String:nameLoser[64];
	decl String:nameWinner[64];
	if (fencer >= 0)
	{
		GetClientName(g_players[arena][fencer], nameLoser, sizeof(nameLoser));
		GetClientName(g_players[arena][!fencer], nameWinner, sizeof(nameWinner));
	}
	
	new bool:freeze = false;
	switch (reason)
	{
		case REASON_HIT:
		{
			freeze = true;
			PlaySoundToArena(arena, SOUND_SCORE);
			g_score[arena][fencer] += 1;
		}
		case REASON_GRAB:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Grab! \x04(\x03%s\x04)\x03", nameLoser); // PLUGIN_PREFIX is inside PrintToArena function
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_ROLL:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Roll! \x04(\x03%s\x04)\x03", nameLoser);
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_DASH:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Dash! \x04(\x03%s\x04)\x03", nameLoser);
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_SHURI:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Shuri! \x04(\x03%s\x04)\x03", nameLoser);
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_EQUIPMENT:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Equipmet problems!", nameLoser);
		}
		case REASON_HEAVY:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Heavy attack! \x04(\x03%s\x04)\x03", nameLoser);
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_AIR:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Air attack! \x04(\x03%s\x04)\x03", nameLoser);
			if (AddWarning(arena, g_players[arena][fencer]))
			{
				g_score[arena][!fencer] += 1;
				PrintToArena(arena, "\x04Point to \x03%s\x04", nameWinner);
			}
		}
		case REASON_STEP_OFF:
		{
			freeze = true;
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Step off!\x04 Point to \x03%s\x04", nameWinner);
			g_score[arena][!fencer] += 1;
		}
		case REASON_SWAP:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Swap!", PLUGIN_PREFIX);
		}
		//case REASON_DEATH:
		//{
			//PlaySoundToArena(arena, SOUND_GAME);
			//PrintToArena(arena, "Death!", PLUGIN_PREFIX);
			//g_score[arena][!fencer] = SCORELIMIT;
		//}
		case REASON_TECH:
		{
			PlaySoundToArena(arena, SOUND_HALT);
			PrintToArena(arena, "\x03Wrong block tech!", PLUGIN_PREFIX);
			g_score[arena][!fencer] += 5;
		}
	}
	
	
	//temp text
	decl String:name0[64];
	GetClientName(g_players[arena][0], name0, sizeof(name0));
	decl String:name1[64];
	GetClientName(g_players[arena][1], name1, sizeof(name1));
	PrintToArena(arena, "\x03%s %d\x04 - \x03%d %s\x04", name0, g_score[arena][0], g_score[arena][1], name1);
	
	if (freeze)
		FreezePlayers(arena, FREEZE_ENDROUND);
	
	//check win conditions
	if (g_score[arena][0] >= SCORELIMIT)
	{
		PrintToArena(arena, "\x03%s\x01 wins!", name0);
		EndGame(arena, g_players[arena][1]);
	}
	else if (g_score[arena][1] >= SCORELIMIT)
	{
		PrintToArena(arena, "\x03%s\x01 wins!", name1);
		EndGame(arena, g_players[arena][0]);
	}
	else
	{
		CreateTimer(3.0, Timer_OnGuard, arena, TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool:AddWarning(arena, loser)
{
	// 0 warnings - print nothing, add 1, return false
	// 1 warnings - print 1, add 1, return false
	// 2 warnings - print 2, add 1, return false
	// 3 warnings - print 3, add 1, return false
	// 4 warnings - return true
	if (g_warnings[loser] <= 0)
		g_warnings[loser] = 1;
	else if (g_warnings[loser] >= 4)
		return true;
	else 
	{
		PrintToArena(arena, "Warning \x03%d\x04!", g_warnings[loser]); 
		g_warnings[loser]++;
	}
			
	return false;
}

FreezePlayers(arena, freezeType)
{
	new Float:time = 1.0;
	switch (freezeType)
	{
		case FREEZE_ENDROUND:
		{
			time = 2.8;
		}
		case FREEZE_READY:
		{
			time = TIMER_READY + 0.6;
		}
	}
	if (IsValidClient(g_players[arena][0]))
	{
		SetEntPropFloat(g_players[arena][0], Prop_Send, "m_flLaggedMovementValue", 0.0);
		CreateTimer(time, Timer_Unfreeze, g_players[arena][0], TIMER_FLAG_NO_MAPCHANGE);
	}
	
	if (IsValidClient(g_players[arena][1]))
	{
		SetEntPropFloat(g_players[arena][1], Prop_Send, "m_flLaggedMovementValue", 0.0);
		CreateTimer(time, Timer_Unfreeze, g_players[arena][1], TIMER_FLAG_NO_MAPCHANGE);
	}
	
}

public Action:Timer_Unfreeze(Handle:timer, any:client)
{	
	if (IsValidClient(client))
		SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
	
	return Plugin_Handled;
}

EndGame(arena, loser)
{
	// don't reset yet!
	g_arenaStatus[arena] = 3;
	
	CreateTimer(3.0, Timer_Kill, loser, TIMER_FLAG_NO_MAPCHANGE);	
	CreateTimer(3.0, Timer_GameSound, arena, TIMER_FLAG_NO_MAPCHANGE);	
	CreateTimer(5.5, Timer_ResetArena, arena, TIMER_FLAG_NO_MAPCHANGE);	
	
}

public Action:Timer_GameSound(Handle:timer, any:arena)
{
	PlaySoundToArena(arena, SOUND_GAME);
		
	return Plugin_Handled;
}

public Action:Timer_Kill(Handle:timer, any:client)
{
	g_bKillBlocked[client] = false;
	if (IsValidClient(client) && IsPlayerAlive(client))
		ClientCommand(client, "kill");
	
	return Plugin_Handled;
}

public Action:Timer_ResetArena(Handle:timer, any:arena)
{	
	ResetClient(g_players[arena][0]);
	ResetClient(g_players[arena][1]);
	ResetArena(arena);
	
	return Plugin_Handled;
}

// player left Mat
/*public EndTouch_Mat(const String:output[], caller, activator, Float:delay)
{
	//PrintToChatAll("EndTouch_Mat fired!");
	
	if (IsValidClient(activator) && IsPlayerAlive(activator))
	{
		new arena = g_isOnArena[activator];
		if ((arena >= 0) && (caller == g_arenaTriggers[arena]))
			if (g_arenaStatus[arena] == 2)// if fencing in progress
			{
				if (g_players[arena][0] == activator)
					EndRound(arena, REASON_STEP_OFF, 0);
				else if (g_players[arena][1] == activator)
					EndRound(arena, REASON_STEP_OFF, 1);
			}
	}
}*/
//======================================//
//										//
//		  OnGameFrame					//
//										//
//======================================//
public OnGameFrame() 
{
	if (!g_bIsMapCorrect)
		return;
	
	for (new i = 0; i < g_arenasCount; i++)
	{
		if (g_arenaStatus[i] != 2) 
			continue;
		
		new actId;
		new bool:charging;
		new Float:pos0[3];
		new Float:pos1[3];
		for (new player = 0; player < 2; player++)
		{
			// these should be instant, so yea, potentially heavy endround and resetround are here:(
			actId = GetActId(g_players[i][player]);
			charging = bool:GetEntProp(g_players[i][player], Prop_Send, "m_bCharging");
			if ((actId == BS_ACTIONID_ROLL) && (!g_allow_roll))
			{
				EndRound(i, REASON_ROLL, player);
				break;
			}
			//else if (actId == BS_ACTIONID_GRAB) //v 1.1 - allow grabs
			//{
				//EndRound(i, REASON_GRAB, player);
				//break;
			//}
			else if ((actId == BS_ACTIONID_DASH) && (!g_allow_dash))
			{
				EndRound(i, REASON_DASH, player);
				break;
			}
			else if (actId == BS_ACTIONID_SHURI)
			{
				EndRound(i, REASON_SHURI, player);
				break;
			}
			else if ((actId == BS_ACTIONID_PHALANX_HEAVY_1) || (actId == BS_ACTIONID_PHALANX_HEAVY_LEFT) || (actId == BS_ACTIONID_PHALANX_HEAVY_RIGHT))
			{
				EndRound(i, REASON_HEAVY, player);
				break;
			}
			else if ((actId == BS_ACTIONID_PHALANX_AIR_1) && (!charging))
			{
				EndRound(i, REASON_AIR, player);
				break;
			}
			else if ((((actId == BS_ACTIONID_PHALANX_AIR_LEFT) || (actId == BS_ACTIONID_PHALANX_AIR_RIGHT)) && (!g_allow_sideair)) && (!charging))
			{
				EndRound(i, REASON_AIR, player);
				break;
			}
			else if ((actId == BS_ACTIONID_INTERCEPT) || (actId == BS_ACTIONID_BLOCK) || (actId == BS_ACTIONID_FEINT))
			{
				EndRound(i, REASON_TECH, player);
				break;
			}
		}
		if (g_arenaStatus[i] == 2) // ... this looks dumb
		// if (EndRound didn't change this value)
		{
			// check for swapped positions, 
			// v1.1 also check step off here too!
			GetClientAbsOrigin(g_players[i][0], pos0);
			GetClientAbsOrigin(g_players[i][1], pos1);
			
			if ((g_arenaSignum[i] >= 0.0) && (pos0[1] > pos1[1] + 16.0))
				EndRound(i, REASON_SWAP, -1);
			else if ((g_arenaSignum[i] < 0.0) && (pos1[1] > pos0[1] + 16.0))
				EndRound(i, REASON_SWAP, -1);
			// mat x
			else if ((pos0[0] > g_arenaPos[i][0] + g_mat_width2plusR) || (pos0[0] < g_arenaPos[i][0] - g_mat_width2plusR))
				EndRound(i, REASON_STEP_OFF, 0);
			else if ((pos0[1] > g_arenaPos[i][1] + g_mat_length2plusR) || (pos0[1] < g_arenaPos[i][1] - g_mat_length2plusR))
				EndRound(i, REASON_STEP_OFF, 0);
			else if ((pos1[0] > g_arenaPos[i][0] + g_mat_width2plusR) || (pos1[0] < g_arenaPos[i][0] - g_mat_width2plusR))
				EndRound(i, REASON_STEP_OFF, 1);
			else if ((pos1[1] > g_arenaPos[i][1] + g_mat_length2plusR) || (pos1[1] < g_arenaPos[i][1] - g_mat_length2plusR))
				EndRound(i, REASON_STEP_OFF, 1);
		}
	}
}

//======================================//
//										//
//		  Misc							//
//										//
//======================================//
stock bool:CheckEquipment(client, arena)
{
	if (!IsValidClient(client))
		return false;
	// check sword type
	if (GetSwordTypeId(client) != BS_SWORDTYPEID_RAPIER)
	{
		decl String:name[64];
		GetClientName(client, name, sizeof(name));
		PrintToArena(arena, "Wrong sword type (\x03%s\x04)! Ending game.", name);
		return false;
	}
	// check character
	if (GetEntProp(client, Prop_Send, "m_CharacterIndex") != 0)
	{
		decl String:name[64];
		GetClientName(client, name, sizeof(name));
		PrintToArena(arena, "Wrong character (\x03%s\x04)! Ending game.", name);
		return false;
	}
	 
	return true;
}

stock ChangeEquipment(client)
{
	if (!IsValidClient(client))
		return;
	
	// check sword type
	if (GetSwordTypeId(client) != BS_SWORDTYPEID_RAPIER)
		ClientCommand(client, DEFAULT_SWORD);
	
	// check character
	if (GetEntProp(client, Prop_Send, "m_CharacterIndex") != 0)
		ClientCommand(client, "vs_character phalanx");
}

stock GetArenaEnt(client)
{
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
		
	return g_DuelState[client]; // 0 if no arena. but it is possible only on ffa, right?
}

// get opponent (this used when we already started fencing on this arena and have players inside g_players[arena] array)
stock GetOpponentOnArena(client, arena)
{
	if (g_players[arena][0] == client)
		return g_players[arena][1];
	else if (g_players[arena][1] == client)
		return g_players[arena][0];
	else
		return -1;
}

// get opponent (this one used when we don't have started arena yet)
stock GetOpponent(client)
{	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	new arenaId = g_DuelState[client];
	//PrintToChatAll("GetOpponent! arenaId = %d", arenaId);
	
	if (arenaId <= 0)
		return -1;
	
	for (new i = 1; i <= MaxClients; i++)
		if ((i != client) && (g_DuelState[i] == arenaId) && IsValidClient(i) && IsPlayerAlive(i))
			return i;
		
	return -1;
}

stock PrintToArena(arena, const String:myString[], any:...)
{
	if ((arena < 0) || (arena >= g_arenasCount))
		return;
	
	new len = strlen(myString) + 255;
	decl String:myFormattedString[len];
	VFormat(myFormattedString, len, myString, 3);
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if (GetArenaEnt(i) == g_arenas[arena])
				PrintToChat(i, "%s %s", PLUGIN_PREFIX, myFormattedString);
}

stock PlaySoundToArena(arena, sound)
{
	if ((arena < 0) || (arena >= g_arenasCount))
		return;
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if (GetArenaEnt(i) == g_arenas[arena])
				PlaySound(i, sound);
}

stock PlaySound(client, sound)
{
	// SOUND_SCORE is alone, others have alternative sound
	if (sound != SOUND_SCORE)
		sound += GetRandomInt(0, 1);
	
	decl String:cmd[64];
	Format(cmd, sizeof(cmd), "play %s", g_sSounds[sound]);
	ClientCommand(client, cmd);
}

// don't let freezed players press anything
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_bIsMapCorrect)
		if (g_isOnArena[client] >= 0)
			if(GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") == 0.0)
				buttons = 0;
			
	return Plugin_Continue;
}
//======================================//
//										//
//		  Tests							//
//										//
//======================================//
/* CMD_Test
public Action:CMD_Test(client, args)
{	
	
	PrintToChat(client, "%s test commmand!", PLUGIN_PREFIX);
	
	if (args == 1)
	{
		new String:arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		
		new m_Offset = FindSendPropInfo("CBerimbauPlayer", "m_iSwordItemType");
		GetEntData(StringToInt(arg1), m_Offset);
		PrintToChatAll("Good!");
		PrintToChatAll("Client #%d, m_iSwordItemType = %d", StringToInt(arg1), GetEntData(StringToInt(arg1), m_Offset));
		
		m_Offset = FindSendPropInfo("CBerimbauPlayer", "m_iSwordIndex");
		GetEntData(StringToInt(arg1), m_Offset);
		PrintToChatAll("Good!");
		PrintToChatAll("Client #%d, m_iSwordIndex = %d", StringToInt(arg1), GetEntData(StringToInt(arg1), m_Offset));
		
		m_Offset = FindSendPropInfo("CBerimbauPlayer", "m_iSwordtypeId");
		GetEntData(StringToInt(arg1), m_Offset);
		PrintToChatAll("Good!");
		PrintToChatAll("Client #%d, m_iSwordtypeId = %d", StringToInt(arg1), GetEntData(StringToInt(arg1), m_Offset));
		//PrintToChatAll("Client #%d, m_iSwordItemType = %d", StringToInt(arg1), GetEntProp(StringToInt(arg1), Prop_Send, "m_iSwordItemType"));
		//PrintToChatAll("Client #%d, m_iSwordIndex = %d", StringToInt(arg1), GetEntProp(StringToInt(arg1), Prop_Data, "m_iSwordIndex"));
		//PrintToChatAll("Client #%d, m_iSwordtypeId = %d", StringToInt(arg1), GetEntProp(StringToInt(arg1), Prop_Send, "m_iSwordtypeId"));
		
		
	}
	return Plugin_Handled;
}*/