#if defined _bs_eventblock_included
 #endinput
#endif
#define _bs_eventblock_included
#include <sdktools>

#define EVENT_BLOCKER_NAME "ct_event_blocker_sprite_ct"

/**
 * Create blocking entity.
 *
 * @return				Index of entity. 
 */
stock BlockEvents()
{
	if (IsEventInProgress())
		return -1;
		
	// Create Entity
	new ent = CreateEntityByName("env_sprite");
	
	if (ent > MaxClients)
	{
		DispatchKeyValue(ent, "targetname", EVENT_BLOCKER_NAME);
		DispatchSpawn(ent);
	}
	
	//PrintToChatAll("new ent %d!", ent);
	return ent;
	
}

/**
 * Find blocking entity
 *
 * @return				true if entity found, false otherwise
 */
stock bool:IsEventInProgress()
{
	// Entity_FindByName
	
	new index = -1;
	while ((index = FindEntityByClassname(index, "env_sprite")) != -1)
	{
		decl String:strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		
		//PrintToChatAll(strName);
		if (strcmp(strName, EVENT_BLOCKER_NAME) == 0)
			break;
	}
	//PrintToChatAll("ent index is %d!", index);
	return (index!=-1);
}

/**
 * Remove blocking entity
 *
 * @param x				index of blocking entity
 *
 * @noreturn
 */
stock UnblockEvents(blockerEnt)
{
	//PrintToChatAll("removing %d!", blockerEnt);
	if (blockerEnt > MaxClients)
	{
		if (IsValidEdict(blockerEnt))
		{
			AcceptEntityInput(blockerEnt, "Deactivate");
			AcceptEntityInput(blockerEnt, "Kill");
		}
	}
}