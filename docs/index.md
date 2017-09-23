---
title: Introduction
keywords: homepage
tags: [introduction, home]
sidebar: mydoc_sidebar
permalink: index.html
---

[Insert some text here]

## Subheading 1

[Some basic info]

## Subheading 2

[something about first example]

Code from tutorial at <a href="https://wiki.alliedmods.net/Introduction_to_sourcemod_plugins">wiki.alliedmods.net</a>

```c
#include <sourcemod>

public Plugin myinfo =
{
	name = "My First Plugin",
	author = "Me",
	description = "My first plugin ever",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};
 
public void OnPluginStart()
{
	PrintToServer("Hello world!");
}
```

Let's add some basic stuff to it!<br>
First thing will be our favorite prefix for text strings. Symbols "\x01", "\x02", "\x03", etc. apply colors to subsequent letters, where "\x01" is default white:

```c
#include <sourcemod>

// add constant so you don't need to guess every time which acronym did you choose
#define PLUGIN_PREFIX "\x03[HW]\x01"

public Plugin myinfo =
{
	name = "My First Plugin",
	author = "Me",
	description = "My first plugin ever",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};
 
public void OnPluginStart()
{
	PrintToServer("%s Hello world!", PLUGIN_PREFIX);
	
	// Print message in chat to all players
	PrintToChatAll("%s Hello world!", PLUGIN_PREFIX);
}
```

Result in chat:
<img class="img-responsive img-full" src="{{ site.baseurl }}/index_hw_chat.png" alt="text in chat">

and in server's window:
<img class="img-responsive img-full" src="{{ site.baseurl }}/index_hw_server.png" alt="text in server">
Well, terminal obviously doesn't care about colors, but this looks nice in Windows anyway.

