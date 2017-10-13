---
title: UnblockEvents()
tags: [bs_eventBlock]
keywords: event, block, stocks, include
last_updated: 13.10.2017
sidebar: mydoc_sidebar
permalink: eventblock_UnblockEvents.html
folder: mydoc
---

Safety: not safe - This function will remove given entity. Probably should check not "does somewhere on the map exist a blocker entity?", but "Is this given entity a blocker entity?".

```c
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
```
