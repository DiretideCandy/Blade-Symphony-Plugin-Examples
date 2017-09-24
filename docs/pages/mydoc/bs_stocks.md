---
title: bs_stocks.inc
tags: [bs_stocks]
keywords: bs_stocks, stocks, include
last_updated: 24.09.2017
datatable: true
summary: "External *.inc files are useful for storing common functions and simplifying plugin's code"
sidebar: mydoc_sidebar
permalink: bs_stocks.html
folder: mydoc
---

## bs_stocks.inc file

[What and why]

## Example

Example of simple .inc file:

```c
// this C stuff makes sure this file don't get included two or more times
#if defined _bs_stocks_included
 #endinput
#endif
#define _bs_stocks_included

// include basic Sourcemod libraries if required by your functions
#include <sdktools>

// optional but mostly helpful comment
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

'stock' keyword marks this function as optional. Compiler won't write 'symbol is never used: "Abs"' warning for this function.