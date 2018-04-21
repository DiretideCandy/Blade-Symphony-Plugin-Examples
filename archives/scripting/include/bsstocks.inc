#if defined _bs_stocks_included
 #endinput
#endif
#define _bs_stocks_included
#include <sdktools>

/*
 * ActionId values
 */
#define BS_ACTIONID_BLOCK 0
#define BS_ACTIONID_INTERCEPT 1
#define BS_ACTIONID_GUARD 2
#define BS_ACTIONID_FEINT 3
#define BS_ACTIONID_BOW 5
#define BS_ACTIONID_ROLL 10
#define BS_ACTIONID_GRAB 13
#define BS_ACTIONID_DASH 12
#define BS_ACTIONID_SHURI 35

#define BS_ACTIONID_PHALANX_HEAVY_1 57
#define BS_ACTIONID_PHALANX_HEAVY_LEFT 59
#define BS_ACTIONID_PHALANX_HEAVY_RIGHT 60
#define BS_ACTIONID_PHALANX_AIR_1 62
#define BS_ACTIONID_PHALANX_AIR_LEFT 64
#define BS_ACTIONID_PHALANX_AIR_RIGHT 65

#define BS_ACTIONID_UNKNOWN 255

/*
 * GetSwordTypeId values
 */
#define BS_SWORDTYPEID_RAPIER 3
 
/**
 * Remove entity.
 *
 * @param entity		Entity to remove.
 *
 * @return				nothing
 */
stock RemoveEntity(entity)
{
	if (entity > MaxClients)
	{
		if (IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "Deactivate");
			AcceptEntityInput(entity, "Kill");
		}
	}
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
stock CreateBrush(const String:type[], const Float:vecPos[3],const Float:size[3], const spawnflags = 1)
{
	new ent = CreateEntityByName(type);
	
	if (IsValidEntity(ent))
	{
		decl String:flagsStr[10];
		Format(flagsStr, sizeof(flagsStr), "%d", spawnflags);
		DispatchKeyValue(ent, "spawnflags", flagsStr);
		
		DispatchKeyValue(ent, "wait", "0.0");		
	
		DispatchSpawn(ent);
		ActivateEntity(ent);
		TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
		//TeleportEntity(ent, NULL_VECTOR, vecDir, NULL_VECTOR);  //not working:(
		
		SetEntityModel(ent, "models/extras/info_speech.mdl");
		
		new Float:minBounds[3]; 
		new Float:maxBounds[3];
		for (new i; i < 3; i++)
		{
			maxBounds[i] = size[i] / 2.0;
			minBounds[i] = -maxBounds[i];
		}
		
		SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
		SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
		
		SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
		
		new enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
		enteffects |= 32;
		SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	
	}
	
	return ent;
}

// event function for antishuri trigger_multiple entities
public AntiShuriTouch(const String:output[], caller, activator, Float:delay)
{		
	if (activator > 32)
	{
		decl String:name[32];
		GetEdictClassname(activator, name, sizeof(name));
		
		if (StrEqual(name, "berimbau_throwable"))
		{
			RemoveEntity(activator);
		}
	}
}
/*
stock DrawBeam(int& targetEntity, int& beamEntity, const float targetPos[3], const float beamPos[3], const char[] color)
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
*/

/**
 * Checks if client is valid.
 *
 * @param client		Client entity index to check.
 *
 * @return				True if valid, false otherwise. 
 */
stock bool:IsValidClient(client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}

/**
 * Finds client entity index by client name.
 *
 * @param name_substr	Substring to be searched for.
 *
 * @return				-1 if no matches were found, 0 if >1 matches,
 *						client index if exactly 1 match was found. 
 */
stock FindPlayerByName(const String:name_substr[])
{
	new last_match = -1;
	new num_matches = 0;
	
	decl String:name[MAX_NAME_LENGTH];
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (IsValidClient(i))
		{
			new bool:bRes = GetClientName(i, name, sizeof(name));
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
 * Checks if client is in duel.
 *
 * @param client		Client entity index to check.
 *
 * @return				True if valid, false otherwise. 
 */
stock bool:IsInDuel(client)
{
	if(!IsClientInGame(client))
		return false;
	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
		return true;
	
	return false;
}

stock Abs(x)
{
   return x>0 ? x : -x;
}
stock Float:fAbs(Float:x)
{
   return x>0 ? x : -x;
}

stock GetActId(client)
{
	if (IsValidClient(client))
		//simple, because we don't need bCharging or iTierIndex
		return GetEntProp(client, Prop_Send, "m_ActionId");
	
	return -1;
}

stock Entity_FindByName(const String:entityName[], const String:entityClassName[])
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

stock GetSwordTypeId(client)
{
	if (!IsValidClient(client))
		return -1;
		
	return GetEntData(client, FindSendPropInfo("CBerimbauPlayer", "m_iSwordtypeId"));
}