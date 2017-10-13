---
title: IsInDuel
tags: [bs_stocks]
keywords: bs_stocks, stocks, include, duel
last_updated: 24.09.2017
sidebar: mydoc_sidebar
permalink: bs_stocks_IsInDuel.html
folder: mydoc
---

Safety: 146% - Gormarim's and Elmo's versions are pretty much the same.

```c
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
```
