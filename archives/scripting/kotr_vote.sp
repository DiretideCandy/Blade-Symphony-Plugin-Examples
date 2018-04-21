#include <sourcemod> 	// always here

#include <sdkhooks>		// required for hooking player damage event
#include <sdktools>		// has many useful functions: TeleportEntity, FindEntityByClassname, etc. 

#include <bsstocks>

#include <bs_eventBlock>

#define PLUGIN_PREFIX "\x04[\x03KotR\x04]\x03: \x04 "

#define MIN_VOTES 2 //controls the absolute minimum number of participants
#define INITAL_VOTE_TIME 45 //controls the amount of time the first vote for bchess will be displayed
#define PI 3.1415926535897932384626433832795

public Plugin:myinfo =
{
	name = "kotr_vote",
	author = "Crystal",
	description = "",
	version = "1.0",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

new g_blockerEnt;

new bool:g_bKotrCD = false;

new bool:g_bArenaIsUp = false;

new g_MinYesVotes = MIN_VOTES;

new String:g_buttons[20][64];

new bool:g_freezedPlayers[MAXPLAYERS+1];

new bool:g_bStartFound = false;
new Float:g_vecStartCenter[3];
new Float:g_fStartRadius;

new Float:g_vecOutOrigin[3];
new Float:g_vecOutSize[3];
new Float:g_vecOutDest[3];
new Float:g_vecSpectatorSpawn[3];

public OnPluginStart()
{
	RegConsoleCmd("kotr_start", CMD_ChatStart, "starts kotr via chat trigger");
	HookEvent("player_death", Event_PlayerDeath);
}

public OnMapStart()
{
	ResetAllGlobals();
	
	for(new i = 1; i <= 18; i++)
	{
		Format(g_buttons[i-1], sizeof(g_buttons[]), "kotr_timer_button_%d", i);
		PrepareButton(g_buttons[i-1]);
	}
	
	// load map
	g_bStartFound = false;
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/kotr_vote.txt");
	
	// create Handle for KeyValues and load them from file
	new Handle:kv = CreateKeyValues("kotr_vote");
	if (!FileToKeyValues(kv, path))
	{
		g_bStartFound = false;
		PrintToServer("[KotR] File <plugins/kotr_vote.txt> not found.");
		
	}
	else
	{
		g_bStartFound = true;
		g_fStartRadius = KvGetFloat(kv, "start_radius", 368.0);
		KvGetVector(kv, "start_center", g_vecStartCenter);
	
		KvGetVector(kv, "out_origin", g_vecOutOrigin);
		KvGetVector(kv, "out_wlh", g_vecOutSize);
		KvGetVector(kv, "out_dest", g_vecOutDest);
		KvGetVector(kv, "spectator_spawn", g_vecSpectatorSpawn);
		
	}
	CloseHandle(kv);
	
	// hook event ending:
	new ent = Entity_FindByName("arena", "func_tracktrain");
	if (ent > MaxClients)
		HookSingleEntityOutput(ent, "OnStart", OnArenaStart);
	
	//  hook event starter
	ent = Entity_FindByName("Kotr_trigger", "trigger_multiple");
	if (ent > MaxClients)
		HookSingleEntityOutput(ent, "OnStartTouch", Start_Trigger_Callback, false);
	//PrintToChatAll("Event? %d", IsEventInProgress());
	
	//  remove shaking game text
	RemoveEntity(Entity_FindByName("kotr_shake_text", "game_text"));
}

stock ResetAllGlobals()
{
	g_bKotrCD = false;
	g_blockerEnt = -1;
	g_bArenaIsUp = false;
	g_MinYesVotes = MIN_VOTES;
	
	for (new i = 1; i <= MaxClients; i++)
		g_freezedPlayers[i] = false;
}

public Action:CMD_ChatStart(client, args)
{
	if( !IsInDuel(client) )
	{
		if(!IsVoteInProgress() && !IsEventInProgress())
		{
			if (!IsEventInProgress())
			{
				if (!g_bKotrCD)
				{
					DisplayAskToStartVote(client);
				}
				else
				{
					PrintToChat(client, "%s game is on CD now, please wait then try again.", PLUGIN_PREFIX);
				}
			}
			else
			{
				PrintToChat(client, "\x04 Another event is currently in progress, please wait then try again.");
			}
		}
		else
		{
			PrintToChat(client, "\x04A vote or game is currently in progress, please wait then try again.");
		}
	}	
	return Plugin_Handled;
}

TeleportToArena(client, tele_counter, num_clients)
{
	if (g_bStartFound)
	{
		new Float:pos[3];
		pos[0] = g_vecStartCenter[0] + g_fStartRadius*Cosine(2.0*PI*tele_counter/num_clients);
		pos[1] = g_vecStartCenter[1] + g_fStartRadius*Sine(2.0*PI*tele_counter/num_clients);
		pos[2] = g_vecStartCenter[2];
		
		new Float:dir[3];
		dir[0] = 10.0;
		dir[2]= 0.0;
		dir[1] = 360.0 * tele_counter/num_clients + 180.0;
									
		TeleportEntity(client, pos, dir, NULL_VECTOR);
		SetEntityHealth(client, 100);
	}
}

DisplayAskToStartVote(client)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AskToStartVoteHandler, MENU_ACTIONS_DEFAULT);
	//set the title
	SetMenuTitle(menu, "Would you like to initiate a KotR vote?");
	//add menu items (w/unique Ids)
	AddMenuItem(menu, "1", "Yes");
	AddMenuItem(menu, "2", "No");
	//display to client
	DisplayMenu(menu, client, 5);
}

public AskToStartVoteHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//yes
				
				if(!IsVoteInProgress() && !IsEventInProgress())
				{
					if (!IsEventInProgress())
					{
						if (!g_bKotrCD)
						{
							DisplayInitialVote();
						}
						else
						{
							PrintToChat(param1, "%s game is on CD now, please wait then try again.", PLUGIN_PREFIX);
						}
					}
					else
					{
						PrintToChat(param1, "\x04 Another event is currently in progress, please wait then try again.");
					}
				}
				else
				{
					PrintToChat(param1, "\x04A vote or game is currently in progress, please wait then try again.");
				}
			}
			case 2:
			{
				//no
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisplayInitialVote()
{
	if(!IsVoteInProgress())
	{
		//dynamic array for list of recipients
		new Handle:cl_arr_buff = CreateArray( 1, 0 );
		new numRecipients;
		for( new i = 0; i <= MaxClients; i++ )
		{
			if( IsValidClient(i) && !IsInDuel(i) )
			{
				PushArrayCell(cl_arr_buff, i);
				numRecipients++;
			}
		}
		//translate dynamic array to normal array
		new cl_arr[numRecipients];
		for( new i = 0; i < numRecipients; i++ )
		{
			new x = GetArrayCell(cl_arr_buff, i);
			cl_arr[i] = x;
		}

		//create and push menu
		new Handle:menu = CreateMenu(InitialVoteMenuHandler, MENU_ACTIONS_DEFAULT);
		SetVoteResultCallback(menu, InitialVoteResultsHandler);
		SetMenuTitle(menu, "Would you like to play KotR?");
		AddMenuItem(menu, "1", "Yes");
		AddMenuItem(menu, "2", "No");
		SetMenuExitButton(menu, false);
		VoteMenu(menu, cl_arr, numRecipients, INITAL_VOTE_TIME);
		
		//close dynamic array handle
		CloseHandle(cl_arr_buff);
	}
}

public InitialVoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public InitialVoteResultsHandler(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	//get the item index for a 'yes' vote
	new String:vote_item_buffer[2];
	new vote_yes_index = -1;
	
	for( new i = 0; i < num_items; i++ )
	{
		GetMenuItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], vote_item_buffer, sizeof(vote_item_buffer));
		//PrintToChatAll("vote_item_buffer = %s", vote_item_buffer);
		new x = StringToInt(vote_item_buffer);
		if( x == 1 )
		{
			vote_yes_index = i;
			break;
		}
	}
	//PrintToChatAll("vote_yes_index = %d", vote_yes_index);
	//get the number of clients that voted yes
	new num_yes_votes = 0;
	new num_tele = 0;
	for( new i = 0; i < num_clients; i++ )
	{
		if( client_info[i][VOTEINFO_CLIENT_ITEM] == item_info[vote_yes_index][VOTEINFO_ITEM_INDEX] )
		{
			if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
			{
				if( !IsInDuel(client_info[i][VOTEINFO_CLIENT_INDEX]) )
				{
					num_yes_votes++;
					if( IsPlayerAlive(client_info[i][VOTEINFO_CLIENT_INDEX]) )
					{
						num_tele++;
					}
				}
			}
		}
	}
	//PrintToChatAll("num_yes_votes = %d", num_yes_votes);
	//PrintToChatAll("g_MinYesVotes = %d", g_MinYesVotes);
	
	new tele_counter = 0;
	//check for min number of yes votes
	if( num_yes_votes >= g_MinYesVotes )
	{
		//flag the participating clients
		for( new i = 0; i < num_clients; i++ )
		{
			if( client_info[i][VOTEINFO_CLIENT_ITEM] == item_info[vote_yes_index][VOTEINFO_ITEM_INDEX] )
			{
				if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
				{
					if( !IsInDuel(client_info[i][VOTEINFO_CLIENT_INDEX]) )
					{
						if( IsPlayerAlive(client_info[i][VOTEINFO_CLIENT_INDEX]) )
						{
							g_freezedPlayers[client_info[i][VOTEINFO_CLIENT_INDEX]] = true;
							SetEntPropFloat(client_info[i][VOTEINFO_CLIENT_INDEX], Prop_Send, "m_flLaggedMovementValue", 0.0);
							
							TeleportToArena(client_info[i][VOTEINFO_CLIENT_INDEX], tele_counter, num_tele);
							tele_counter++;
						}
						else
						{
							SDKHook(client_info[i][VOTEINFO_CLIENT_INDEX], SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
						}
					}
				}
			}
			else if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
			{
				//PrintToChatAll("%N voted no", client_info[i][VOTEINFO_CLIENT_INDEX]);
			}
		}
		// msg participants that the vote passed
		PrintToChatAll("%s Vote successful! Event begins!", PLUGIN_PREFIX);
		
		
		
		//Start Event
		CreateTimer(11.0, Timer_UnfreezePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
		PressButtons();
		
		//Teleport dueling players away
		for (new i = 1; i <= MaxClients; i++)
			if (IsValidClient(i) && IsPlayerAlive(i))
				if (!g_freezedPlayers[i])
					if (IsInsideArena(i))
					{
						TeleportEntity(i, g_vecOutDest, NULL_VECTOR, NULL_VECTOR);
						PrintToChat(i, "%s You were teleported away from event", PLUGIN_PREFIX);
					}				
		
	}
	else
	{
		//tell all clients how many players are needed and that there weren't enough to start. Reset everything.
		PrintToChatAll("%s Vote was unsuccessful; received %i of the required %i minimum votes.", PLUGIN_PREFIX, num_yes_votes, g_MinYesVotes);
		ResetAllGlobals();
	}
}

PressButtons()
{
	for(new i=17; i>=0;i--)
	{
		new ent = Entity_FindByName(g_buttons[i], "func_button");
		if (ent > MaxClients)
		{
			//PrintToChatAll("Pressing button %d", ent);
			AcceptEntityInput(ent, "Press");
		}
	}
}

public OnArenaStart(const String:output[], caller, activator, Float:delay)
{
	g_bArenaIsUp = !g_bArenaIsUp;
	//PrintToChatAll("g_bArenaIsUp = %d", g_bArenaIsUp);
	
	// if going down
	if (!g_bArenaIsUp)
	{
		UnblockEvents(g_blockerEnt);
	}
}

public OnButtonPressed(const String:output[], caller, activator, Float:delay)
{
	// block events
	g_blockerEnt = BlockEvents();
	
	// start timer (event cd)
	//PrintToChatAll("OnButtonPressed Start");
	g_bKotrCD = true;
	CreateTimer(600.0, Timer_KotrCD, _, TIMER_FLAG_NO_MAPCHANGE);
	//PrintToChatAll("OnButtonPressed End");
}

public Action:Timer_UnfreezePlayers(Handle:timer)
{
	//PrintToChatAll("Fire timer");
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_freezedPlayers[i])
		{
			if  (IsValidClient(i) && IsPlayerAlive(i))
			{
				//{
					//PrintToChatAll("g_freezedPlayers[%d] = %d", i, g_freezedPlayers[i]);
				SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
				//}
			}
		}
	}
	
	ShakeText();
	CreateTimer(10.0, Timer_Shake, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE); 
}

public Action:Timer_Shake(Handle:timer)
{
	if (g_bArenaIsUp)
	{
		ShakeText();
		
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

ShakeText()
{
	new Handle:hHudText = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.05, 5.0, 255, 255, 255, 255);
			
	for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i) && !IsInDuel(i) && IsInsideArena(i))
			ShowSyncHudText(i, hHudText, "[KOTR] Arena is breaking down, watch out!");
			
	CloseHandle(hHudText);
}
			

public Action:Timer_KotrCD(Handle:timer)
{
	g_bKotrCD = false;
}

PrepareButton(const String:entName[])
{
	new Float:away[3];
	away[0] = 4015.0;
	away[1] = 5304.0;
	away[2] = -11921.0;
	
	new ent = Entity_FindByName(entName, "func_button");
	
	if (ent > MaxClients)
	{
		HookSingleEntityOutput(ent, "OnPressed", OnButtonPressed);
		TeleportEntity(ent, away, NULL_VECTOR, NULL_VECTOR);
		//PrintToChatAll("Hooked %s (%d)", entName, ent);
		return ent;
	}
	//PrintToChatAll("Didn't hook %s (%d)", entName, ent);
	return ent;
}

Entity_FindByName(const String:entityName[], const String:entityClassName[])
{
	new index = -1;
	while ((index = FindEntityByClassname(index, entityClassName)) != -1)
	{
		decl String:strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		
		//PrintToChatAll(strName);
		if (strcmp(strName, entityName) == 0)
		{
			return index;
		}
	}
	return index;
}

public ParticipantMissedInitialSpawn(client)
{
	if( IsValidClient(client) )
	{
		if( IsPlayerAlive(client) )
		{
			TeleportEntity(client, g_vecStartCenter, NULL_VECTOR, NULL_VECTOR);
			SDKUnhook(client, SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
			
			g_freezedPlayers[client] = true;
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 0.0);
		}
	}
}

public TextRedirection(const String:output[], caller, activator, Float:delay)
{
	PrintToChatAll("Display 1!");
	
	if (IsValidClient(1))
		AcceptEntityInput(caller, "Display", 1);
	
	PrintToChatAll("Display 2!");
}

public Start_Trigger_Callback(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if( !IsInDuel(activator) )
		{
			if(!IsVoteInProgress() && !IsEventInProgress())
			{
				if (!IsEventInProgress())
				{
					if (!g_bKotrCD)
					{
						DisplayAskToStartVote(activator);
					}
					else
					{
						PrintToChat(activator, "%s game is on CD now, please wait then try again.", PLUGIN_PREFIX);
					}
				}
				else
				{
					PrintToChat(activator, "\x04 Another event is currently in progress, please wait then try again.");
				}
			}
			else
			{
				PrintToChat(activator, "\x04A vote or game is currently in progress, please wait then try again.");
			}
		}
	}
}

stock bool:IsInsideArena(client)
{
	new Float:pos[3];
	GetClientAbsOrigin(client, pos);
	
	new bool:inside = true;
	for (new j=0; j<2; j++)
	{
		if ((pos[j] > g_vecOutOrigin[j] + g_vecOutSize[j]/2.0) || (pos[j] < g_vecOutOrigin[j] - g_vecOutSize[j]/2.0))
		{
			inside = false;
			break;
		}
	}
	return inside;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_bArenaIsUp)
		if (IsValidClient(victim) && !IsInDuel(victim))
			if (IsInsideArena(victim))
			{
				SDKHook(victim, SDKHook_SpawnPost, SpawnAsSpectator);
			}
}

public SpawnAsSpectator(client)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		TeleportEntity(client, g_vecSpectatorSpawn, NULL_VECTOR, NULL_VECTOR);
	}
}