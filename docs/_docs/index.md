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

[about first example]

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

