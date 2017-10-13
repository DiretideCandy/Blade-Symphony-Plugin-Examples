---
title: IsEventInProgress()
tags: [bs_stocks]
keywords: bs_stocks, stocks, include, duel
last_updated: 13.10.2017
sidebar: mydoc_sidebar
permalink: eventblock_IsEventInProgress.html
folder: mydoc
---

Safety: 100% - Probably a bit expensive if map has maximum entities and almost all of them are env_sprite? Should be fine, its not like it being called often.

```c
#define EVENT_BLOCKER_NAME "ct_event_blocker_sprite_ct"

/**
 * Find blocking entity
 *
 * @return				true if entity found, false otherwise
 */
stock bool:IsEventInProgress()
{
	//should be just one line:
	//return Entity_FindByName(EVENT_BLOCKER_NAME, "env_sprite")!=-1;
	//but I didn't add Entity_FindByName to bs_stocks yet

	new index = -1;
	
	// this loop cycles though every env_sprite on the map until it finds one with name	EVENT_BLOCKER_NAME
	while ((index = FindEntityByClassname(index, "env_sprite")) != -1)
	{
		decl String:strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		
		if (strcmp(strName, EVENT_BLOCKER_NAME) == 0)
			break;
	}
	
	return (index!=-1);
}
```
