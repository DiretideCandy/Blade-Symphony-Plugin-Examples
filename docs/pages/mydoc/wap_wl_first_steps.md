---
title: First steps
tags: [wap, weakest, link]
keywords: writing, first, weakest, link
last_updated: 25.09.2017
sidebar: mydoc_sidebar
permalink: wap_wl_first_steps.html
folder: mydoc
---

Simple event plugin:<br>
FFA on Arena. When player dies -> reset round without this player.
<br><br>
Initial goals:
* Admin commands for starting event manually
	1. /wl_add &lt;index of player&gt;<br>
	Adding players to event. We'll worry about automatic player gathering later.
	2. /wl_start<br>
	Start event when everyone ready.
	3. /wl_reset<br>
	Command for testing. Resets variables and entities to initial values and positions
* Event's logic