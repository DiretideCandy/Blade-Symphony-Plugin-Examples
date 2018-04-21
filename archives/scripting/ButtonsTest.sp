#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_BUTTONS 25
new g_LastButtons[MAXPLAYERS+1];


public Plugin myinfo = 
{
	name = "",
	author = "Crystal",
	description = "",
	version = "0.00000001",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("test", Test_Test);
}

public Action Test_Test(client, args)
{
	
}

public OnClientDisconnect_Post(client)
{
	g_LastButtons[client] = 0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	for (new i = 0; i < MAX_BUTTONS; i++)
	{
		new button = (1 << i);
		
		if ((buttons & button))
		{
			if (!(g_LastButtons[client] & button))
			{
				OnButtonPress(client, button);
			}
		}
		else if ((g_LastButtons[client] & button))
		{
			OnButtonRelease(client, button);
		}
	}
	
	g_LastButtons[client] = buttons;
	
	return Plugin_Continue;
}

OnButtonPress(client, button)
{
	// do stuff
	PrintToChat(client, "button Pressed %d", button);
}

OnButtonRelease(client, button)
{
	// do stuff
	PrintToChat(client, "button Released %d", button);
}