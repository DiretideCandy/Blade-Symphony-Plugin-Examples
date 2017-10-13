---
title: BlockEvents()
tags: [bs_eventBlock]
keywords: event, block, stocks, include
last_updated: 13.10.2017
sidebar: mydoc_sidebar
permalink: eventblock_BlockEvents.html
folder: mydoc
---

Safety: 90%? - It won't create new same entity if there is already one. Also, maps with maximum number of entities shouldn't exist. And make sure you don't create map with entity named "ct_event_blocker_sprite_ct" in it. 

Jokes aside, you must carefuly store index of blocking entity to destroy it after event. This storing should take into account sudden mapchanges during event. Worst case scenario: someone starts bchess voting (no block yet), then admin enters manual /event_block command. This command (unlike event voting start commands) doesn't have vote-in-progress checks and blocks events. Chess event can't create new blocking entity after successful vote and can't remove block after event ends.

```c
// when event wants to start, it will search for existing env_sprite with this name
#define EVENT_BLOCKER_NAME "ct_event_blocker_sprite_ct"

/**
 * Create blocking entity.
 *
 * @return				Index of entity. 
 */
stock BlockEvents()
{
	if (IsEventInProgress()) // another function from this inc file
		return -1;
		
	// Create Entity
	new ent = CreateEntityByName("env_sprite");
	
	if (ent > MaxClients)
	{
		// apply name to entity
		DispatchKeyValue(ent, "targetname", EVENT_BLOCKER_NAME);	
		
		// complete spawning entity
		DispatchSpawn(ent);
	}
	
	//PrintToChatAll("new ent %d!", ent);
	return ent;
}
```

Function returns entity index, this means plugin should store it itself. To unblock events plugin must pass this index to UnblockEvents() function.