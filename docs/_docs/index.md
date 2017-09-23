---
title: Introduction
permalink: index.html
sidebar: generic
topnav: topnav
---

[Insert some text here]

## Subheading 1

[Some basic info]

## Subheading 2

[something about first example]
Code from tutorial at https://wiki.alliedmods.net/Introduction_to_sourcemod_plugins

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

Let's add some basic stuff to it! 
First thing will be our favorite prefix for text strings. Symbols "\x01", "\x02", etc. apply colors to

<a href="https://github.com/DiretideCandy/Blade-Symphony-Plugin-Examples/blob/master/addons/sourcemod/scripting/examples/hello_world_modified.sp">plugin</a>
```c
#define PLUGIN_PREFIX "\x03[HW]\x01"

public void OnPluginStart()
{
	PrintToServer("%s Hello world!", PLUGIN_PREFIX);
	PrintToChatAll("%s Hello world!", PLUGIN_PREFIX);
}
```

Results in chat:
<img class="img-responsive img-full" src="{{ site.baseurl }}/img/index_hw_chat.png" alt="text in chat">

and in server's window:
<img class="img-responsive img-full" src="{{ site.baseurl }}/img/index_hw_server.png" alt="text in server">