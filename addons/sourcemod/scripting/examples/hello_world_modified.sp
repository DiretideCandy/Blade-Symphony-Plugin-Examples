#include <sourcemod>

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
	PrintToChatAll("%s Hello world!", PLUGIN_PREFIX);
}