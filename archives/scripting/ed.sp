#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
// <- Crystal's comment// #include <smlib>
// <- Crystal's comment// #include <berimbaulib>

#define MAX_CLIENTS 129

public Plugin:myinfo =
{
	name = "BS Create Duel",
	author = "Elmo, the Grand Defiler of Souls",
	description = "create a duel between up to 4 players",
	version = "0.1",
	url = "elmers<3"
};
//==============================================//
//												//
//				Configuration Vars				//
//												//
//==============================================//
new Handle:g_hAddPlayerToDuel = INVALID_HANDLE;
new Handle:g_hSetDuel = INVALID_HANDLE;
new Handle:g_hStartWarmup = INVALID_HANDLE;
new Handle:g_hGetCHandleCBaseEntity = INVALID_HANDLE;
new Handle:g_hRemoveFromDuelList = INVALID_HANDLE;
//==============================================//
//												//
//			  Main Body of Plugin				//
//												//
//==============================================//
public OnPluginStart()
{
	RegAdminCmd("create_duel", Command_CreateDuel, ADMFLAG_ROOT, "create duel between players");
	RegAdminCmd("get_info", TEST, ADMFLAG_ROOT);
	LoadTranslations("commmon.phrases");
	
	//CBerimbauDuel::AddPlayer(CHandle<CBaseEntity>)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CBerimbauDuel9AddPlayerE7CHandleI11CBaseEntityE", 0);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hAddPlayerToDuel = EndPrepSDKCall();
	
	//BerimbauPlayer::SetDuel(CBerimbauDuel *)
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN15CBerimbauPlayer7SetDuelEP13CBerimbauDuel", 0);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSetDuel = EndPrepSDKCall();
		
	//CBerimbauDuel::StartWarmup(void)
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CBerimbauDuel11StartWarmupEv", 0);
	g_hStartWarmup = EndPrepSDKCall();
	
	//CBaseEntity::GetRefEHandle(void)const
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZNK11CBaseEntity13GetRefEHandleEv", 0);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hGetCHandleCBaseEntity = EndPrepSDKCall();
	
	//Berimbau::DuelList::Remove(CBerimbauDuel *)
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN8Berimbau8DuelList6RemoveEP13CBerimbauDuel", 0);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hRemoveFromDuelList = EndPrepSDKCall();
}

public Action:TEST(client, args)
{
	new Duel = GetClientDuelId(client);
	PrintToChat(client, "Duel = %i", Duel);
	if( Duel != 0 )
	{
		//PrintToChat(client, "DuelID = %i", GetEntData(Duel, GetEntSendPropOffs(Duel,"m_DuelID"), 1));
		PrintToChat(client, "DuelID = %i EndTime = %f", GetEntProp(Duel, Prop_Send, "m_DuelID"), GetEntPropFloat(Duel, Prop_Send, "m_flEndTime"));
	}
	return Plugin_Handled;
}


public Action:Command_CreateDuel(client, args)
{
	decl String:Target1[MAX_NAME_LENGTH], String:Target2[MAX_NAME_LENGTH], String:Target3[MAX_NAME_LENGTH], String:Target4[MAX_NAME_LENGTH], String:buffer[MAX_NAME_LENGTH], Player1, Player2, Player3, Player4;
	GetCmdArg(1, Target1, sizeof(Target1));
	GetCmdArg(2, Target2, sizeof(Target2));
	GetCmdArg(3, Target3, sizeof(Target3));
	GetCmdArg(4, Target4, sizeof(Target4));
		
	if(args < 2)
	{
		PrintToChat(client, "\x04[\x03BS\x04]:\x03usage: /create_duel <Player 1> <Player 2> <Player 3> <Player 4>");
		return Plugin_Handled;
	}
	
	new targets[MAX_CLIENTS], bool:ml = false;

	new count = ProcessTargetString(Target1, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
	if (count <= 0)
	{
		PrintToChat(client, "\x04[\x03BS\x04]:\x03Bad Target 1 q_q");	
	}
	else for (new i = 0; i < count; i++)
	{
		Player1 = targets[i];
	}
	
	new count2 = ProcessTargetString(Target2, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
	if (count2 <= 0)
	{
		PrintToChat(client, "\x04[\x03BS\x04]:\x03Bad Target 2 q_q");	
	}
	else for (new i = 0; i < count; i++)
	{
		Player2 = targets[i];
	}
	
	new count3 = ProcessTargetString(Target3, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
	if (count3 <= 0)
	{
		PrintToChat(client, "\x04[\x03BS\x04]:\x03Bad Target 3 q_q");	
	}
	else for (new i = 0; i < count; i++)
	{
		Player3 = targets[i];
	}
	
	new count4 = ProcessTargetString(Target4, client, targets, sizeof(targets), COMMAND_FILTER_NO_MULTI, buffer, sizeof(buffer), ml);
	if (count4 <= 0)
	{
		PrintToChat(client, "\x04[\x03BS\x04]:\x03Bad Target 4 q_q");	
	}
	else for (new i = 0; i < count; i++)
	{
		Player4 = targets[i];
	}
	
	
	if( IsValidClient(Player1) && IsValidClient(Player2) && (args == 2) )
	{
		//1v1 desired
		Create1v1(Player1, Player2);
		ReplyToCommand(client, "\x04[\x03BS\x04]:\x03Successfully created 1v1 duel.");
	}
	else if( IsValidClient(Player1) && IsValidClient(Player2) && IsValidClient(Player3) && (args == 3) )
	{
		//1v2 desired
		Create1v2(Player1, Player2, Player3);
		ReplyToCommand(client, "\x04[\x03BS\x04]:\x03Successfully created 1v2 duel.");
	}
	else if( IsValidClient(Player1) && IsValidClient(Player2) && IsValidClient(Player3) && IsValidClient(Player4) && (args == 4) )
	{
		//2v2 desired
		Create2v2(Player1, Player2, Player3, Player4);
		ReplyToCommand(client, "\x04[\x03BS\x04]:\x03Successfully created 2v2 duel.");
	}
	else
	{
		//error
		ReplyToCommand(client, "\x04[\x03BS\x04]:\x03Error: one or more target clients were invalid.");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

Create1v1(Player1, Player2)
{
	new Duel = CreateEntityByName("berimbau_duel");
	if( IsValidEntity(Duel) )
	{
		// <- Crystal's comment// if( Entity_ClassNameMatches(Duel, "berimbau_duel") )
		{
			SetEntProp(Duel, Prop_Send, "m_iNumRounds", 3);
			SetEntProp(Duel, Prop_Send, "m_iRequiredPlayers", 2);
			SetEntProp(Duel, Prop_Send, "m_State", 3);
			SetEntProp(Duel, Prop_Send, "m_iPVPMode", 0);
			//SetEntPropFloat(Duel, Prop_Send, "m_flEndTime", 2200.0);
			DispatchSpawn(Duel);
			ActivateEntity(Duel);
			
			AddToDuel(Duel, Player1);
			AddToDuel(Duel, Player2);
			SetDuel(Duel, Player1);
			SetDuel(Duel, Player2);
			StartWarmUp(Duel);
		}
	}
}

Create1v2(Player1, Player2, Player3)
{
	new Duel = CreateEntityByName("berimbau_duel");
	if( IsValidEntity(Duel) )
	{
		// <- Crystal's comment// if( Entity_ClassNameMatches(Duel, "berimbau_duel") )
		{
			SetEntProp(Duel, Prop_Send, "m_iNumRounds", 3);
			SetEntProp(Duel, Prop_Send, "m_iRequiredPlayers", 3);
			SetEntProp(Duel, Prop_Send, "m_State", 3);
			SetEntProp(Duel, Prop_Send, "m_iPVPMode", 1);
			DispatchSpawn(Duel);
			ActivateEntity(Duel);
			
			AddToDuel(Duel, Player1);
			AddToDuel(Duel, Player2);
			AddToDuel(Duel, Player3);
			SetDuel(Duel, Player1);
			SetDuel(Duel, Player2);
			SetDuel(Duel, Player3);
			StartWarmUp(Duel);
		}
	}
}

Create2v2(Player1, Player2, Player3, Player4)
{
	new Duel = CreateEntityByName("berimbau_duel");
	if( IsValidEntity(Duel) )
	{
		// <- Crystal's comment// if( Entity_ClassNameMatches(Duel, "berimbau_duel") )
		{
			SetEntProp(Duel, Prop_Send, "m_iNumRounds", 3);
			SetEntProp(Duel, Prop_Send, "m_iRequiredPlayers", 4);
			SetEntProp(Duel, Prop_Send, "m_State", 3);
			SetEntProp(Duel, Prop_Send, "m_iPVPMode", 2);
			DispatchSpawn(Duel);
			ActivateEntity(Duel);
			
			AddToDuel(Duel, Player1);
			AddToDuel(Duel, Player2);
			AddToDuel(Duel, Player3);
			AddToDuel(Duel, Player4);
			SetDuel(Duel, Player1);
			SetDuel(Duel, Player2);
			SetDuel(Duel, Player3);
			SetDuel(Duel, Player4);
			StartWarmUp(Duel);
		}
	}
}

SetDuel(DuelEntity, ToBeAdded)
{
	SDKCall(g_hSetDuel, ToBeAdded, DuelEntity);	
}

AddToDuel(DuelEntity, ToBeAdded)
{
	new Reference = SDKCall(g_hGetCHandleCBaseEntity, ToBeAdded);
	SDKCall(g_hAddPlayerToDuel, DuelEntity, Reference);
}

StartWarmUp(DuelEntity)
{
	SDKCall(g_hStartWarmup, DuelEntity);
}

RemoveFromDuelList(DuelEntity)
{
	SDKCall(g_hRemoveFromDuelList, DuelEntity);
}

bool:IsValidClient(client)
{
	if(1 <= client <= MaxClients)
	{
		if( IsValidEntity(client) )
		{
			if( IsClientInGame(client) && !IsInDuel(client))
			{
				return true;
			}
		}
	}
	return false;
}
/*
	new Float:RealTimeLeft;
	RealTimeLeft = GetConVarFloat(FindConVar("mp_timelimit_free"));
	RealTimeLeft = FloatSub(RealTimeLeft, FloatDiv(GetGameTime(), 60.0));
	if( RealTimeLeft < 0.0 )
	{
		RealTimeLeft = 0.0;
	}
	if( RealTimeleft == 0.0 && !AreThereAnyDuellers() )
	{
		decl String:NextMap[128];
		new bool:NextMapExists = GetNextMap(NextMap, sizeof(NextMap));
		if( !NextMapExists )
		{
			GetCurrentMap(NextMap, sizeof(NextMap));
		}
		
		//ServerCommand("changelevel %s", NextMap);
		PrintToServer("map would have been changed to %s", NextMap);
	}
	
	PrintToChat(client, "RealTimeLeft = %0.2f", RealTimeLeft);
	return Plugin_Handled;

bool:AreThereAnyDuellers()
{
	new DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, DuelState, 34, 4);
	
	for(new i = 0; i <= MAXPLAYERS; i++ )
	{
		if( DuelState[i] != 0 )
		{
			return true;
		}
	}
	
	return false;
}

*/



//==============================================================//
//												                //
//		Crystal's "Something like Elmo's BERIMBAULIB"			//
//												                //
//==============================================================//
bool:IsInDuel(client)
{
	
	if(!IsClientInGame(client))
	{
		return false;
	}
	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
	{
		return true;
	}
	
	return false;
}

GetClientDuelId(client)
{
	if(!IsClientInGame(client))
	{
		return 0;
	}
	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	return g_DuelState[client];
}