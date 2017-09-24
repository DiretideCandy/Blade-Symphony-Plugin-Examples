---
title: IsValidClient
tags: [bs_stocks]
keywords: bs_stocks, stocks, include, valid, client
last_updated: 24.09.2017
sidebar: mydoc_sidebar
permalink: bs_stocks_IsValidClient.html
folder: mydoc
---

Safety: 146% - Gormarim and Elmo both had it like this.

```c
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
```

<br>
Every entity on the map has its index and every player is an entity with index between 1 and current Maximum of players. You can access server's maximum number of players value with Sourcemod's constant MaxClients. Also, at any time you can see players' indexes ingame with console command status:
<img class="img-responsive img-full" src="{{ site.baseurl }}/images/isvalidclient_indexes.png" alt="status result">
second column in result are player entity indexes
<br><br>
Most Sourcemod functions (if they work with players) will fail if you pass them invalid client (for example: you stored one and player disconnected). 
Let's look at this simple command:
```c
public Action simple_command(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
		PrintToChat(i, "%s Hi!", PLUGIN_PREFIX);
	
	PrintToServer("<<test>> Done!");
}
```
After calling it you expect to see a new message in server's console, but it will only appear if the server is full! If even one player slot is empty, PrintToChat function receives invalid argument, fails, and execution of this action stops.
<br>
Every time you must make sure that number you pass is a valid client:
```c
public Action simple_command(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			PrintToChat(i, "%s Hi!", PLUGIN_PREFIX);
	
	PrintToServer("<<test>> Done!");
}
```
<br><br>
Unnecessary note. This function (and not only this) will work incorrectly if someone hosts a server from a game itself: in this case he must be addressed as player with index 0. You should avoid this by hosting a srcds server on the same computer instead.