#include <sourcemod> 	// always here
#include <sdkhooks>		
#include <sdktools>		

#include <bsstocks>

#define TRIGGER_NAME "ct_antishuri_321321321"

public Plugin:myinfo =
{
	name = "AntiShuri Triggers",
	author = "Crystal",
	description = "",
	version = "1.0",
	url = "https://diretidecandy.github.io/Blade-Symphony-Plugin-Examples/index.html"
};


//======================================//
//										//
//		   Main Body Of Plugin			//
//										//
//======================================//
public OnPluginStart()
{
	RegAdminCmd("antishuri_reload", CMD_Reload, ADMFLAG_ROOT);
}

public OnMapStart()
{
	LoadTriggers();
}

public Action:CMD_Reload(client, args)
{
	RemoveTriggers();
	
	LoadTriggers();
	
	return Plugin_Handled;
}

LoadTriggers()
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/ct_antishuri.txt");
	
	// create Handle for KeyValues and load them from file
	new Handle:kv = CreateKeyValues("triggers");
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[AntiShuri] File <plugins/ct_antishuri.txt> not found.");
	}
	else
	{
		if (!KvGotoFirstSubKey(kv))
		{
			PrintToServer("[AntiShuri] No triggers in <plugins/ct_antishuri.txt>");
			
		}
		else
		{
			new Float:origin[3];
			new Float:size[3];
			do
			{
				
				KvGetVector(kv, "origin", origin);
				KvGetVector(kv, "wlh", size);
				
				new ent = CreateNamedBrush("trigger_multiple", origin, size, 1103, TRIGGER_NAME);
				HookSingleEntityOutput(ent, "OnStartTouch", AntiShuriTouch, false);
				
			} while (KvGotoNextKey(kv));
		}
	}
	CloseHandle(kv);
}

RemoveTriggers()
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "trigger_multiple")) != -1)
	{
		decl String:strName[50];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));

		if(strcmp(strName, TRIGGER_NAME) == 0)
		{
			//PrintToChatAll("[AntiShuri] Removing entity #%d", index);
			RemoveEntity(index);
		}
	}
}

CreateNamedBrush(const String:type[], const Float:vecPos[3],const Float:size[3], const spawnflags = 1, const String:name[] = "")
{
	new ent = CreateEntityByName(type);
	
	//PrintToChatAll("[AntiShuri] Creating entity #%d", ent);
	if (IsValidEntity(ent))
	{
		decl String:flagsStr[10];
		Format(flagsStr, sizeof(flagsStr), "%d", spawnflags);
		DispatchKeyValue(ent, "spawnflags", flagsStr);
		
		DispatchKeyValue(ent, "wait", "0.0");		
		DispatchKeyValue(ent, "targetname", name);
	
		DispatchSpawn(ent);
		ActivateEntity(ent);
		TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
		//TeleportEntity(ent, NULL_VECTOR, vecDir, NULL_VECTOR);  //not working:(
		
		SetEntityModel(ent, "models/extras/info_speech.mdl");
		
		new Float:minBounds[3]; 
		new Float:maxBounds[3];
		for (new i = 0; i < 3; i++)
		{
			maxBounds[i] = size[i]/2.0;
			minBounds[i] = -maxBounds[i];
		}
		
		SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
		SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
		
		SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
		
		new enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
		enteffects |= 32;
		SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	
	}
	
	return ent;
}

public Action:CMD_Test(client, args)
{
	if (args >= 3)
	{
		new Float:target[3];
		for (new i = 0; i < 3; i++)
		{
			decl String:arg[32];
			GetCmdArg(i+1, arg, sizeof(arg));
			
			target[i] = StringToFloat(arg);
		}
		TeleportEntity(client, target, NULL_VECTOR, NULL_VECTOR);
	}
	return Plugin_Handled;
}