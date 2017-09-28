---
title: Knockback plugin
tags: [plugin, knockback, kotr]
keywords: plugin, knockback, raffle, kotr
last_updated: 27.09.2017
sidebar: mydoc_sidebar
permalink: kotr_knockback.html
folder: mydoc
---

Simple plugin for pushing players on damage.

* Pushes player away from attacker
* Pushes only when player is inside trigger_multiple, provided by map
<br><br>
<a href="https://github.com/DiretideCandy/Blade-Symphony-Plugin-Examples/blob/master/addons/sourcemod/scripting/kotr_knockback.sp" target="_blank">.sp file for SM 1.6</a>


## Pushing players

To push players we need to detect damage, received by them. Luckily, Sourcemod libraries have OnTakeDamage event, therefore we don't need to monitor health of players every frame or something like that.

We can see there how action declaration should look like, let's prepare it for adding pushing:

```c
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	// check if this is player-to-player damage
	if (!IsValidClient(attacker) || !IsValidClient(victim))
		return Plugin_Continue;
		
	if (damage <= 0.0)
		return Plugin_Continue;
		
	/* 
		Push player here
	*/
		
	return Plugin_Continue;
}
```

This code executes right before game's code for dealing damage, and by returning Plugin_Continue value we tell Soucemod that we want game to continue executing original damage event. If we would need to prevent damage to player, we should return Plugin_Handled value.
<br>
Obvious choice for pushing players is <a href="https://sm.alliedmods.net/api/index.php?fastload=show&id=40&" target="_blank">TeleportEntity</a> function. It requires 4 arguments: entity to teleport, target position, direction and velocity. [][]

<ul id="profileTabs" class="nav nav-tabs">
<li class="active"><a href="#onepointeight" data-toggle="tab">1.6</a></li>
<li><a href="#onepointsix" data-toggle="tab">1.8</a></li>
</ul>
<div class="tab-content">
<div role="tabpanel" class="tab-pane active" id="onepointeight">
<p>1.8 code will be here</p>
</div>

<div role="tabpanel" class="tab-pane" id="onepointsix">
```c
PrintToServer("Hellow World!");
```
</div>
</div>