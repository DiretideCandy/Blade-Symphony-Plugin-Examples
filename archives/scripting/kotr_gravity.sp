#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "kotr_gravity",
	author = "Crystal",
	description = "gravity helper for raffle's kotr",
	version = "0.1",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

// if (g_bDebug == true) prints more messages to server's console and chat
new g_bDebug = false;

// gravity multiplier ( 3.0 is default ammount of gravity (!) )
new Float:g_fGravityZ;

///!


// Array to keep track of players with modified gravity
new g_bIsGravityOn[MAXPLAYERS+1];

// integer to store trigger's entity index
new triggerEnt;

public OnPluginStart()
{
	// load settings
	
	g_fGravityZ = 0.5;
	g_bDebug = 0;
	
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/kotr_gravity.txt");
	
	new Handle:kv = CreateKeyValues("kotr_gravity");
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[kotr] Settings file <%s> not found.", path);
		CloseHandle(kv);
	}
	else
	{
		g_bDebug = KvGetNum(kv, "debug", 0);
		g_fGravityZ = KvGetFloat(kv, "gravity", 0.5);
		
		if (g_bDebug != 0)
		{
			PrintToServer("[kotr] debug = %d", g_bDebug);
			PrintToServer("[kotr] gravity = %3.1f", g_fGravityZ);
		}
	}
	CloseHandle(kv);
}

public OnMapStart()
{
	for (new i = 1; i <= MaxClients; i++)
		ResetClient(i);
	
	// find kotr_gravity trigger
	triggerEnt = -1;
	while ((triggerEnt = FindEntityByClassname(triggerEnt, "trigger_multiple")) != -1)
	{
		decl String:strName[50];
		GetEntPropString(triggerEnt, Prop_Data, "m_iName", strName, sizeof(strName));

		if (strcmp(strName, "kotr_gravity") == 0)
		{
			// found trigger! hook events
			HookSingleEntityOutput(triggerEnt, "OnStartTouch", StartTouch_Grav, false); 
			HookSingleEntityOutput(triggerEnt, "OnEndTouch", EndTouch_Grav, false);	
			if (g_bDebug != 0)
			{
				PrintToServer("Found trigger! index = %d", triggerEnt);
			}
			break;
		}
	}
	if (triggerEnt == -1)
		PrintToServer("[kotr] Trigger not found: kotr_gravity");
}

public OnMapEnd()
{
	for (new i = 1; i < MaxClients; i++)
		ResetClient(i);
	
	if (triggerEnt > MaxClients)
	{
		UnhookSingleEntityOutput(triggerEnt, "OnStartTouch", StartTouch_Grav); 
		UnhookSingleEntityOutput(triggerEnt, "OnEndTouch", EndTouch_Grav); 
	}
}

public OnClientDisconnect(client)
{
	// if player was in knockback area -> Unhook everything
	ResetClient(client);
}

AddClient(client)
{
	if (g_bIsGravityOn[client] < 1)
	{
		SetEntityGravity(client, g_fGravityZ);
		g_bIsGravityOn[client] = 1;
		
		if (g_bDebug != 0)
			PrintToChatAll("[kotr] Added gravity to client %d", client);
	}
}
	
ResetClient(client)
{
	
	if (g_bIsGravityOn[client] > 0)
	{
		if (IsValidClient(client)) // this could be called from OnClientDisconnected, so...
			SetEntityGravity(client, 3.0); // 3.0 ???
		
		g_bIsGravityOn[client] = 0;
		
		if (g_bDebug != 0)
			PrintToChatAll("[kotr] Removed gravity from client %d", client);
	}
}

public StartTouch_Grav(const String:output[], caller, activator, Float:delay)
{
	if (!IsValidClient(activator))
		return;
	
	AddClient(activator);
	
	return;
}

public EndTouch_Grav(const String:output[], caller, activator, Float:delay)
{
	if (!IsValidClient(activator))
		return;
	
	ResetClient(activator);
	
	return;
}

//======================================//
//										//
//			Misc. Functions				//
//										//
//======================================//

//public Action:Command_Test(client, args)
//{
//	
//	PrintToChat(client, "Your gravity is <%f>", GetEntityGravity(client));
//}

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