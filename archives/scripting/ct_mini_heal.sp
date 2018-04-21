#include <sourcemod>
#include <bs_stocks.inc>

#define PLUGIN_PREFIX "\x03[Heal]\x01"

public Plugin myinfo = 
{
	name = "mini-heal",
	author = "Crystal",
	description = "Gormarim's /heal and /hp",
	version = "1.0",
	url = ""
};

public OnPluginStart() 
{
	RegAdminCmd("sm_heal", Heal_100, ADMFLAG_RCON);
	RegAdminCmd("sm_heal_all", Heal_All, ADMFLAG_RCON);
	RegAdminCmd("sm_hp", Heal_HP, ADMFLAG_RCON);
}

public Action Heal_100(int client, int args)
{
	if (args==0)
	{
		SetEntData(client, FindDataMapOffs(client, "m_iMaxHealth"), 100, 4, true);
		SetVariantInt(100);
		AcceptEntityInput(client, "SetHealth");
		PrintToChat(client, "%s Heal successful", PLUGIN_PREFIX);
	}
	else
	{
			
		char name[64];
		char buffer[64];
		GetCmdArg(1, name, sizeof(name));
		
		new targets[MAXPLAYERS+1];
		bool ml = false;

		int count = ProcessTargetString(name, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
		if (count <= 0)
		{
			PrintToChat(client, "%s Wrong name!", PLUGIN_PREFIX);
		}
		else if (count > 1)
		{
			PrintToChat(client, "%s >1 matches", PLUGIN_PREFIX);
		}
		else
		{
			if (IsValidClient(targets[0])) 
			{
				if (IsPlayerAlive(targets[0]))
				{
					if (!IsInDuel(targets[0]))
					{
						SetEntData(targets[0], FindDataMapOffs(targets[0], "m_iMaxHealth"), 100, 4, true);
						
						SetVariantInt(100);
						AcceptEntityInput(targets[0], "SetHealth");
						
						PrintToChat(client, "%s Heal successful", PLUGIN_PREFIX);
					}
					else
					{
						PrintToChat(client, "%s Heal target is in duel", PLUGIN_PREFIX);
					}
				}
				else
				{
					PrintToChat(client, "%s Heal target is dead", PLUGIN_PREFIX);
				}
			}
		}
	}
}

public Action Heal_All(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if (IsPlayerAlive(i))
				if (!IsInDuel(i))
				{
					SetEntData(i, FindDataMapOffs(i, "m_iMaxHealth"), 100, 4, true);
					
					SetVariantInt(100);
					AcceptEntityInput(i, "SetHealth");
					
				}
	PrintToChat(client, "%s Healed everyone", PLUGIN_PREFIX);
}

public Action Heal_HP(int client, int args)
{
	if (args != 2)
	{
		PrintToChat(client, "%s Usage: /hp <target name> <target hp>", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	char name[64];
	char hpStr[64];
	char buffer[64];
	int hp;
	GetCmdArg(1, name, sizeof(name));
	GetCmdArg(2, hpStr, sizeof(hpStr));
	hp = StringToInt(hpStr);
	if ((hp <= 0) || (hp > 10000))
	{
		PrintToChat(client, "%s Usage: /hp <target name> <target hp>", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	new targets[MAXPLAYERS+1];
	bool ml = false;

	int count = ProcessTargetString(name, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
	if (count <= 0)
	{
		PrintToChat(client, "%s Wrong name!", PLUGIN_PREFIX);
	}
	else if (count > 1)
	{
		PrintToChat(client, "%s >1 matches", PLUGIN_PREFIX);
	}
	else
	{
		if (IsValidClient(targets[0])) 
		{
			if (IsPlayerAlive(targets[0]))
			{
				if (!IsInDuel(targets[0]))
				{
					if (hp > 100)
					{
						SetEntData(targets[0], FindDataMapOffs(targets[0], "m_iMaxHealth"), hp, 4, true);
						
						PrintToChat(targets[0], "%s hp = %d", PLUGIN_PREFIX, hp);
						CreateTimer(2.0, DuelCheck, targets[0], TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
					else
					{
						SetEntData(targets[0], FindDataMapOffs(targets[0], "m_iMaxHealth"), 100, 4, true);
					}
					SetEntData(targets[0], FindDataMapOffs(targets[0], "m_iHealth"), hp, 4, true);
					
					PrintToChat(client, "%s HP Set", PLUGIN_PREFIX);
				}
				else
				{
					PrintToChat(client, "%s Heal target is in duel", PLUGIN_PREFIX);
				}
			}
			else
			{
				PrintToChat(client, "%s Heal target is dead", PLUGIN_PREFIX);
			}
		}
	}
	return Plugin_Handled;
}

public Action DuelCheck(Handle timer, int client)
{
	int maxhp = GetEntData(client, FindDataMapOffs(client, "m_iMaxHealth"));
	int hp = GetEntProp(client, Prop_Data, "m_iHealth", 1);
	
	if (maxhp <= 100)
		return Plugin_Stop;
	
	if (hp <= 100)
	{
		SetEntData(client, FindDataMapOffs(client, "m_iMaxHealth"), 100, 4, true);
		return Plugin_Stop;
	}
	
	if (IsInDuel(client))
	{
		SetEntData(client, FindDataMapOffs(client, "m_iMaxHealth"), 100, 4, true);
		SetEntProp(client, Prop_Data, "m_iHealth", 100, 1);
		return Plugin_Stop;
	}
		
	
	return Plugin_Continue;
}