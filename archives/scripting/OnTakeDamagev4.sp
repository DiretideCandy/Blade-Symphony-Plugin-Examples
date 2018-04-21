/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "OnTakeDamage Test01",
	author = "Gorm",
	description = "Atata",
	version = "1.0",
	url = "Poltora Kota"
}

/*public OnPluginStart()
{
	RegAdminCmd("hook_me", hook_me, ADMFLAG_RCON);
}

public Action:hook_me(client, args)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	return Plugin_Continue;
}
*/

public OnClientPutInServer(client) 
{ 
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage); 
} 

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	new String:attacker_name[32], String:victim_name[32], String:inflictor_name[32];
	new String:attacker_classname[32], String:victim_classname[32], String:inflictor_classname[32];
	
	GetClientName(attacker, attacker_name, 32);
	GetEntityClassname(attacker, attacker_classname, 32);
	GetClientName(victim,victim_name,32);
	GetEntityClassname(victim, victim_classname, 32);
	GetClientName(inflictor, inflictor_name, 32);
	GetEntityClassname(inflictor, inflictor_classname, 32);
	
	//PrintToChatAll("%s was attacked by %s", attacker_name, victim_name);
	
	//PrintToChatAll("Attacker Name: %s\nAttacker Classname: %s", attacker_name, attacker_classname);
	//PrintToChatAll("Victim Name: %s\nVictim Classname: %s", victim_name, victim_classname);
	//PrintToChatAll("Inflictor Name: %s\nInflictor Classname: %s", inflictor_name, inflictor_classname);
	
	PrintToChatAll("%f damage to %s", damage, victim_name);
	return Plugin_Continue;
}
	