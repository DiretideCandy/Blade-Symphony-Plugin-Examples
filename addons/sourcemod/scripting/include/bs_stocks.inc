#if defined _bs_stocks_included
 #endinput
#endif
#define _bs_stocks_included
#include <sdktools>

/**
 * @param x				Integer
 *
 * @return				Absolute value of integer. 
 */
stock int Abs(int x)
{
   return x>0 ? x : -x;
}

/**
 * Checks if client is valid.
 *
 * @param client		Client entity index to check.
 *
 * @return				True if valid, false otherwise. 
 */
stock bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}

/**
 * Checks if client is in duel.
 *
 * @param client		Client entity index to check.
 *
 * @return				True if in duel, false otherwise. 
 */
stock bool IsInDuel(int client)
{
	if(!IsClientInGame(client))
		return false;
	
	int g_DuelState[MAXPLAYERS+1];
	int m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	int ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
		return true;
	
	return false;
}

/**
 * Finds client entity index by client name.
 *
 * @param name_substr	Substring to be searched for.
 *
 * @return				-1 if no matches were found, 0 if >1 matches,
 *						client index if exactly 1 match was found. 
 */
stock int FindPlayerByName(char[] name_substr)
{
	int last_match = -1;
	int num_matches = 0;
	
	char name[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i))
		{
			bool bRes = GetClientName(i, name, sizeof(name));
			if (!bRes)
				continue;
			
			if (StrContains(name, name_substr, true) != -1)
			{
				last_match = i;
				num_matches += 1;
			}
		}
	}
	
	if (num_matches == 0)
		return -1;
	
	if (num_matches > 1)
		return 0;
	
	return last_match;
}

/**
 * Create brush (but we can't rotate them)
 * genertes one "non-brush" error into server console
 *
 * @param type			entity type name for CreateEntityByName("trigger_multiple");
 * @param spawnflags	spawnflags
 * @param vecPos		brush origin
 * @param size			brush size (wlh)
 * @noreturn
 */
stock int CreateBrush(const char[] type, const float vecPos[3],/* float vecDir[3],*/ const float size[3], const int spawnflags = 1)
{
	int ent;
	
	ent = CreateEntityByName(type);
	
	if (IsValidEntity(ent))
	{
		char flagsStr[10];
		Format(flagsStr, sizeof(flagsStr), "%d", spawnflags);
		DispatchKeyValue(ent, "spawnflags", flagsStr);
		
		DispatchKeyValue(ent, "wait", "0.0");		
	
		DispatchSpawn(ent);
		ActivateEntity(ent);
		TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
		//TeleportEntity(ent, NULL_VECTOR, vecDir, NULL_VECTOR);  //not working:(
		
		SetEntityModel(ent, "models/extras/info_speech.mdl");
		
		float minBounds[3]; 
		float maxBounds[3];
		for (int i; i < 3; i++)
		{
			maxBounds[i] = size[i]/2.0;
			minBounds[i] = -maxBounds[i];
		}
		
		SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
		SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
		
		SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
		
		int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
		enteffects |= 32;
		SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	
	}
	
	return ent;
}

stock public AntiShuriTouch(const String:output[], caller, activator, Float:delay)
{		
	//PrintToChatAll("AntiShuriTouch: %d", activator);

	if (activator > 32)
	{
		char name[32];
		GetEdictClassname(activator, name, sizeof(name));
		
		if (StrEqual(name, "berimbau_throwable"))
		{
			RemoveEntity(activator);
		}
	}
}

stock void DrawBeam(int& targetEntity, int& beamEntity, const float targetPos[3], const float beamPos[3], const char[] color)
{
	targetEntity = CreateEntityByName("env_sprite"); 
	SetEntityModel(targetEntity, "materials/particle/dys_beam_big_rect.vmt");
	DispatchKeyValue(targetEntity, "renderamt", "255");
	DispatchKeyValue(targetEntity, "rendercolor", "255 255 255"); 
	DispatchSpawn(targetEntity );
	AcceptEntityInput(targetEntity,"ShowSprite");
	ActivateEntity(targetEntity);
	TeleportEntity(targetEntity, targetPos, NULL_VECTOR, NULL_VECTOR);
	
	beamEntity = CreateEntityByName("env_beam");
	SetEntityModel( beamEntity, "materials/particle/dys_beam_big_rect.vmt");
	DispatchKeyValue(beamEntity, "rendermode", "0");
	DispatchKeyValue(beamEntity, "renderamt", "100");
	DispatchKeyValue(beamEntity, "rendermode", "0");
	DispatchKeyValue(beamEntity, "rendercolor", color);  
	DispatchKeyValue(beamEntity, "life", "0"); 		
	TeleportEntity(beamEntity, beamPos, NULL_VECTOR, NULL_VECTOR); 		
	DispatchSpawn(beamEntity);
	SetEntPropEnt(beamEntity, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beamEntity));
	SetEntPropEnt(beamEntity, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(targetEntity), 1);
	SetEntProp(beamEntity, Prop_Send, "m_nNumBeamEnts", 2);
	SetEntProp(beamEntity, Prop_Send, "m_nBeamType", 2);		
	SetEntPropFloat(beamEntity, Prop_Data, "m_fWidth",  3.0);
	SetEntPropFloat(beamEntity, Prop_Data, "m_fEndWidth", 3.0);
	ActivateEntity(beamEntity);
	AcceptEntityInput(beamEntity,"TurnOn");
}

/**
 * Remove entity.
 *
 * @param entity		Entity to remove.
 */
stock void RemoveEntity(entity)
{
	if ((entity > MaxClients) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Deactivate");
		AcceptEntityInput(entity, "Kill");
	}
}
