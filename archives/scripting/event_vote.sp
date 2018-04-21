#include <sourcemod> 	// always here
#include <sdkhooks>		
#include <sdktools>		// has many useful functions: TeleportEntity, FindEntityByClassname, etc. 

#include <bsstocks>
#include <bs_eventBlock>

#define PLUGIN_PREFIX "\x04[\x03Event\x04]\x03: \x04"

#define MIN_VOTES 1 //controls the absolute minimum number of participants
#define INITAL_VOTE_TIME 45 //controls the amount of time the first vote will be displayed

public Plugin:myinfo =
{
	name = "event_vote",
	author = "Crystal",
	description = "Simple event voting plugin for teleporting people to admin",
	version = "1.0",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};

// Blocker entity index
new g_blockerEnt;

// variable from Elmo's chess. Using MIN_VOTES would be fine, but I'll keep it here for now. 
// Will be useful if this number will go to settings file.
new g_MinYesVotes = MIN_VOTES;

// Admin index and position
new g_eventAdmin;
new Float:g_vecAdminPos[3];

public OnPluginStart()
{
	// add admin commands
	RegAdminCmd("event_vote", CMD_EventStart, ADMFLAG_ROOT, "starts event via chat trigger");
	RegAdminCmd("event_block", CMD_EventBlock, ADMFLAG_ROOT, "blocks all autoevents from starting");
	RegAdminCmd("event_unblock", CMD_EventUnblock, ADMFLAG_ROOT, "removes autoevent block");
}

public OnMapStart()
{
	// reset values (in case of mapchange in the middle of event)
	g_eventAdmin = -1;
	g_blockerEnt = -1;
}

public Action:CMD_EventStart(client, args)
{
	// reject empty question
	if (args<=0)
	{
		PrintToChat(client, "Usage: /event_vote \"question\"");
		return Plugin_Handled;
	}
	
	if( !IsInDuel(client) )
	{
		if(!IsVoteInProgress())
		{
			if (!IsEventInProgress())
			{
				decl String:question[256];
				GetCmdArgString(question, sizeof(question));
				
				// store admin index for later
				g_eventAdmin = client;
				
				// start vote
				DisplayVote(question);
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

// Vote start function from Elmo's chess plugin
// I suppose these dynamic arrays required for SM's default voting system, which Elmo is using.
DisplayVote(const String:question[])
{
	if(!IsVoteInProgress())
	{
		//dynamic array for list of recipients
		new Handle:cl_arr_buff = CreateArray( 1, 0 );
		new numRecipients;
		for( new i = 1; i <= MaxClients; i++ )
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
		SetMenuTitle(menu, question);
		AddMenuItem(menu, "1", "Yes");
		AddMenuItem(menu, "2", "No");
		SetMenuExitButton(menu, false);
		VoteMenu(menu, cl_arr, numRecipients, INITAL_VOTE_TIME);
		
		//close dynamic array handle
		CloseHandle(cl_arr_buff);
	}
}

// Menu handler for Yes/No menu.
// This just means we don't need to do anything special when client chooses something (and before gathering results).
public InitialVoteMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// Voting results handler
// Teleports people to admin if they vote yes
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
	
	//get the number of clients that voted yes
	// ( only for comparing it to g_MinYesVotes. In this particular plugin we didn't need to )
	new num_yes_votes = 0;
	for( new i = 0; i < num_clients; i++ )
	{
		if( client_info[i][VOTEINFO_CLIENT_ITEM] == item_info[vote_yes_index][VOTEINFO_ITEM_INDEX] )
		{
			if( IsValidClient(client_info[i][VOTEINFO_CLIENT_INDEX]) )
			{
				if( !IsInDuel(client_info[i][VOTEINFO_CLIENT_INDEX]) )
				{
					num_yes_votes++;
				}
			}
		}
	}
	
	// teleport players
	if( num_yes_votes >= g_MinYesVotes )
	{
		// get position of admin.
		// main reason of making g_eventAdmin global. Because this vote doesn't know which player started it.
		// reason for global g_vecAdminPos will appear later
		GetClientAbsOrigin(g_eventAdmin, g_vecAdminPos);
		
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
							TeleportEntity(client_info[i][VOTEINFO_CLIENT_INDEX], g_vecAdminPos, NULL_VECTOR, NULL_VECTOR);
						}
						else
						{
							// if client is not alive but he did vote yes: hook his spawn event. We'll teleport him on spawn
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
		
		// block events
		g_blockerEnt = BlockEvents();
	}
}

// Player's spawn event
public ParticipantMissedInitialSpawn(client)
{
	if( IsValidClient(client) )
	{
		// this event fires two times: after your corpse vanishes, and after your actual spawn.
		// luckily, simple (IsPlayerAlive(client)) condition will say us which one is this
		if( IsPlayerAlive(client) )
		{
			// and thats why g_vecAdminPos is global.
			// maybe I could get new admin's position here, but I'm too lazy for this
			TeleportEntity(client, g_vecAdminPos, NULL_VECTOR, NULL_VECTOR);
			
			// we don't need this hook on this player anymore
			SDKUnhook(client, SDKHook_SpawnPost, ParticipantMissedInitialSpawn);
		}
	}
}

// unblock when admin leaves from his event
public OnClientDisconnect(client)
{
	if (client == g_eventAdmin && g_blockerEnt > MaxClients)
		UnblockEvents(g_blockerEnt);
}

//
public Action:CMD_EventBlock(client, args)
{
	if (IsEventInProgress())
	{
		PrintToChat(client, "%s Events are blocked already!", PLUGIN_PREFIX);
	}
	else
	{
		g_eventAdmin = client;
		g_blockerEnt = BlockEvents();
		PrintToChat(client, "%s Events are blocked now.", PLUGIN_PREFIX);
	}
	return Plugin_Handled;
}

//
public Action:CMD_EventUnblock(client, args)
{
	if (IsEventInProgress())
	{
		if (g_blockerEnt <= MaxClients)
		{
			PrintToChat(client, "%s Events are blocked by another event", PLUGIN_PREFIX);
		}
		else
		{
			UnblockEvents(g_blockerEnt);
			PrintToChat(client, "%s Events are unblocked now.", PLUGIN_PREFIX);
		}
	}
	else
	{
		PrintToChat(client, "%s Events are unblocked already!", PLUGIN_PREFIX);
	}
	return Plugin_Handled;
}
