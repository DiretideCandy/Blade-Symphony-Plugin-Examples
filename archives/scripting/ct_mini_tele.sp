/*
[Fixed, thanks Niky] "/tele 1" works in duels 
[Done? test more] Add /tele /bring and /goto queue for dead players
[]	Text breaking when waiting for >1 respawns with one command

*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <bsstocks.inc>

#define PLUGIN_PREFIX "\x03[Tele]\x01"

// 8 because i don't want pages in tele menu 
#define MAXDESTPOINTS 8

public Plugin myinfo = 
{
	name = "mini-tele",
	author = "Crystal",
	description = "",
	version = "1.0.0.1",
	url = ""
};

// commands for dead players
enum Queued
{
	None = 0,
	Tele,
	Bring,
	Goto
}

ConVar g_cvTeleEnabled;
bool g_bTeleEnabled;
ConVar g_cvReason;

bool g_bMapIsCorrect;

new Queued:g_command[MAXPLAYERS + 1];
int g_commandDest[MAXPLAYERS + 1];
bool g_commandReverse[MAXPLAYERS + 1];

// tele destinations
//name
char g_sTeleDestName[MAXDESTPOINTS][32];
//pos
float g_vecTeleDestPos[MAXDESTPOINTS][3];
//dir
float g_vecTeleDestDir[MAXDESTPOINTS][3];
//only for admins
bool g_bTeleDestAdminOnly[MAXDESTPOINTS];
// count
int g_teleDestCount;

public void OnPluginStart()
{
	RegConsoleCmd("tele", Command_Tele);
	RegAdminCmd("bring", Command_Bring, ADMFLAG_RCON);
	RegAdminCmd("goto", Command_Goto, ADMFLAG_RCON);
	
	g_cvReason = CreateConVar("ct_tele_disable_reason", "", "Error text for /tele menu");
	g_cvReason.Flags = 0;
	
	g_cvTeleEnabled = CreateConVar("ct_tele_enabled", "1", "Toggle /tele menu");
	g_cvTeleEnabled.Flags = FCVAR_NOTIFY; // only notify, others = false
		
	g_cvTeleEnabled.AddChangeHook(OnTeleToggle);
}

public OnMapStart()
{
	g_teleDestCount = 0;
	g_bMapIsCorrect = LoadTelePoints();
	g_bTeleEnabled = g_bMapIsCorrect; // change it manualy first, in case it doesn't call cvar change event.
	g_cvTeleEnabled.BoolValue = g_bMapIsCorrect;
	
	if (g_bMapIsCorrect)
		for (int i = 1; i <= MaxClients; i++)
			g_command[i] = None;
}

bool LoadTelePoints()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	Handle kv = CreateKeyValues("TelePoints");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/settings/ct_mini_tele/%s.txt", mapName);
	
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[Tele] Cannot find file <%s>", path);
		CloseHandle(kv);
		return false;
	}
	
	int point = 0;
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_sTeleDestName[point], sizeof(g_sTeleDestName[]));
			KvGetVector(kv, "position", g_vecTeleDestPos[point]);
			KvGetVector(kv, "orientation", g_vecTeleDestDir[point]);
			g_bTeleDestAdminOnly[point] = (KvGetNum(kv, "admin", 0) == 1);
			
			point++;
		} while ((point < MAXDESTPOINTS) && KvGotoNextKey(kv));
		
	}
	else
	{
		PrintToServer("[Tele] No Tele points in file <%s>", path);
		CloseHandle(kv);
		return false;
	}
	
	g_teleDestCount = point;
	PrintToServer("[Tele] Tele points loaded: %d", point);
	CloseHandle(kv);
	return true;
}
 
public void OnTeleToggle(ConVar convar, char[] oldValue, char[] newValue)
{
	if ((StringToInt(newValue) == 1) && g_bMapIsCorrect)
		g_bTeleEnabled = true;
	else
		g_bTeleEnabled = false;
}

ShowTeleMenu(int client)
{	
	Menu menu = new Menu(MenuHandler_Tele, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = true;
	
	int counter = 0;
	for (int i = 0; i < g_teleDestCount; i++)
	{
		if (!((GetUserFlagBits(client)==0) && (g_bTeleDestAdminOnly[i])))
		{	
			char destI[5];
			Format(destI, sizeof(destI), "%d", i)
			menu.AddItem(destI, g_sTeleDestName[i]);
			counter++;
		}
	}
	if (counter > 0)
		menu.SetTitle("Choose destination:");
	else
		menu.SetTitle("No points found.");
	
	menu.Display(client, 20);
}

public int MenuHandler_Tele(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		
		if (g_bTeleEnabled)
		{
			if (IsValidClient(param1))
			{
				if (!IsInDuel(param1))
				{
					if (!IsPlayerAlive(param1))
					{
						Queue(Tele, param1, StringToInt(info));
						PrintToChat(param1, "%s You are dead. Waiting for spawn", PLUGIN_PREFIX);
					}
					else
					{
						TeleportEntity(param1, g_vecTeleDestPos[StringToInt(info)], g_vecTeleDestDir[StringToInt(info)],NULL_VECTOR);
						PrintToChat(param1, "%s Done!", PLUGIN_PREFIX);
					}
				}
				else
				{
					PrintToChat(param1, "%s Can't teleport out of duel", PLUGIN_PREFIX);
				}
			}
		}
		else
		{
			char buffer[128];
			g_cvReason.GetString(buffer, sizeof(buffer));
			if (StrEqual(buffer, ""))
				PrintToChat(param1, "%s Teleportation disabled", PLUGIN_PREFIX);
			else
				PrintToChat(param1, "%s Teleportation disabled <%s>", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

public Action Command_Tele(int client, int args)
{
	if (!g_bTeleEnabled)
	{
		char buffer[128];
		g_cvReason.GetString(buffer, sizeof(buffer));
		if (StrEqual(buffer, ""))
			PrintToChat(client, "%s Teleportation disabled", PLUGIN_PREFIX);
		else
			PrintToChat(client, "%s Teleportation disabled <%s>", PLUGIN_PREFIX);
		
		return Plugin_Handled;
	}
	
	if (IsInDuel(client))
	{
		PrintToChat(client, "%s Can't teleport out of duel", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	if (args == 0)
	{
		ShowTeleMenu(client);
		return Plugin_Handled;
	}
	else if (args > 1)
	{
		PrintToChat(client, "%s Usage: /tele", PLUGIN_PREFIX);
		PrintToChat(client, "%s Or: /tele <point number in menu>", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	// teleport to specific point
	char arg1[10];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	// numbers from 1 to MAXDESTPOINTS. 0 is invalid
	// but our arrays are from 0 to MAXDESTPOINTS-1. MAXDESTPOINTS is invalid
	int point = StringToInt(arg1) - 1;
	
	if ((point >= 0) && (point < g_teleDestCount))
	{
		if ((GetUserFlagBits(client) == 0) && (g_bTeleDestAdminOnly[point]))
		{
			PrintToChat(client, "%s This point is for admins only", PLUGIN_PREFIX);
		}
		else
		{
			// its ok now, tele him
			
			if (!IsPlayerAlive(client))
			{
				Queue(Tele, client, point);
				PrintToChat(client, "%s You are dead. Waiting for spawn", PLUGIN_PREFIX);
			}
			else
			{
				TeleportEntity(client, g_vecTeleDestPos[point], g_vecTeleDestDir[point], NULL_VECTOR);
				PrintToChat(client, "%s Done!", PLUGIN_PREFIX);
			}
			
		}
	}
	else
	{
		PrintToChat(client, "%s Invalid point number", PLUGIN_PREFIX);
	}
	return Plugin_Handled;
}

public Action Command_Bring(int client, int args)
{
	if (args != 1)
	{
		PrintToChat(client, "%s Usage: /bring <player name>", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	char name[64];
	GetCmdArg(1, name, sizeof(name));
	
	int player = FindPlayerByName(name);
	if (player == -1)
	{
		PrintToChat(client, "%s Wrong name!", PLUGIN_PREFIX);
	}
	else if (player == 0)
	{
		PrintToChat(client, "%s >1 matches", PLUGIN_PREFIX);
	}
	else if (player == client)
	{
		PrintToChat(client, "%s Can't target yourself", PLUGIN_PREFIX);
	}	
	else if (IsInDuel(player))
	{
		PrintToChat(client, "%s Target is in duel", PLUGIN_PREFIX);
	}
	else
	{
		if (!IsPlayerAlive(client))
		{
			Queue(Bring, client, player);
			PrintToChat(client, "%s You are dead. Waiting for spawn", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
		else if (!IsPlayerAlive(player))
		{
			// queue for player, because we need hook his spawn
			Queue(Goto, player, client, true);
			PrintToChat(client, "%s Target is dead. Waiting for spawn", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
		
		float adminPos[3];
		GetClientAbsOrigin(client, adminPos);
		
		char nameStr[32];
		GetClientName(client, nameStr, sizeof(nameStr));
		TeleportEntity(player, adminPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(player, "%s Summoned by %s", PLUGIN_PREFIX, nameStr);
		PrintToChat(client, "%s Done!", PLUGIN_PREFIX);
	}
	return Plugin_Handled;
}

public Action Command_Goto(int client, int args)
{
	if (args != 1)
	{
		PrintToChat(client, "%s Usage: /goto <player name>", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	char name[64];
	GetCmdArg(1, name, sizeof(name));
	
	int player = FindPlayerByName(name);
	if (IsInDuel(client))
	{
		PrintToChat(client, "%s Can't teleport out of duel", PLUGIN_PREFIX);
	}
	else if (player == -1)
	{
		PrintToChat(client, "%s Wrong name!", PLUGIN_PREFIX);
	}
	else if (player == 0)
	{
		PrintToChat(client, "%s >1 matches", PLUGIN_PREFIX);
	}
	else if (player == client)
	{
		PrintToChat(client, "%s Can't target yourself", PLUGIN_PREFIX);
	}
	else
	{
		if (!IsPlayerAlive(client))
		{
			Queue(Goto, client, player);
			PrintToChat(client, "%s You are dead. Waiting for spawn", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
		else if (!IsPlayerAlive(player))
		{
			// queue for player, because we need hook his spawn
			Queue(Bring, player, client, true);
			PrintToChat(client, "%s Target is dead. Waiting for spawn", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
			
		float pos[3];
		GetClientAbsOrigin(player, pos);
		TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "%s Done!", PLUGIN_PREFIX);
		
	}
	return Plugin_Handled;
}

void Queue(Queued:comm, int client, int dest, bool reverse = false)
{
	g_command[client] = comm;
	g_commandDest[client] = dest;
	SDKHook(client, SDKHook_SpawnPost, OnSpawn);
	g_commandReverse[client] = reverse;
}

public OnSpawn(entity)
{
	//static bool firstSpawn[MAXPLAYERS + 1] = {false, ...};
	
	if (!g_bTeleEnabled)
	{
		char buffer[128];
		g_cvReason.GetString(buffer, sizeof(buffer));
		if (StrEqual(buffer, ""))
			PrintToChat(entity, "%s Teleportation disabled", PLUGIN_PREFIX);
		else
			PrintToChat(entity, "%s Teleportation disabled <%s>", PLUGIN_PREFIX);
		
		g_command[entity] = None;
		SDKUnhook(entity, SDKHook_SpawnPost, OnSpawn);
	}
	
	if (IsValidClient(entity))
		if (!IsInDuel(entity))
		{
			
			//firstSpawn[entity] = !firstSpawn[entity];
			//PrintToServer("firstSpawn[%d] = %d", entity, firstSpawn[entity]);
			
			if (IsPlayerAlive(entity))
			{
				// if hooked ==> command != None, but we check anyway
				if (g_command[entity] > None)
				{
					switch (g_command[entity])
					{
						case Tele:
						{
							TeleportEntity(entity, g_vecTeleDestPos[g_commandDest[entity]], NULL_VECTOR, NULL_VECTOR);
						}
						case Bring:
						{
							if (!IsPlayerAlive(g_commandDest[entity]))
							{
								Queue(Goto, g_commandDest[entity], entity, true);
								PrintToChat(g_commandReverse[entity] ? g_commandDest[entity] : entity, "%s Target is dead. Waiting for spawn", PLUGIN_PREFIX);
							}
							else
							{
								float adminPos[3];
								GetClientAbsOrigin(entity, adminPos);
								
								TeleportEntity(g_commandDest[entity], adminPos, NULL_VECTOR, NULL_VECTOR);
								if (g_commandReverse[entity])
								{
									PrintToChat(g_commandDest[entity], "%s Done!", PLUGIN_PREFIX);
								}
								else
								{
									char nameStr[32];
									GetClientName(entity, nameStr, sizeof(nameStr));
									PrintToChat(g_commandDest[entity], "%s Summoned by %s", PLUGIN_PREFIX, nameStr);
									PrintToChat(entity, "%s Done!", PLUGIN_PREFIX);
								}
							}
						}
						case Goto:
						{
							
							if (!IsPlayerAlive(g_commandDest[entity]))
							{
								Queue(Bring, g_commandDest[entity], entity, true);
								PrintToChat(g_commandReverse[entity] ? g_commandDest[entity] : entity, "%s Target is dead. Waiting for spawn", PLUGIN_PREFIX);
							}
							else
							{
								float pos[3];
								GetClientAbsOrigin(g_commandDest[entity], pos);
								TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
								if (g_commandReverse[entity])
								{
									char nameStr[32];
									GetClientName(g_commandDest[entity], nameStr, sizeof(nameStr));
									PrintToChat(entity, "%s Summoned by %s", PLUGIN_PREFIX, nameStr);
									PrintToChat(g_commandDest[entity], "%s Done!", PLUGIN_PREFIX);
								}
								else
								{
									PrintToChat(entity, "%s Done!", PLUGIN_PREFIX);
								}
							}
						}
					}
				}
				g_command[entity] = None;
				SDKUnhook(entity, SDKHook_SpawnPost, OnSpawn);
			}
		}
}
