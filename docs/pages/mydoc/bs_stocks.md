---
title: Stock functions
tags: [bs_stocks]
keywords: bs_stocks, stocks, include
last_updated: 24.09.2017
summary: "External *.inc files are useful for storing common functions and simplifying plugin's code"
sidebar: mydoc_sidebar
permalink: bs_stocks.html
folder: mydoc
---

## bs_stocks.inc file

[What and why]<br>
[Elmo's smlib and bs_stocks]<br>
[Place it into /addons/sourcemod/scripting/include/]<br>
[Mine: <a href="https://github.com/DiretideCandy/Blade-Symphony-Plugin-Examples/blob/master/addons/sourcemod/scripting/include/bs_stocks.inc">bs_stocks.inc</a>]

## Example

Example of simple bs_stocks.inc file:

```c
// This C stuff makes sure this file doesn't get included two or more times
#if defined _name_of_this_lib_included
 #endinput
#endif
#define _name_of_this_lib_included

// Include basic Sourcemod libraries if required by your functions
#include <sdktools>

// Optional but mostly helpful comment
/**
 * Get absolute value of integer
 *
 * @param x				Integer
 *
 * @return				Absolute value of integer. 
 */
stock int Abs(int x)
{
   return x>0 ? x : -x;
}
```

"stock" keyword marks this function as optional. Compiler won't write "symbol is never used: 'Abs'" warning for this function.
