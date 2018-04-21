//never ever make a plugin as sloppy and terrible as this one...I'm extremely ashamed of it.

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <berimbaulib>

#define DEFAULT_CHAR_TYPE_MAT1 1
#define DEFAULT_CHAR_TYPE_MAT2 1
#define OUTOFBOUNDSDMG 8
#define OUTOFBOUNDSDMG_Float 8.0

/*bugs & todo list
[done] 1.) on ring out, check hp to make sure death glitch doesn't happen
[done] 2.) skele bug
[done] 3.) global message on match start
[done] 4.) downed state fix on reset
[done] ? 5.) string reset
[done] 6.) fix messages
[done] 7.) voting disabling?
[done] 8.) bushido mode
[done] 9.) immobilize both players on ring out
[done] 10.) re-align player angles on reset

vaerix suggestions:
1.) cvars for attachments ( vs_genericattachment)

new bugs:
[done] 1.) hologram doesn't match global setting on reset
[done] 2.) disable rules when match starts
[done] 3.) rules don't last long enough?
[done] 4.) set bushido hp and 100 hp after spawn inside mat, not before
[done] 5.) death bug still exists (possibly ring out related still)
[done] 6.) jian intercept: filter from the damage hook
[done] 7.) 100 hp on accepting the settings
[done] 8.) collision on button for on/off
[done] 9.) check for character model on mat 1 trigger, force character to selected settings if no match.
10.) prevent map change until all kendo matches are done
[done] 11.) give full hp at kendo end
[done] 12.) whenever someone registers, block the settings button for 10 seconds.
[done] 13.) add 0.5 - 1 second freeze on reset
[done] 14.) allow stance change on freeze


raffle: func_tracktrain
raffle: kendo_mat_1_camera


DONE: --> 				 <---
raffle: oh ok letm e see
raffle: when someone registers
raffle: kendo_mat_1_plat1_model
raffle: output is: skin
raffle: the skin is 4
raffle: when the plat is free, change the skin back to 3
raffle: same thing for plat2, kendo_mat_1_plat2_model
raffle: when registered, skin is 7, when back to normal its 6



latest bugs:
[DONE] 1.) buffer timer for short freeze

DONE: -->	Maybe?			<--
raffle: alright
raffle: so
raffle: while someone is diying
raffle: if you step out, you freeze him in death
raffle: and we get the death bug
raffle: basically flower just reproduced what we were lookin for all along
raffle: also, mouse1+mouse2 still grabs
Elmo, The Grand Defiler Of Souls: wtf really?
Elmo, The Grand Defiler Of Souls: alright, but the ring out info is good, I'll just check both participants health on ring out, instead of just the activator
Elmo, The Grand Defiler Of Souls: I'll add mouse1 + mouse2 to the list of inputs that should be blocked

*/

public Plugin:myinfo =
{
	name = "Sexy Food Auto Kendo",
	author = "Elmo, the Grand Defiler of Souls",
	description = "test",
	version = "0.1",
	url = "http://steamcommunity.com/groups/2sexy4me"
};
//==============================================//
//												//
//					Client Vars					//
//												//
//==============================================//
//===================Mat 1=======================//
new g_KendoMat1_Participants[MAXPLAYERS+1] = {0,...};
new bool:g_Mat1_Client_Blocked[MAXPLAYERS+1] = {false,...};
new bool:g_Mat1_Client_Intercepted[MAXPLAYERS+1] = {false,...};

new bool:g_Mat1_Plat1_Client_Confirmation = false;
new bool:g_Mat1_Plat2_Client_Confirmation = false;

//===================Mat 2=======================//
new g_KendoMat2_Participants[MAXPLAYERS+1] = {0,...};
new bool:g_Mat2_Client_Blocked[MAXPLAYERS+1] = {false,...};
new bool:g_Mat2_Client_Intercepted[MAXPLAYERS+1] = {false,...};

new bool:g_Mat2_Plat1_Client_Confirmation = false;
new bool:g_Mat2_Plat2_Client_Confirmation = false;

//==============================================//
//												//
//					Config Vars					//
//												//
//==============================================//
//===================Mat 1=======================//
new Float:g_vec_KendoMat1Start_plat1[3];
new Float:g_vec_KendoMat1Start_plat2[3];
new Float:g_vec_KendoMat1Exit_plat1[3];
new Float:g_vec_KendoMat1Exit_plat2[3];
new Float:g_vec_KendoMat1View_plat1[3];
new Float:g_vec_KendoMat1View_plat2[3];

new g_Mat1_RoundStart_Sound_Ent;
new g_Mat1_RoundEnd_Sound_Ent;
new g_Mat1_Rules_Plat1_Ent;
new g_Mat1_Rules_Plat2_Ent;
new g_Mat1_Character_Type_Button_Model;
new g_Mat1_Character_Type_Button_Func;
new g_Mat1_Character_Type_Button_Text;

new g_Mat1_Plat1_Model;
new g_Mat1_Plat2_Model;

new g_Mat1_Hologram_Pure;
new g_Mat1_Hologram_Phalanx;
new g_Mat1_Hologram_Judgement;
new g_Mat1_Hologram_Ryoku;

new g_Mat1_Bushido_Symbol;
new g_Mat1_Bushido_Text;

new g_Mat1_Character_Type = DEFAULT_CHAR_TYPE_MAT1;
new bool:g_Bushido_Mat1 = false;

new g_OldTickCount = 0;
new g_NewTickCount;

//===================Mat 2=======================//
new Float:g_vec_KendoMat2Start_plat1[3];
new Float:g_vec_KendoMat2Start_plat2[3];
new Float:g_vec_KendoMat2Exit_plat1[3];
new Float:g_vec_KendoMat2Exit_plat2[3];
new Float:g_vec_KendoMat2View_plat1[3];
new Float:g_vec_KendoMat2View_plat2[3];

new g_Mat2_RoundStart_Sound_Ent;
new g_Mat2_RoundEnd_Sound_Ent;
new g_Mat2_Rules_Plat1_Ent;
new g_Mat2_Rules_Plat2_Ent;
new g_Mat2_Character_Type_Button_Model;
new g_Mat2_Character_Type_Button_Func;
new g_Mat2_Character_Type_Button_Text;

new g_Mat2_Plat1_Model;
new g_Mat2_Plat2_Model;

new g_Mat2_Hologram_Pure;
new g_Mat2_Hologram_Phalanx;
new g_Mat2_Hologram_Judgement;
new g_Mat2_Hologram_Ryoku;

new g_Mat2_Bushido_Symbol;
new g_Mat2_Bushido_Text;

new g_Mat2_Character_Type = DEFAULT_CHAR_TYPE_MAT2;
new bool:g_Bushido_Mat2 = false;

new g_OldTickCount_Mat2 = 0;
new g_NewTickCount_Mat2;

//==================Both Mats=====================//
new String:g_szFile[PLATFORM_MAX_PATH];

//==============================================//
//												//
//			Main Body Of Plugin					//
//												//
//==============================================//
public OnMapStart()
{
	//find and hook each kendo trigger
	for( new i = 0; i <= GetMaxEntities(); i++ )
	{
		//if the entity is invalid, skip to next iteration
		if( !IsValidEntity(i) )
		{
			continue;
		}
		
		if( Entity_ClassNameMatches(i, "trigger_multiple") )
		{
			if( Entity_NameMatches(i, "kendo_mat_1") )
			{
				HookSingleEntityOutput(i, "OnTrigger", TriggerCallback_Kendo_Mat1_Trigger, false); // Hook OnTrigger output
				SetEntPropFloat(i, Prop_Data, "m_flWait", 0.01);
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2") )
			{
				HookSingleEntityOutput(i, "OnTrigger", TriggerCallback_Kendo_Mat2_Trigger, false); // Hook OnTrigger output
				SetEntPropFloat(i, Prop_Data, "m_flWait", 0.01);
			}
			
			if( Entity_NameMatches(i, "kendo_mat_1_out") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat1_Out_Trigger, false); // Hook start touch output
				HookSingleEntityOutput(i, "OnTrigger", TriggerCallback_Kendo_Mat1_Out_Trigger, false); // Hook OnTrigger output
				SetEntPropFloat(i, Prop_Data, "m_flWait", 0.01);
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_out") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat2_Out_Trigger, false); // Hook start touch output
				HookSingleEntityOutput(i, "OnTrigger", TriggerCallback_Kendo_Mat2_Out_Trigger, false); // Hook OnTrigger output
				SetEntPropFloat(i, Prop_Data, "m_flWait", 0.01);
			}
			
			if( Entity_NameMatches(i, "kendo_mat_1_plat1") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat_Plat1_Trigger, false); // Hook start touch output
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_plat1") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat2_Plat1_Trigger, false); // Hook start touch output
			}
			
			if( Entity_NameMatches(i, "kendo_mat_1_plat2") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat_Plat2_Trigger, false); // Hook start touch output
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_plat2") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", TriggerCallback_Kendo_Mat2_Plat2_Trigger, false); // Hook start touch output
			}
			
			if( Entity_NameMatches(i, "kendo_mat_1_class_button") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", CharacterButtonCallback_Kendo_Mat_1, false); // Hook start touch output
				g_Mat1_Character_Type_Button_Func = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_class_button") )
			{
				HookSingleEntityOutput(i, "OnStartTouch", CharacterButtonCallback_Kendo_Mat_2, false); // Hook start touch output
				g_Mat2_Character_Type_Button_Func = i;
			}
		}
		if( Entity_ClassNameMatches(i, "func_rotating") )
		{
			if( Entity_NameMatches(i, "kendo_mat_1_round_start") )
			{
				g_Mat1_RoundStart_Sound_Ent = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_round_start") )
			{
				g_Mat2_RoundStart_Sound_Ent = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_1_round_end") )
			{
				g_Mat1_RoundEnd_Sound_Ent = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_round_end") )
			{
				g_Mat2_RoundEnd_Sound_Ent = i;
			}
		}
		if( Entity_ClassNameMatches(i, "func_brush") )
		{
			if( Entity_NameMatches(i, "kendo_rules_mat_1_plat_1") )
			{
				g_Mat1_Rules_Plat1_Ent = i;
			}
			if( Entity_NameMatches(i, "kendo_rules_mat_1_plat_2") )
			{
				g_Mat1_Rules_Plat2_Ent = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_pure") )
			{
				g_Mat1_Hologram_Pure = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_judge") )
			{
				g_Mat1_Hologram_Judgement = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_ryoku") )
			{
				g_Mat1_Hologram_Ryoku = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_phalanx") )
			{
				g_Mat1_Hologram_Phalanx = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_bushido") )
			{
				g_Mat1_Bushido_Symbol = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_class_button_text") )
			{
				g_Mat1_Character_Type_Button_Text = i;
			}
			
			
			if( Entity_NameMatches(i, "kendo_rules_mat_2_plat_1") )
			{
				g_Mat2_Rules_Plat1_Ent = i;
			}
			if( Entity_NameMatches(i, "kendo_rules_mat_2_plat_2") )
			{
				g_Mat2_Rules_Plat2_Ent = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_pure") )
			{
				g_Mat2_Hologram_Pure = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_judge") )
			{
				g_Mat2_Hologram_Judgement = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_ryoku") )
			{
				g_Mat2_Hologram_Ryoku = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_phalanx") )
			{
				g_Mat2_Hologram_Phalanx = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_bushido") )
			{
				g_Mat2_Bushido_Symbol = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_class_button_text") )
			{
				g_Mat2_Character_Type_Button_Text = i;
			}
		}
		if( Entity_ClassNameMatches(i, "prop_dynamic") )
		{
			if( Entity_NameMatches(i, "kendo_mat_1_class_button_model") )
			{
				g_Mat1_Character_Type_Button_Model = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_plat1_model") )
			{
				g_Mat1_Plat1_Model = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_1_plat2_model") )
			{
				g_Mat1_Plat2_Model = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_class_button_model") )
			{
				g_Mat2_Character_Type_Button_Model = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_plat1_model") )
			{
				g_Mat2_Plat1_Model = i;
			}
			if( Entity_NameMatches(i, "kendo_mat_2_plat2_model") )
			{
				g_Mat2_Plat2_Model = i;
			}
		}
		if( Entity_ClassNameMatches(i, "game_text") )
		{
			if( Entity_NameMatches(i, "kendo_mat_1_bushido_text") )
			{
				g_Mat1_Bushido_Text = i;
			}
			
			if( Entity_NameMatches(i, "kendo_mat_2_bushido_text") )
			{
				g_Mat2_Bushido_Text = i;
			}
		}		
	}
	HookEvent("player_death", Event_PlayerDeath); //hook death event to end the game
	HookEvent("berimbau_blocked", Event_Blocked, EventHookMode_Pre); //hook the player blocked event to filter blocks out of the player damage event	
	HookEvent("berimbau_intercepted", Event_Intercept, EventHookMode_Pre); //hook the player intercepted event to filter from damage hook
	
	LoadSettingsConfig();
}

public OnClientPutInServer(client)
{
	//hook each client's damage event
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}	  

public OnClientDisconnect(client)
{
	//if a participant of mat1 leaves, end the game.
	if( IsClientAParticipant_Mat1(client) )
	{
		EndKendoMat1GamePrematurely();
	}
	
	if( IsClientAParticipant_Mat2(client) )
	{
		EndKendoMat2GamePrematurely();
	}
}	

public OnMapEnd()
{
	ClearMat1ClientVars();
	g_OldTickCount = 0;
	g_NewTickCount = 0;
	g_Mat1_Character_Type = DEFAULT_CHAR_TYPE_MAT1;
	g_Bushido_Mat1 = false;
	
	ClearMat2ClientVars();
	g_OldTickCount_Mat2 = 0;
	g_NewTickCount_Mat2 = 0;
	g_Mat2_Character_Type = DEFAULT_CHAR_TYPE_MAT2;
	g_Bushido_Mat2 = false;
}

//==============================================//
//												//
//				Event Hooks						//
//												//
//==============================================//
public Event_Blocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "defenderid"));
		
	if( IsClientAParticipant_Mat1(victim) )
	{
		g_Mat1_Client_Blocked[victim] = true;
	}
	
	if( IsClientAParticipant_Mat2(victim) )
	{
		g_Mat2_Client_Blocked[victim] = true;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if( IsClientAParticipant_Mat1(client) || IsClientAParticipant_Mat2(client) )
	{
		if( buttons & IN_ATTACK )		
		{
			if( buttons & IN_GRENADE1 )
			{
				buttons = 0;
			}
		}
		if( (buttons == IN_ALT1) || (buttons == IN_RUN) || (buttons == IN_RELOAD) )
		{
		
		}
		else
		{
			decl Float:test_freeze;
			test_freeze = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
			if(test_freeze == 0.0)
			{
				buttons = 0;
			}
		}
	}
	return Plugin_Continue;
}

public Event_Intercept(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "defenderid"));
	
	if( IsClientAParticipant_Mat1(victim) )
	{
		g_Mat1_Client_Intercepted[victim] = true;
	}
	
	if( IsClientAParticipant_Mat2(victim) )
	{
		g_Mat2_Client_Intercepted[victim] = true;
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//get attacker
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if( IsClientAParticipant_Mat1(victim) )
	{
		if( victim == attacker )
		{
			decl String:suicide_message[50 + MAX_NAME_LENGTH];
			Format(suicide_message, sizeof(suicide_message), "[Kendo]: %N committed suicide.", attacker);
			MessageMat1Participants(suicide_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has committed suicide on mat 1.", attacker);
		}
		else if( IsClientAParticipant_Mat1(attacker) )
		{
			decl String:win_message[50 + MAX_NAME_LENGTH];
			Format(win_message, sizeof(win_message), "[Kendo]: the match has ended! %N is the winner", attacker);
			MessageMat1Participants(win_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has defeated %N on mat 1.", attacker, victim);
		}
		else
		{
			decl String:disrupt_message[50 + MAX_NAME_LENGTH];
			Format(disrupt_message, sizeof(disrupt_message), "[Kendo]: the match has ended: %N disrupted the event.", attacker);
			MessageMat1Participants(disrupt_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has disrupted the match on mat 1.", attacker);
		}
		
		//fix freeze and teleport to exit
		SetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue", 1.0);
		SetEntityHealth(attacker, 100);
		TeleportMat1ParticipantsToExit();
		
		//re-enable character button
		EnableButtonAndHologramMat1();
		
		ClearMat1ClientVars();
	}
	
	if( IsClientAParticipant_Mat2(victim) )
	{
		if( victim == attacker )
		{
			decl String:suicide_message[50 + MAX_NAME_LENGTH];
			Format(suicide_message, sizeof(suicide_message), "[Kendo]: %N committed suicide.", attacker);
			MessageMat2Participants(suicide_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has committed suicide on mat 2.", attacker);
		}
		else if( IsClientAParticipant_Mat2(attacker) )
		{
			decl String:win_message[50 + MAX_NAME_LENGTH];
			Format(win_message, sizeof(win_message), "[Kendo]: the match has ended! %N is the winner", attacker);
			MessageMat2Participants(win_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has defeated %N on mat 2.", attacker, victim);
		}
		else
		{
			decl String:disrupt_message[50 + MAX_NAME_LENGTH];
			Format(disrupt_message, sizeof(disrupt_message), "[Kendo]: the match has ended: %N disrupted the event.", attacker);
			MessageMat2Participants(disrupt_message);
			PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N has disrupted the match on mat 2.", attacker);
		}
		
		//fix freeze and teleport to exit
		SetEntPropFloat(attacker, Prop_Send, "m_flLaggedMovementValue", 1.0);
		SetEntityHealth(attacker, 100);
		TeleportMat2ParticipantsToExit();
		
		//re-enable character button
		EnableButtonAndHologramMat2();
		
		ClearMat2ClientVars();
	}
}

//==============================================//
//												//
//				Trigger Hooks					//
//												//
//==============================================//
public CharacterButtonCallback_Kendo_Mat_1(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if( IsGameInProgress_KendoMat1() )
		{
			if( !IsClientAParticipant_Mat1(activator) )
			{
			
			}
		}
		else
		{
			DisplayCharacterMenu(activator, 1);
		}
	}
}

public CharacterButtonCallback_Kendo_Mat_2(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if( IsGameInProgress_KendoMat2() )
		{
			if( !IsClientAParticipant_Mat2(activator) )
			{
			
			}
		}
		else
		{
			DisplayCharacterMenu_Mat2(activator, 1);
		}
	}
}

public TriggerCallback_Kendo_Mat1_Trigger(const String:output[], caller, activator, Float:delay)
{
	//a bunch of checks to ensure that the game has started, and the activator is a valid participant
	if( IsGameInProgress_KendoMat1() )
	{
		if( IsClientAParticipant_Mat1(activator) )
		{
			if(IsPlayerAlive(activator))
			{
				if( StrEqual(output, "OnTrigger") )
				{
					if( IsInDuel(activator) )
					{
						EndKendoMat1GamePrematurely();
					}
					else if( !IsInDuel(activator) )
					{
						new char_type = GetEntProp(activator, Prop_Send, "m_CharacterIndex");
						if( char_type != g_Mat1_Character_Type )
						{
							//ForceCharacter(activator, g_Mat1_Character_Type);
							EndKendoMat1GamePrematurely_CharacterChangeViolation(activator);
						}
					}
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat2_Trigger(const String:output[], caller, activator, Float:delay)
{
	//a bunch of checks to ensure that the game has started, and the activator is a valid participant
	if( IsGameInProgress_KendoMat2() )
	{
		if( IsClientAParticipant_Mat2(activator) )
		{
			if(IsPlayerAlive(activator))
			{
				if( StrEqual(output, "OnTrigger") )
				{
					if( IsInDuel(activator) )
					{
						EndKendoMat2GamePrematurely();
					}
					else if( !IsInDuel(activator) )
					{
						new char_type = GetEntProp(activator, Prop_Send, "m_CharacterIndex");
						if( char_type != g_Mat2_Character_Type )
						{
							//ForceCharacter(activator, g_Mat1_Character_Type);
							EndKendoMat2GamePrematurely_CharacterChangeViolation(activator);
						}
					}
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat1_Out_Trigger(const String:output[], caller, activator, Float:delay)
{
	//a bunch of checks to ensure that the game has started, and the activator is a valid participant
	if( IsGameInProgress_KendoMat1() )
	{
		if( IsClientAParticipant_Mat1(activator) )
		{
			if(IsPlayerAlive(activator))
			{
				if( StrEqual(output, "OnStartTouch") )
				{
					if(!IsInDuel(activator))
					{
						decl cl_arr[2];
						GetMat1Participants(cl_arr);
						
						if( GetClientHealth(activator) <= 0 )
						{
							//do nothing, client is dead
						}
						else if( (GetClientHealth(cl_arr[0]) <= 0) || (GetClientHealth(cl_arr[1]) <= 0) )
						{
							//do nothing 1 of the players is dead
						}
						else
						{
							new hp = GetClientHealth(activator);
							new new_hp = (hp - OUTOFBOUNDSDMG);
							if( new_hp <= 0 )
							{
								//kill player
								if( cl_arr[0] == activator )
								{
									SDKHooks_TakeDamage(activator, cl_arr[1], cl_arr[1], OUTOFBOUNDSDMG_Float);
								}
								else
								{
									SDKHooks_TakeDamage(activator, cl_arr[0], cl_arr[0], OUTOFBOUNDSDMG_Float);
								}
								
							}
							else
							{
								SetEntityHealth(activator, new_hp);
								decl String:out_of_bounds_message[50 + MAX_NAME_LENGTH];
								Format(out_of_bounds_message, sizeof(out_of_bounds_message), "[Kendo]: %N stepped out of bounds.", activator);
								MessageMat1Participants(out_of_bounds_message);
						
								Freeze_DelayTeleportToStart_Mat1();
						
								AcceptEntityInput(g_Mat1_RoundEnd_Sound_Ent, "Start");
								CreateTimer(3.0, Timer_StopRoundEndSound, _, TIMER_FLAG_NO_MAPCHANGE);
							}
						}
					}
				}
				if ( StrEqual(output, "OnTrigger") )
				{
					if( IsInDuel(activator) )
					{
						EndKendoMat1GamePrematurely();
					}	
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat2_Out_Trigger(const String:output[], caller, activator, Float:delay)
{
	//a bunch of checks to ensure that the game has started, and the activator is a valid participant
	if( IsGameInProgress_KendoMat2() )
	{
		if( IsClientAParticipant_Mat2(activator) )
		{
			if(IsPlayerAlive(activator))
			{
				if( StrEqual(output, "OnStartTouch") )
				{
					if(!IsInDuel(activator))
					{
						decl cl_arr[2];
						GetMat2Participants(cl_arr);
						
						if( GetClientHealth(activator) <= 0 )
						{
							//do nothing, client is dead
						}
						else if( (GetClientHealth(cl_arr[0]) <= 0) || (GetClientHealth(cl_arr[1]) <= 0) )
						{
							//do nothing 1 of the players is dead
						}
						else
						{
							new hp = GetClientHealth(activator);
							new new_hp = (hp - OUTOFBOUNDSDMG);
							if( new_hp <= 0 )
							{
								//kill player
								if( cl_arr[0] == activator )
								{
									SDKHooks_TakeDamage(activator, cl_arr[1], cl_arr[1], OUTOFBOUNDSDMG_Float);
								}
								else
								{
									SDKHooks_TakeDamage(activator, cl_arr[0], cl_arr[0], OUTOFBOUNDSDMG_Float);
								}
								
							}
							else
							{
								SetEntityHealth(activator, new_hp);
								decl String:out_of_bounds_message[50 + MAX_NAME_LENGTH];
								Format(out_of_bounds_message, sizeof(out_of_bounds_message), "[Kendo]: %N stepped out of bounds.", activator);
								MessageMat2Participants(out_of_bounds_message);
						
								Freeze_DelayTeleportToStart_Mat2();
						
								AcceptEntityInput(g_Mat2_RoundEnd_Sound_Ent, "Start");
								CreateTimer(3.0, Timer_StopRoundEndSound_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
							}
						}
					}
				}
				if ( StrEqual(output, "OnTrigger") )
				{
					if( IsInDuel(activator) )
					{
						EndKendoMat2GamePrematurely();
					}	
				}
			}
		}
	}
}

public Action:Timer_StopRoundEndSound(Handle:timer)
{
	AcceptEntityInput(g_Mat1_RoundEnd_Sound_Ent, "Stop");
}

public Action:Timer_StopRoundEndSound_Mat2(Handle:timer)
{
	AcceptEntityInput(g_Mat2_RoundEnd_Sound_Ent, "Stop");
}

public TriggerCallback_Kendo_Mat_Plat1_Trigger(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if(IsPlayerAlive(activator))
		{
			if(!IsInDuel(activator))
			{
				if( CountKendoMat1_Plat1_Participants() == 0 )
				{
					//no plat 1 participants yet, ask to participate via menu
					if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else
					{
						DisplayAskToParticipateMenu(activator, 1);
					}
				}
				else
				{
					if( g_KendoMat1_Participants[activator] == 1 )
					{
						if( g_Mat1_Plat1_Client_Confirmation )
						{
							DisplayAskToParticipateMenu(activator, 3);
						}
						else
						{
							DisplayAskToParticipateMenu(activator, 5);//this one
						}
					}
					else if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01Another player is currently registered on this platform.");
					}
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat2_Plat1_Trigger(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if(IsPlayerAlive(activator))
		{
			if(!IsInDuel(activator))
			{
				if( CountKendoMat2_Plat1_Participants() == 0 )
				{
					//no plat 1 participants yet, ask to participate via menu
					if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else
					{
						DisplayAskToParticipateMenu_Mat2(activator, 1);
					}
				}
				else
				{
					if( g_KendoMat2_Participants[activator] == 1 )
					{
						if( g_Mat2_Plat1_Client_Confirmation )
						{
							DisplayAskToParticipateMenu_Mat2(activator, 3);
						}
						else
						{
							DisplayAskToParticipateMenu_Mat2(activator, 5);//this one
						}
					}
					else if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01Another player is currently registered on this platform.");
					}
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat_Plat2_Trigger(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if(IsPlayerAlive(activator))
		{
			if(!IsInDuel(activator))
			{
				if( CountKendoMat1_Plat2_Participants() == 0 )
				{
					//no plat 2 participants yet, ask to participate via menu
					if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else
					{
						DisplayAskToParticipateMenu(activator, 2);
					}
				}
				else
				{
					if( g_KendoMat1_Participants[activator] == 2 )
					{
						if( g_Mat1_Plat2_Client_Confirmation )
						{
							DisplayAskToParticipateMenu(activator, 4);
						}
						else
						{
							DisplayAskToParticipateMenu(activator, 6);
						}
					}
					else if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else if( g_KendoMat2_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 2!");
					}
					else if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01Another player is currently registered on this platform.");
					}
				}
			}
		}
	}
}

public TriggerCallback_Kendo_Mat2_Plat2_Trigger(const String:output[], caller, activator, Float:delay)
{
	if( IsValidClient(activator) )
	{
		if(IsPlayerAlive(activator))
		{
			if(!IsInDuel(activator))
			{
				if( CountKendoMat2_Plat2_Participants() == 0 )
				{
					//no plat 2 participants yet, ask to participate via menu
					if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else
					{
						DisplayAskToParticipateMenu_Mat2(activator, 2);
					}
				}
				else
				{
					if( g_KendoMat2_Participants[activator] == 2 )
					{
						if( g_Mat2_Plat2_Client_Confirmation )
						{
							DisplayAskToParticipateMenu_Mat2(activator, 4);
						}
						else
						{
							DisplayAskToParticipateMenu_Mat2(activator, 6);
						}
					}
					else if( g_KendoMat2_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 2, platform 1!");
					}
					else if( g_KendoMat1_Participants[activator] == 2 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 2!");
					}
					else if( g_KendoMat1_Participants[activator] == 1 )
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01You've already registered on mat 1, platform 1!");
					}
					else
					{
						PrintToChat(activator, "\x04[\x03Kendo\x04]\x03: \x01Another player is currently registered on this platform.");
					}
				}
			}
		}
	}
}


//==============================================//
//												//
//				Client Hooks					//
//												//
//==============================================//
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{	
	//if the attacker is not a client, don't do anything.
	if( (1 > attacker)||(attacker > MaxClients) )
	{
		return Plugin_Continue;
	}
	
	if( attacker == 0 )
	{
		return Plugin_Continue;
	}
	
//	PrintToConsole(victim, "is valid client check")
	
	if( IsClientAParticipant_Mat1(victim) && IsClientAParticipant_Mat1(attacker) )
	{
		//hacks
		g_NewTickCount = GetGameTickCount();
		if( (g_NewTickCount - g_OldTickCount) <= 1 )
		{
			g_OldTickCount = g_NewTickCount;
//			PrintToConsole(victim, "game tick check")
			return Plugin_Continue;
		}
		g_OldTickCount = g_NewTickCount;
		
		//the attacker is a client, get multihit count and only register per string landed, rather than per hit landed.
		new multihits = GetEntProp(attacker, Prop_Send, "m_iMultiHitCount");
		if( multihits != 0 )
		{
//			PrintToConsole(victim, "multi hit check")
			return Plugin_Continue;
		}
		
		if( g_Mat1_Client_Blocked[victim] )
		{
//			PrintToConsole(victim, "attack blocked check")
			g_Mat1_Client_Blocked[victim] = false;
			return Plugin_Continue;
		}
		else if( g_Mat1_Client_Intercepted[victim] )
		{
			g_Mat1_Client_Intercepted[victim] = false;
			return Plugin_Continue;
		}
		else
		{
//			PrintToConsole(victim, "register as kendo hit")
			//message
			decl String:hit_message[50 + MAX_NAME_LENGTH];
			Format(hit_message, sizeof(hit_message), "[Kendo]: %N landed a hit on %N", attacker, victim);
			MessageMat1Participants(hit_message);
			//teleport
			new hp = GetClientHealth(victim);
			if((hp - RoundToNearest(damage)) <= 0)
			{
				//victim died, don't teleport
			}
			else
			{
				Freeze_DelayTeleportToStart_Mat1();
			}
			
			AcceptEntityInput(g_Mat1_RoundEnd_Sound_Ent, "Start");
			CreateTimer(3.0, Timer_StopRoundEndSound, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	if( IsClientAParticipant_Mat2(victim) && IsClientAParticipant_Mat2(attacker) )
	{
		//hacks
		g_NewTickCount_Mat2 = GetGameTickCount();
		if( (g_NewTickCount_Mat2 - g_OldTickCount_Mat2) <= 1 )
		{
			g_OldTickCount_Mat2 = g_NewTickCount_Mat2;
//			PrintToConsole(victim, "game tick check")
			return Plugin_Continue;
		}
		g_OldTickCount_Mat2 = g_NewTickCount_Mat2;
		
		//the attacker is a client, get multihit count and only register per string landed, rather than per hit landed.
		new multihits = GetEntProp(attacker, Prop_Send, "m_iMultiHitCount");
		if( multihits != 0 )
		{
//			PrintToConsole(victim, "multi hit check")
			return Plugin_Continue;
		}
		
		if( g_Mat2_Client_Blocked[victim] )
		{
//			PrintToConsole(victim, "attack blocked check")
			g_Mat2_Client_Blocked[victim] = false;
			return Plugin_Continue;
		}
		else if( g_Mat2_Client_Intercepted[victim] )
		{
			g_Mat2_Client_Intercepted[victim] = false;
			return Plugin_Continue;
		}
		else
		{
//			PrintToConsole(victim, "register as kendo hit")
			//message
			decl String:hit_message[50 + MAX_NAME_LENGTH];
			Format(hit_message, sizeof(hit_message), "[Kendo]: %N landed a hit on %N", attacker, victim);
			MessageMat2Participants(hit_message);
			//teleport
			new hp = GetClientHealth(victim);
			if((hp - RoundToNearest(damage)) <= 0)
			{
				//victim died, don't teleport
			}
			else
			{
				Freeze_DelayTeleportToStart_Mat2();
			}
			
			AcceptEntityInput(g_Mat2_RoundEnd_Sound_Ent, "Start");
			CreateTimer(3.0, Timer_StopRoundEndSound_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	return Plugin_Continue;
}
//==============================================//
//								  				//
//				Accept Settings Menu			//
//												//
//==============================================//
DisplayAcceptSettingsMenu(client, platform)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AcceptSettingsMenuHandler, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Do you agree to the current settings?");
	
	//add menu items (w/unique Ids)
	if( platform == 1 )
	{
		AddMenuItem(menu, "1", "Yes");
		AddMenuItem(menu, "2", "No");
	}
	else if( platform == 2 )
	{
		AddMenuItem(menu, "3", "Yes");
		AddMenuItem(menu, "4", "No");
	}
	
	//remove exit button
	SetMenuExitButton(menu, false);

	//display to client
	DisplayMenu(menu, client, 10);
}

public AcceptSettingsMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		SetEntityHealth(param1, 100);
		
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//yes plat 1
				if( IsInDuel(param1) )
				{
					ConfirmationFailed_Mat1();
				}
				else
				{
					g_Mat1_Plat1_Client_Confirmation = true;
				
					//if the other participant hasn't voted yet, wait for confirmation
					if(!g_Mat1_Plat2_Client_Confirmation)
					{
						WaitForConfirmation_Mat1();
					}
					else
					{
						//start game
						if( IsGameInProgress_KendoMat1() )
						{
							StartKendoMat1Game();
						}
					}
				}
			}
			case 2:
			{
				//no plat 1
				//message the participants that someone didn't agree to the terms
				//and reset vars
				ConfirmationFailed_Mat1();
			}
			case 3:
			{
				//yes plat 2
				g_Mat1_Plat2_Client_Confirmation = true;
				
				//if the other participant hasn't voted yet, wait for confirmation
				if(!g_Mat1_Plat1_Client_Confirmation)
				{
					WaitForConfirmation_Mat1();
				}
				else
				{
					//start game
					if( IsGameInProgress_KendoMat1() )
					{
						StartKendoMat1Game();
					}
				}
			}
			case 4:
			{
				//no plat 2
				//message the participants that someone didn't agree to the terms
				//and reset vars
				ConfirmationFailed_Mat1();
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock ConfirmationFailed_Mat1()
{
	decl String:confirm_fail_message[50 + MAX_NAME_LENGTH];
	Format(confirm_fail_message, sizeof(confirm_fail_message), "[Kendo]: A participant has declined to play with the current settings.");
	MessageMat1Participants(confirm_fail_message);
	ClearMat1ClientVars();
}

stock WaitForConfirmation_Mat1()
{
	decl String:wait_for_confirmation[50 + MAX_NAME_LENGTH];
	Format(wait_for_confirmation, sizeof(wait_for_confirmation), "[Kendo]: Waiting for settings confirmation. Unregistration will occur in 10 sec.");
	MessageMat1Participants(wait_for_confirmation);
	CreateTimer(10.0, Timer_WaitingForConfirmation, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_WaitingForConfirmation(Handle:timer)
{
	if( !g_Mat1_Plat1_Client_Confirmation || !g_Mat1_Plat2_Client_Confirmation )
	{
		decl String:confirm_time_fail_message[50 + MAX_NAME_LENGTH];
		Format(confirm_time_fail_message, sizeof(confirm_time_fail_message), "[Kendo]: Confirmation time limit reached; players have been unregistered.");
		MessageMat1Participants(confirm_time_fail_message);
		ClearMat1ClientVars();
	}
}


//============================================================MAT2=============================================================//
DisplayAcceptSettingsMenu_Mat2(client, platform)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AcceptSettingsMenuHandler_Mat2, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Do you agree to the current settings?");
	
	//add menu items (w/unique Ids)
	if( platform == 1 )
	{
		AddMenuItem(menu, "1", "Yes");
		AddMenuItem(menu, "2", "No");
	}
	else if( platform == 2 )
	{
		AddMenuItem(menu, "3", "Yes");
		AddMenuItem(menu, "4", "No");
	}
	
	//remove exit button
	SetMenuExitButton(menu, false);

	//display to client
	DisplayMenu(menu, client, 10);
}

public AcceptSettingsMenuHandler_Mat2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		SetEntityHealth(param1, 100);
		
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//yes plat 1
				if( IsInDuel(param1) )
				{
					ConfirmationFailed_Mat1();
				}
				else
				{
					g_Mat2_Plat1_Client_Confirmation = true;
				
					//if the other participant hasn't voted yet, wait for confirmation
					if(!g_Mat2_Plat2_Client_Confirmation)
					{
						WaitForConfirmation_Mat2();
					}
					else
					{
						//start game
						if( IsGameInProgress_KendoMat2() )
						{
							StartKendoMat2Game();
						}
					}
				}
			}
			case 2:
			{
				//no plat 1
				//message the participants that someone didn't agree to the terms
				//and reset vars
				ConfirmationFailed_Mat2();
			}
			case 3:
			{
				//yes plat 2
				g_Mat2_Plat2_Client_Confirmation = true;
				
				//if the other participant hasn't voted yet, wait for confirmation
				if(!g_Mat2_Plat1_Client_Confirmation)
				{
					WaitForConfirmation_Mat2();
				}
				else
				{
					//start game
					if( IsGameInProgress_KendoMat2() )
					{
						StartKendoMat2Game();
					}
				}
			}
			case 4:
			{
				//no plat 2
				//message the participants that someone didn't agree to the terms
				//and reset vars
				ConfirmationFailed_Mat2();
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock ConfirmationFailed_Mat2()
{
	decl String:confirm_fail_message[50 + MAX_NAME_LENGTH];
	Format(confirm_fail_message, sizeof(confirm_fail_message), "[Kendo]: A participant has declined to play with the current settings.");
	MessageMat2Participants(confirm_fail_message);
	ClearMat2ClientVars();
}

stock WaitForConfirmation_Mat2()
{
	decl String:wait_for_confirmation[50 + MAX_NAME_LENGTH];
	Format(wait_for_confirmation, sizeof(wait_for_confirmation), "[Kendo]: Waiting for settings confirmation. Unregistration will occur in 10 sec.");
	MessageMat2Participants(wait_for_confirmation);
	CreateTimer(10.0, Timer_WaitingForConfirmation_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_WaitingForConfirmation_Mat2(Handle:timer)
{
	if( !g_Mat2_Plat1_Client_Confirmation || !g_Mat2_Plat2_Client_Confirmation )
	{
		decl String:confirm_time_fail_message[50 + MAX_NAME_LENGTH];
		Format(confirm_time_fail_message, sizeof(confirm_time_fail_message), "[Kendo]: Confirmation time limit reached; players have been unregistered.");
		MessageMat2Participants(confirm_time_fail_message);
		ClearMat2ClientVars();
	}
}


//==============================================//
//												//
//				Mat Character Menu				//
//												//
//==============================================//
DisplayCharacterMenu(client, mat)
{
	//create the menu handle
	new Handle:menu = CreateMenu(CharacterMenuHandler, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Select a character:");
	
	//add menu items (w/unique Ids)
	if( mat == 1 )
	{
		AddMenuItem(menu, "1", "Judgement");
		AddMenuItem(menu, "2", "Phalanx");
		AddMenuItem(menu, "3", "Ryoku");
		AddMenuItem(menu, "4", "Pure");
	}
	else if( mat == 2 )
	{
		AddMenuItem(menu, "5", "Judgement");
		AddMenuItem(menu, "6", "Phalanx");
		AddMenuItem(menu, "7", "Ryoku");
		AddMenuItem(menu, "8", "Pure");
	}
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public CharacterMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		if( IsGameInProgress_KendoMat1() )
		{
			if( !IsClientAParticipant_Mat1(param1) )
			{
				PrintToChat(param1,"\x04[\x03Kendo\x04]\x03: \x01Settings could not be applied; a game is in progress.");
			}
		}
		else
		{
			switch(id)
			{
				case 1:
				{
					//mat 1 Judgement
					//change hologram, set in global value
					g_Mat1_Character_Type = 1;
					Mat1_ChangeHologramTo("judgement");
				
					//display bushido menu
					DisplayBushidoMenu(param1, 1);
				}
				case 2:
				{
					//mat 1 Phalanx
					g_Mat1_Character_Type = 0;
					Mat1_ChangeHologramTo("phalanx");
				
					//display bushido menu
					DisplayBushidoMenu(param1, 1);
				}
				case 3:
				{
					//mat 1 Ryoku
					g_Mat1_Character_Type = 2;
					Mat1_ChangeHologramTo("ryoku");
				
					//display bushido menu
					DisplayBushidoMenu(param1, 1);
				}
				case 4:
				{
					//mat 1 Pure
					g_Mat1_Character_Type = 3;
					Mat1_ChangeHologramTo("pure");
				
					//display bushido menu
					DisplayBushidoMenu(param1, 1);
				}
				case 5:
				{
					//mat 2 Judgement
				}
				case 6:
				{
					//mat 2 Phalanx
				}
				case 7:
				{
					//mat 2 Ryoku
				}
				case 8:
				{
					//mat 2 Pure
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//======================================================MAT2==========================================================================//
DisplayCharacterMenu_Mat2(client, mat)
{
	//create the menu handle
	new Handle:menu = CreateMenu(CharacterMenuHandler_Mat2, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Select a character:");
	
	//add menu items (w/unique Ids)
	if( mat == 1 )
	{
		AddMenuItem(menu, "1", "Judgement");
		AddMenuItem(menu, "2", "Phalanx");
		AddMenuItem(menu, "3", "Ryoku");
		AddMenuItem(menu, "4", "Pure");
	}
	else if( mat == 2 )
	{
		AddMenuItem(menu, "5", "Judgement");
		AddMenuItem(menu, "6", "Phalanx");
		AddMenuItem(menu, "7", "Ryoku");
		AddMenuItem(menu, "8", "Pure");
	}
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public CharacterMenuHandler_Mat2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		if( IsGameInProgress_KendoMat2() )
		{
			if( !IsClientAParticipant_Mat2(param1) )
			{
				PrintToChat(param1,"\x04[\x03Kendo\x04]\x03: \x01Settings could not be applied; a game is in progress.");
			}
		}
		else
		{
			switch(id)
			{
				case 1:
				{
					//mat 1 Judgement
					//change hologram, set in global value
					g_Mat2_Character_Type = 1;
					Mat2_ChangeHologramTo("judgement");
				
					//display bushido menu
					DisplayBushidoMenu_Mat2(param1, 1);
				}
				case 2:
				{
					//mat 1 Phalanx
					g_Mat2_Character_Type = 0;
					Mat2_ChangeHologramTo("phalanx");
				
					//display bushido menu
					DisplayBushidoMenu_Mat2(param1, 1);
				}
				case 3:
				{
					//mat 1 Ryoku
					g_Mat2_Character_Type = 2;
					Mat2_ChangeHologramTo("ryoku");
				
					//display bushido menu
					DisplayBushidoMenu_Mat2(param1, 1);
				}
				case 4:
				{
					//mat 1 Pure
					g_Mat2_Character_Type = 3;
					Mat2_ChangeHologramTo("pure");
				
					//display bushido menu
					DisplayBushidoMenu_Mat2(param1, 1);
				}
				case 5:
				{
					//mat 2 Judgement
				}
				case 6:
				{
					//mat 2 Phalanx
				}
				case 7:
				{
					//mat 2 Ryoku
				}
				case 8:
				{
					//mat 2 Pure
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//==============================================//
//												//
//				Mat Bushido Menu				//
//												//
//==============================================//
DisplayBushidoMenu(client, mat)
{
	//create the menu handle
	new Handle:menu = CreateMenu(BushidoMenuHandler, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Enable Bushido mode?");
	
	//add menu items (w/unique Ids)
	if( mat == 1 )
	{
		AddMenuItem(menu, "2", "No");
		AddMenuItem(menu, "1", "Yes");
	}
	else if( mat == 2 )
	{
		AddMenuItem(menu, "4", "No");
		AddMenuItem(menu, "3", "Yes");
	}
	AddMenuItem(menu, "5", "What is Bushido mode?")
	
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public BushidoMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//mat 1 yes
				//show the symbol, set the global var
				AcceptEntityInput(g_Mat1_Bushido_Symbol, "Enable");
				g_Bushido_Mat1 = true;
			}
			case 2:
			{
				//mat 1 no
				//hide the symbol, set the global var
				AcceptEntityInput(g_Mat1_Bushido_Symbol, "Disable");
				g_Bushido_Mat1 = false;
			}
			case 3:
			{
				//mat 2 yes
				//show the symbol, set the global var
			}
			case 4:
			{
				//mat 2 no
				//hide the symbol, set the global var
			}
			case 5:
			{
				//show bushido mode text
				AcceptEntityInput(g_Mat1_Bushido_Text, "Display", param1);
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//==========================================================MAT2======================================================//
DisplayBushidoMenu_Mat2(client, mat)
{
	//create the menu handle
	new Handle:menu = CreateMenu(BushidoMenuHandler_Mat2, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Enable Bushido mode?");
	
	//add menu items (w/unique Ids)
	if( mat == 1 )
	{
		AddMenuItem(menu, "2", "No");
		AddMenuItem(menu, "1", "Yes");
	}
	else if( mat == 2 )
	{
		AddMenuItem(menu, "4", "No");
		AddMenuItem(menu, "3", "Yes");
	}
	AddMenuItem(menu, "5", "What is Bushido mode?")
	
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public BushidoMenuHandler_Mat2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//mat 1 yes
				//show the symbol, set the global var
				AcceptEntityInput(g_Mat2_Bushido_Symbol, "Enable");
				g_Bushido_Mat2 = true;
			}
			case 2:
			{
				//mat 1 no
				//hide the symbol, set the global var
				AcceptEntityInput(g_Mat2_Bushido_Symbol, "Disable");
				g_Bushido_Mat2 = false;
			}
			case 3:
			{
				//mat 2 yes
				//show the symbol, set the global var
			}
			case 4:
			{
				//mat 2 no
				//hide the symbol, set the global var
			}
			case 5:
			{
				//show bushido mode text
				AcceptEntityInput(g_Mat2_Bushido_Text, "Display", param1);
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//==============================================//
//												//
//			Trigger Platform Menu				//
//												//
//==============================================//
DisplayAskToParticipateMenu(client, platform)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AskToParticipateMenuHandler, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Would you like to play kendo?");
	
	//add menu items (w/unique Ids)
	if(platform == 1)
	{
		AddMenuItem(menu, "1", "Yes (register)");
		AddMenuItem(menu, "2", "No (unregister)");
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if( platform == 2 )
	{
		AddMenuItem(menu, "3", "Yes (register)");
		AddMenuItem(menu, "4", "No (unregister)");
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	else if(platform == 3)
	{
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if(platform == 4)
	{
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	else if(platform == 5)
	{
		AddMenuItem(menu, "2", "No (unregister)");
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if(platform == 6)
	{
		AddMenuItem(menu, "4", "No (unregister)");
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	
	//SetMenuExitButton(menu, false);
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public AskToParticipateMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//plat 1 yes
				UnRegisterAllPlayers_Plat1_Mat1();
				g_KendoMat1_Participants[param1] = 1;
				Lock_Delay_Unlock_Settings_Button_Mat1();
				
				//change plat to occupied
				SetVariantString("4")
				AcceptEntityInput(g_Mat1_Plat1_Model, "Skin");
				
				if( IsGameInProgress_KendoMat1() )
				{
					//ask for confirmation
					decl cl_arr[2];
					GetMat1Participants(cl_arr);
					DisplayAcceptSettingsMenu(cl_arr[0], 1);
					DisplayAcceptSettingsMenu(cl_arr[1], 2);
				}
				else
				{
					PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N is waiting for another player on mat 1.", param1);
				}
			}
			case 2:
			{
				//plat 1 no
				g_KendoMat1_Participants[param1] = 0;
				
				//change plat to free
				SetVariantString("3")
				AcceptEntityInput(g_Mat1_Plat1_Model, "Skin");
			}
			case 3:
			{
				//plat 2 yes
				UnRegisterAllPlayers_Plat2_Mat1();
				g_KendoMat1_Participants[param1] = 2;
				Lock_Delay_Unlock_Settings_Button_Mat1();
				
				//change plat to occupied
				SetVariantString("7")
				AcceptEntityInput(g_Mat1_Plat2_Model, "Skin");
				
				if( IsGameInProgress_KendoMat1() )
				{
					//ask for confirmation
					decl cl_arr[2];
					GetMat1Participants(cl_arr);
					DisplayAcceptSettingsMenu(cl_arr[0], 1);
					DisplayAcceptSettingsMenu(cl_arr[1], 2);
				}
				else
				{
					PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N is waiting for another player on mat 1.", param1);
				}
			}
			case 4:
			{
				//plat 2 no
				g_KendoMat1_Participants[param1] = 0;
				
				//change plat to free
				SetVariantString("6")
				AcceptEntityInput(g_Mat1_Plat2_Model, "Skin");
			}
			case 5:
			{
				//view rules plat 1
				AcceptEntityInput(g_Mat1_Rules_Plat1_Ent, "Enable");
				CreateTimer(20.0, Timer_DisableRulesDisplay, g_Mat1_Rules_Plat1_Ent, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 6:
			{
				//view rules plat 2
				AcceptEntityInput(g_Mat1_Rules_Plat2_Ent, "Enable");
				CreateTimer(20.0, Timer_DisableRulesDisplay, g_Mat1_Rules_Plat2_Ent, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//=================================================================================MAT2===============================================================//
DisplayAskToParticipateMenu_Mat2(client, platform)
{
	//create the menu handle
	new Handle:menu = CreateMenu(AskToParticipateMenuHandler_Mat2, MENU_ACTIONS_ALL);
	
	//set the title
	SetMenuTitle(menu, "Would you like to play kendo?");
	
	//add menu items (w/unique Ids)
	if(platform == 1)
	{
		AddMenuItem(menu, "1", "Yes (register)");
		AddMenuItem(menu, "2", "No (unregister)");
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if( platform == 2 )
	{
		AddMenuItem(menu, "3", "Yes (register)");
		AddMenuItem(menu, "4", "No (unregister)");
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	else if(platform == 3)
	{
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if(platform == 4)
	{
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	else if(platform == 5)
	{
		AddMenuItem(menu, "2", "No (unregister)");
		AddMenuItem(menu, "5", "View Kendo rules.");
	}
	else if(platform == 6)
	{
		AddMenuItem(menu, "4", "No (unregister)");
		AddMenuItem(menu, "6", "View Kendo rules.");
	}
	
	//SetMenuExitButton(menu, false);
	
	//display to client
	DisplayMenu(menu, client, 5);
}

public AskToParticipateMenuHandler_Mat2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//declare string buffer
		decl String:sz_IdBuffer[8];
		
		//get item id
		GetMenuItem(menu, param2, sz_IdBuffer, sizeof(sz_IdBuffer));
		
		//convert to int
		new id = StringToInt(sz_IdBuffer);
		
		//switch statement to display proper menu based on id
		switch(id)
		{
			case 1:
			{
				//plat 1 yes
				UnRegisterAllPlayers_Plat1_Mat2();
				g_KendoMat2_Participants[param1] = 1;
				Lock_Delay_Unlock_Settings_Button_Mat2();
				
				//change plat to occupied
				SetVariantString("4")
				AcceptEntityInput(g_Mat2_Plat1_Model, "Skin");
				
				if( IsGameInProgress_KendoMat2() )
				{
					//ask for confirmation
					decl cl_arr[2];
					GetMat2Participants(cl_arr);
					DisplayAcceptSettingsMenu_Mat2(cl_arr[0], 1);
					DisplayAcceptSettingsMenu_Mat2(cl_arr[1], 2);
				}
				else
				{
					PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N is waiting for another player on mat 2.", param1);
				}
			}
			case 2:
			{
				//plat 1 no
				g_KendoMat2_Participants[param1] = 0;
				
				//change plat to free
				SetVariantString("3")
				AcceptEntityInput(g_Mat2_Plat1_Model, "Skin");
			}
			case 3:
			{
				//plat 2 yes
				UnRegisterAllPlayers_Plat2_Mat2();
				g_KendoMat2_Participants[param1] = 2;
				Lock_Delay_Unlock_Settings_Button_Mat2();
				
				//change plat to occupied
				SetVariantString("7")
				AcceptEntityInput(g_Mat2_Plat2_Model, "Skin");
				
				if( IsGameInProgress_KendoMat2() )
				{
					//ask for confirmation
					decl cl_arr[2];
					GetMat2Participants(cl_arr);
					DisplayAcceptSettingsMenu_Mat2(cl_arr[0], 1);
					DisplayAcceptSettingsMenu_Mat2(cl_arr[1], 2);
				}
				else
				{
					PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N is waiting for another player on mat 2.", param1);
				}
			}
			case 4:
			{
				//plat 2 no
				g_KendoMat2_Participants[param1] = 0;
				
				//change plat to free
				SetVariantString("6")
				AcceptEntityInput(g_Mat2_Plat2_Model, "Skin");
			}
			case 5:
			{
				//view rules plat 1
				AcceptEntityInput(g_Mat2_Rules_Plat1_Ent, "Enable");
				CreateTimer(20.0, Timer_DisableRulesDisplay, g_Mat2_Rules_Plat1_Ent, TIMER_FLAG_NO_MAPCHANGE);
			}
			case 6:
			{
				//view rules plat 2
				AcceptEntityInput(g_Mat2_Rules_Plat2_Ent, "Enable");
				CreateTimer(20.0, Timer_DisableRulesDisplay, g_Mat2_Rules_Plat2_Ent, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:Timer_DisableRulesDisplay(Handle:timer, any:entity)
{
	if(IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Disable");
	}
}

//==============================================//
//												//
//				Misc. Functions					//
//												//
//==============================================//
stock CountKendoMat1_Plat1_Participants()
{
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ )
	{
		//if the array index contains a 1, then that signifies a participant
		//therefore, increment the count by 1.
		if( g_KendoMat1_Participants[i] == 1 )
		{
			count++;
		}
	}
	
	return count;
}

stock CountKendoMat2_Plat1_Participants()
{
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ )
	{
		//if the array index contains a 1, then that signifies a participant
		//therefore, increment the count by 1.
		if( g_KendoMat2_Participants[i] == 1 )
		{
			count++;
		}
	}
	
	return count;
}

stock CountKendoMat1_Plat2_Participants()
{
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ )
	{
		//if the array index contains a 2, then that signifies a participant
		//therefore, increment the count by 1.
		if( g_KendoMat1_Participants[i] == 2 )
		{
			count++;
		}
	}
	
	return count;
}

stock CountKendoMat2_Plat2_Participants()
{
	new count = 0;
	for( new i = 1; i <= MaxClients; i++ )
	{
		//if the array index contains a 2, then that signifies a participant
		//therefore, increment the count by 1.
		if( g_KendoMat2_Participants[i] == 2 )
		{
			count++;
		}
	}
	
	return count;
}

stock bool:IsGameInProgress_KendoMat1()
{
	if( (CountKendoMat1_Plat1_Participants() == 1) && (CountKendoMat1_Plat2_Participants() == 1) )
	{
		return true;
	}
	
	return false;
}

stock bool:IsGameInProgress_KendoMat2()
{
	if( (CountKendoMat2_Plat1_Participants() == 1) && (CountKendoMat2_Plat2_Participants() == 1) )
	{
		return true;
	}
	
	return false;
}

stock StartKendoMat1Game()
{		
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	//message them
	MessageMat1Participants("[Kendo]: the match has begun! Attack your opponent!");
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N and %N are now playing on mat 1.", cl_arr[0], cl_arr[1]);
	
	//teleport them to start
	Freeze_DelayTeleportToStart_Mat1_INITIAL();
	
	//disable the character button
	DisableButtonAndHologramMat1();
}

stock StartKendoMat2Game()
{		
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	//message them
	MessageMat2Participants("[Kendo]: the match has begun! Attack your opponent!");
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01%N and %N are now playing on mat 2.", cl_arr[0], cl_arr[1]);
	
	//teleport them to start
	Freeze_DelayTeleportToStart_Mat2_INITIAL();
	
	//disable the character button
	DisableButtonAndHologramMat2();
}

stock EndKendoMat1GamePrematurely()
{
	//send message
	MessageMat1Participants("[Kendo]: the match has ended prematurely!");
	
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01the match on mat 1 has ended prematurely.");
	
	//teleport out of ring
	TeleportMat1ParticipantsToExit();
	
	//reset mat1
	ClearMat1ClientVars();
	
	//enable the character button
	EnableButtonAndHologramMat1();
}

stock EndKendoMat2GamePrematurely()
{
	//send message
	MessageMat1Participants("[Kendo]: the match has ended prematurely!");
	
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01the match on mat 2 has ended prematurely.");
	
	//teleport out of ring
	TeleportMat2ParticipantsToExit();
	
	//reset mat1
	ClearMat2ClientVars();
	
	//enable the character button
	EnableButtonAndHologramMat2();
}

stock EndKendoMat1GamePrematurely_CharacterChangeViolation(violator)
{
	//send message
	MessageMat1Participants("[Kendo]: match ended due to attempted character change.");
	
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01the match on mat 1 has ended (attempted character change by %N).", violator);
	
	//teleport out of ring
	TeleportMat1ParticipantsToExit();
	
	//reset mat1
	ClearMat1ClientVars();
	
	//enable the character button
	EnableButtonAndHologramMat1();
}

stock EndKendoMat2GamePrematurely_CharacterChangeViolation(violator)
{
	//send message
	MessageMat2Participants("[Kendo]: match ended due to attempted character change.");
	
	PrintToChatAll("\x04[\x03Kendo\x04]\x03: \x01the match on mat 2 has ended (attempted character change by %N).", violator);
	
	//teleport out of ring
	TeleportMat2ParticipantsToExit();
	
	//reset mat1
	ClearMat2ClientVars();
	
	//enable the character button
	EnableButtonAndHologramMat2();
}

stock bool:IsClientAParticipant_Mat1(client)
{
	if( IsValidClient(client) )
	{
		if( g_KendoMat1_Participants[client] != 0 )
		{
			return true;
		}
	}
	
	return false;
}

stock bool:IsClientAParticipant_Mat2(client)
{
	if( IsValidClient(client) )
	{
		if( g_KendoMat2_Participants[client] != 0 )
		{
			return true;
		}
	}
	
	return false;
}

stock GetMat1Participants(arr[])
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat1_Participants[i] == 1 )
		{
			//plat 1 participant
			arr[0] = i;
		}
		
		if( g_KendoMat1_Participants[i] == 2 )
		{
			//plat 2 participant
			arr[1] = i;
		}
	}
}

stock GetMat2Participants(arr[])
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat2_Participants[i] == 1 )
		{
			//plat 1 participant
			arr[0] = i;
		}
		
		if( g_KendoMat2_Participants[i] == 2 )
		{
			//plat 2 participant
			arr[1] = i;
		}
	}
}

stock bool:IsValidClient(client)
{
	if(1 <= client <= MaxClients)
	{
		if( IsValidEntity(client) )
		{
			if( IsClientInGame(client) )
			{
				return true;
			}
		}
	}
	return false;
}

stock TeleportMat1ParticipantsToStart()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if(g_KendoMat1_Participants[i] == 1)
			{
				TeleportEntity(i, g_vec_KendoMat1Start_plat1, NULL_VECTOR, NULL_VECTOR);
				//SetEntPropVector(i, Prop_Send, "m_angRotation", Float:{90.0, 90.0, 90.0});
			}
			else if( g_KendoMat1_Participants[i] == 2 )
			{
				TeleportEntity(i, g_vec_KendoMat1Start_plat2, NULL_VECTOR, NULL_VECTOR);
				//SetEntPropVector(i, Prop_Send, "m_angRotation", Float:{90.0, 90.0, 90.0});
			}
		}
	}
}

stock TeleportMat2ParticipantsToStart()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if(g_KendoMat2_Participants[i] == 1)
			{
				TeleportEntity(i, g_vec_KendoMat2Start_plat1, NULL_VECTOR, NULL_VECTOR);
				//SetEntPropVector(i, Prop_Send, "m_angRotation", Float:{90.0, 90.0, 90.0});
			}
			else if( g_KendoMat2_Participants[i] == 2 )
			{
				TeleportEntity(i, g_vec_KendoMat2Start_plat2, NULL_VECTOR, NULL_VECTOR);
				//SetEntPropVector(i, Prop_Send, "m_angRotation", Float:{90.0, 90.0, 90.0});
			}
		}
	}
}

stock Freeze_DelayTeleportToStart_Mat1_INITIAL()
{
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	ForceCharacter(cl_arr[0], g_Mat1_Character_Type);
	ForceCharacter(cl_arr[1], g_Mat1_Character_Type);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
	
	CreateTimer(3.0, Timer_DelayTeleportToStart_INITIAL, _, TIMER_FLAG_NO_MAPCHANGE);
}	

public Action:Timer_DelayTeleportToStart_INITIAL(Handle:timer)
{
	TeleportMat1ParticipantsToStart();
	
	//Give participants full hp or bushido
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	if( g_Bushido_Mat1 )
	{
		SetEntityHealth(cl_arr[0], 1);
		SetEntityHealth(cl_arr[1], 1);
	}
	else
	{
		SetEntityHealth(cl_arr[0], 100);
		SetEntityHealth(cl_arr[1], 100);
	}
	
	AcceptEntityInput(g_Mat1_RoundStart_Sound_Ent, "Start");
	CreateTimer(3.0, Timer_StopRoundStartSound, _, TIMER_FLAG_NO_MAPCHANGE);
	
	TeleportEntity(cl_arr[0], NULL_VECTOR, g_vec_KendoMat1View_plat1, Float:{0.0, 0.0, 0.0});
	TeleportEntity(cl_arr[1], NULL_VECTOR, g_vec_KendoMat1View_plat2, Float:{0.0, 0.0, 0.0});
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if( IsClientAParticipant_Mat1(i) )
			{
				SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SetEntProp(i, Prop_Send, "m_bKneeling", 0);
				SetEntProp(i, Prop_Send, "m_iStringIndex", 0);
				//m_iStringIndex
			}
		}
	}
	
	ShortFreezeOnRoundStart_Mat1();
}

stock Freeze_DelayTeleportToStart_Mat1()
{
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
		
	CreateTimer(3.0, Timer_DelayTeleportToStart, _, TIMER_FLAG_NO_MAPCHANGE);
}	

public Action:Timer_DelayTeleportToStart(Handle:timer)
{
	TeleportMat1ParticipantsToStart();
	
	AcceptEntityInput(g_Mat1_RoundStart_Sound_Ent, "Start");
	CreateTimer(3.0, Timer_StopRoundStartSound, _, TIMER_FLAG_NO_MAPCHANGE);
	
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	TeleportEntity(cl_arr[0], NULL_VECTOR, g_vec_KendoMat1View_plat1, Float:{0.0, 0.0, 0.0});
	TeleportEntity(cl_arr[1], NULL_VECTOR, g_vec_KendoMat1View_plat2, Float:{0.0, 0.0, 0.0});
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if( IsClientAParticipant_Mat1(i) )
			{
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
				SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SetEntProp(i, Prop_Send, "m_bKneeling", 0);
				SetEntProp(i, Prop_Send, "m_iStringIndex", 0);				
				//m_iStringIndex
			}
		}
	}
	
	ShortFreezeOnRoundStart_Mat1();
}

stock ShortFreezeOnRoundStart_Mat1()
{
	CreateTimer(0.2, Timer_ShortFreeze_Mat1, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ShortFreeze_Mat1(Handle:timer)
{
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
		
	CreateTimer(0.5, Timer_ShortUnfreeze, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ShortUnfreeze(Handle:timer)
{
	decl cl_arr[2];
	GetMat1Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 1.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 1.0);
}

public Action:Timer_StopRoundStartSound(Handle:timer)
{
	AcceptEntityInput(g_Mat1_RoundStart_Sound_Ent, "Stop");
}

stock TeleportMat1ParticipantsToExit()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if(g_KendoMat1_Participants[i] == 1)
			{
				TeleportEntity(i, g_vec_KendoMat1Exit_plat1, NULL_VECTOR, NULL_VECTOR);
			}
			else if( g_KendoMat1_Participants[i] == 2 )
			{
				TeleportEntity(i, g_vec_KendoMat1Exit_plat2, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}


stock MessageMat1Participants(const String:message[])
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientAParticipant_Mat1(i) )
		{
			PrintHintText(i, message);
		}
	}
}

stock ClearMat1ClientVars()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		g_KendoMat1_Participants[i] = 0;
		g_Mat1_Client_Blocked[i] = false;
		g_Mat1_Client_Intercepted[i] = false;
		g_Mat1_Plat1_Client_Confirmation = false;
		g_Mat1_Plat2_Client_Confirmation = false;
	}
	
	SetVariantString("3")
	AcceptEntityInput(g_Mat1_Plat1_Model, "Skin");
	
	SetVariantString("6")
	AcceptEntityInput(g_Mat1_Plat2_Model, "Skin");
}

stock Lock_Delay_Unlock_Settings_Button_Mat1()
{
	AcceptEntityInput(g_Mat1_Character_Type_Button_Func, "Disable");
	CreateTimer(15.0, Timer_UnlockButton_Mat1, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_UnlockButton_Mat1(Handle:timer)
{		
	AcceptEntityInput(g_Mat1_Character_Type_Button_Func, "Enable");
}

stock DisableButtonAndHologramMat1()
{
	AcceptEntityInput(g_Mat1_Character_Type_Button_Model, "Disable");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Model, "DisableCollision");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Func, "Disable");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Text, "Disable");
	
	AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Pure, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Judgement, "Disable");
	
	AcceptEntityInput(g_Mat1_Bushido_Symbol, "Disable");
	AcceptEntityInput(g_Mat1_Rules_Plat1_Ent, "Disable");
	AcceptEntityInput(g_Mat1_Rules_Plat2_Ent, "Disable");	
}

stock EnableButtonAndHologramMat1()
{
	AcceptEntityInput(g_Mat1_Character_Type_Button_Model, "Enable");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Model, "EnableCollision");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Func, "Enable");
	AcceptEntityInput(g_Mat1_Character_Type_Button_Text, "Enable");
	
	AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Pure, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Disable");
	AcceptEntityInput(g_Mat1_Hologram_Judgement, "Enable");
	
	SetVariantString("3")
	AcceptEntityInput(g_Mat1_Plat1_Model, "Skin");
	
	SetVariantString("6")
	AcceptEntityInput(g_Mat1_Plat2_Model, "Skin");
	
	
	g_Mat1_Character_Type = DEFAULT_CHAR_TYPE_MAT1;
	g_Bushido_Mat1 = false;
	
}

stock Mat1_ChangeHologramTo(const String:character[])
{
	if(StrEqual(character, "ryoku"))
	{
		AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Enable");
		AcceptEntityInput(g_Mat1_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Judgement, "Disable");
	}
	else if(StrEqual(character, "pure"))
	{
		AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Pure, "Enable");
		AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Judgement, "Disable");
	}
	else if(StrEqual(character, "judgement"))
	{
		AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Judgement, "Enable");
	}
	else if(StrEqual(character, "phalanx"))
	{
		AcceptEntityInput(g_Mat1_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat1_Hologram_Phalanx, "Enable");
		AcceptEntityInput(g_Mat1_Hologram_Judgement, "Disable");
	}
}

stock ForceCharacter(client, type)
{
	if( IsValidClient(client) )
	{
		if( type == 3 )
		{
			//SetEntProp(client, Prop_Send, "m_CharacterIndex", 3);
			//SetEntityModel(client, "models/player/characters/pure/pure.mdl");
			ClientCommand(client, "vs_character pure");
			
		}
		else if( type == 0 )
		{
			//SetEntProp(client, Prop_Send, "m_CharacterIndex", 0);
			//SetEntityModel(client, "models/player/characters/phalanx/phalanx.mdl");
			ClientCommand(client, "vs_character phalanx");
		}
		else if( type == 1 )
		{
			//SetEntProp(client, Prop_Send, "m_CharacterIndex", 1);
			//SetEntityModel(client, "models/player/characters/knight/knight.mdl");
			ClientCommand(client, "vs_character knight");
		}
		else if( type == 2 )
		{
			//SetEntProp(client, Prop_Send, "m_CharacterIndex", 2);
			//SetEntityModel(client, "models/player/characters/ryoku/ryoku.mdl");
			ClientCommand(client, "vs_character ryoku");
			
		}
	}
}



//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
//===============================================================================MAT2===============================================================================//
stock Freeze_DelayTeleportToStart_Mat2_INITIAL()
{
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	ForceCharacter(cl_arr[0], g_Mat2_Character_Type);
	ForceCharacter(cl_arr[1], g_Mat2_Character_Type);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
	
	CreateTimer(3.0, Timer_DelayTeleportToStart_INITIAL_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}	

public Action:Timer_DelayTeleportToStart_INITIAL_Mat2(Handle:timer)
{
	TeleportMat2ParticipantsToStart();
	
	//Give participants full hp or bushido
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	if( g_Bushido_Mat2 )
	{
		SetEntityHealth(cl_arr[0], 1);
		SetEntityHealth(cl_arr[1], 1);
	}
	else
	{
		SetEntityHealth(cl_arr[0], 100);
		SetEntityHealth(cl_arr[1], 100);
	}
	
	AcceptEntityInput(g_Mat2_RoundStart_Sound_Ent, "Start");
	CreateTimer(3.0, Timer_StopRoundStartSound_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
	
	TeleportEntity(cl_arr[0], NULL_VECTOR, g_vec_KendoMat2View_plat1, Float:{0.0, 0.0, 0.0});
	TeleportEntity(cl_arr[1], NULL_VECTOR, g_vec_KendoMat2View_plat2, Float:{0.0, 0.0, 0.0});
	
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if( IsClientAParticipant_Mat2(i) )
			{
				SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SetEntProp(i, Prop_Send, "m_bKneeling", 0);
				SetEntProp(i, Prop_Send, "m_iStringIndex", 0);
				//m_iStringIndex
			}
		}
	}
	
	ShortFreezeOnRoundStart_Mat2();
}

stock Freeze_DelayTeleportToStart_Mat2()
{
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
		
	CreateTimer(3.0, Timer_DelayTeleportToStart_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}	

public Action:Timer_DelayTeleportToStart_Mat2(Handle:timer)
{
	TeleportMat2ParticipantsToStart();
	
	AcceptEntityInput(g_Mat2_RoundStart_Sound_Ent, "Start");
	CreateTimer(3.0, Timer_StopRoundStartSound_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
	
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	TeleportEntity(cl_arr[0], NULL_VECTOR, g_vec_KendoMat2View_plat1, Float:{0.0, 0.0, 0.0});
	TeleportEntity(cl_arr[1], NULL_VECTOR, g_vec_KendoMat2View_plat2, Float:{0.0, 0.0, 0.0});

	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if( IsClientAParticipant_Mat2(i) )
			{
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
				SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 1.0);
				SetEntProp(i, Prop_Send, "m_bKneeling", 0);
				SetEntProp(i, Prop_Send, "m_iStringIndex", 0);				
				//m_iStringIndex
			}
		}
	}
	
	ShortFreezeOnRoundStart_Mat2();
}

stock ShortFreezeOnRoundStart_Mat2()
{
	CreateTimer(0.2, Timer_ShortFreeze_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ShortFreeze_Mat2(Handle:timer)
{
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 0.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 0.0);
		
	CreateTimer(0.5, Timer_ShortUnfreeze_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ShortUnfreeze_Mat2(Handle:timer)
{
	decl cl_arr[2];
	GetMat2Participants(cl_arr);
	
	SetEntPropFloat(cl_arr[0], Prop_Send, "m_flLaggedMovementValue", 1.0);
	SetEntPropFloat(cl_arr[1], Prop_Send, "m_flLaggedMovementValue", 1.0);
}

public Action:Timer_StopRoundStartSound_Mat2(Handle:timer)
{
	AcceptEntityInput(g_Mat2_RoundStart_Sound_Ent, "Stop");
}

stock TeleportMat2ParticipantsToExit()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			if(g_KendoMat2_Participants[i] == 1)
			{
				TeleportEntity(i, g_vec_KendoMat2Exit_plat1, NULL_VECTOR, NULL_VECTOR);
			}
			else if( g_KendoMat2_Participants[i] == 2 )
			{
				TeleportEntity(i, g_vec_KendoMat2Exit_plat2, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}


stock MessageMat2Participants(const String:message[])
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( IsClientAParticipant_Mat2(i) )
		{
			PrintHintText(i, message);
		}
	}
}

stock ClearMat2ClientVars()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		g_KendoMat2_Participants[i] = 0;
		g_Mat2_Client_Blocked[i] = false;
		g_Mat2_Client_Intercepted[i] = false;
		g_Mat2_Plat1_Client_Confirmation = false;
		g_Mat2_Plat2_Client_Confirmation = false;
	}
	
	SetVariantString("3")
	AcceptEntityInput(g_Mat2_Plat1_Model, "Skin");
	
	SetVariantString("6")
	AcceptEntityInput(g_Mat2_Plat2_Model, "Skin");
}

stock LoadSettingsConfig()
{
	BuildPath(Path_SM, g_szFile, PLATFORM_MAX_PATH, "configs/sf_kendo_settings.ini"); //read file path into var
	
	//read config and store globals
	//declare vars 
	decl String:SectionName[32];
	
	//load keyvalues
	new Handle:kv = CreateKeyValues("SF_Kendo_Settings")
	FileToKeyValues(kv, g_szFile)
	KvGotoFirstSubKey(kv);
	
	//loop through keyvalues and store info
	do
	{		
		KvGetSectionName(kv, SectionName, sizeof(SectionName));
		
		if( StrEqual(SectionName, "Mat 1", false) )
		{
			KvGetVector(kv, "Mat_1_start_location_player_1", g_vec_KendoMat1Start_plat1);
			KvGetVector(kv, "Mat_1_start_location_player_2", g_vec_KendoMat1Start_plat2);
			KvGetVector(kv, "Mat_1_exit_location_player_1", g_vec_KendoMat1Exit_plat1);
			KvGetVector(kv, "Mat_1_exit_location_player_2", g_vec_KendoMat1Exit_plat2);
			KvGetVector(kv, "Mat_1_view_angles_player_1", g_vec_KendoMat1View_plat1);
			KvGetVector(kv, "Mat_1_view_angles_player_2", g_vec_KendoMat1View_plat2);
		}
		else if( StrEqual(SectionName, "Mat 2", false) )
		{
			KvGetVector(kv, "Mat_2_start_location_player_1", g_vec_KendoMat2Start_plat1);
			KvGetVector(kv, "Mat_2_start_location_player_2", g_vec_KendoMat2Start_plat2);
			KvGetVector(kv, "Mat_2_exit_location_player_1", g_vec_KendoMat2Exit_plat1);
			KvGetVector(kv, "Mat_2_exit_location_player_2", g_vec_KendoMat2Exit_plat2);
			KvGetVector(kv, "Mat_2_view_angles_player_1", g_vec_KendoMat2View_plat1);
			KvGetVector(kv, "Mat_2_view_angles_player_2", g_vec_KendoMat2View_plat2);
		}
		
	} while (KvGotoNextKey(kv));
	
	//clean up
	KvRewind(kv);
	CloseHandle(kv);
}

stock Lock_Delay_Unlock_Settings_Button_Mat2()
{
	AcceptEntityInput(g_Mat2_Character_Type_Button_Func, "Disable");
	CreateTimer(15.0, Timer_UnlockButton_Mat2, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_UnlockButton_Mat2(Handle:timer)
{
	AcceptEntityInput(g_Mat2_Character_Type_Button_Func, "Enable");
}

stock DisableButtonAndHologramMat2()
{
	AcceptEntityInput(g_Mat2_Character_Type_Button_Model, "Disable");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Model, "DisableCollision");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Func, "Disable");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Text, "Disable");
	
	AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Pure, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Judgement, "Disable");
	
	AcceptEntityInput(g_Mat2_Bushido_Symbol, "Disable");
	AcceptEntityInput(g_Mat2_Rules_Plat1_Ent, "Disable");
	AcceptEntityInput(g_Mat2_Rules_Plat2_Ent, "Disable");	
}

stock EnableButtonAndHologramMat2()
{
	AcceptEntityInput(g_Mat2_Character_Type_Button_Model, "Enable");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Model, "EnableCollision");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Func, "Enable");
	AcceptEntityInput(g_Mat2_Character_Type_Button_Text, "Enable");
	
	AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Pure, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Disable");
	AcceptEntityInput(g_Mat2_Hologram_Judgement, "Enable");
	
	SetVariantString("3")
	AcceptEntityInput(g_Mat2_Plat1_Model, "Skin");
	
	SetVariantString("6")
	AcceptEntityInput(g_Mat2_Plat2_Model, "Skin");
	
	
	g_Mat2_Character_Type = DEFAULT_CHAR_TYPE_MAT2;
	g_Bushido_Mat2 = false;
	
}

stock Mat2_ChangeHologramTo(const String:character[])
{
	if(StrEqual(character, "ryoku"))
	{
		AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Enable");
		AcceptEntityInput(g_Mat2_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Judgement, "Disable");
	}
	else if(StrEqual(character, "pure"))
	{
		AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Pure, "Enable");
		AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Judgement, "Disable");
	}
	else if(StrEqual(character, "judgement"))
	{
		AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Judgement, "Enable");
	}
	else if(StrEqual(character, "phalanx"))
	{
		AcceptEntityInput(g_Mat2_Hologram_Ryoku, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Pure, "Disable");
		AcceptEntityInput(g_Mat2_Hologram_Phalanx, "Enable");
		AcceptEntityInput(g_Mat2_Hologram_Judgement, "Disable");
	}
}

stock UnRegisterAllPlayers_Plat1_Mat1()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat1_Participants[i] == 1 )
		{
			g_KendoMat1_Participants[i] = 0;
		}
	}
}

stock UnRegisterAllPlayers_Plat2_Mat1()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat1_Participants[i] == 2 )
		{
			g_KendoMat1_Participants[i] = 0;
		}
	}
}

stock UnRegisterAllPlayers_Plat1_Mat2()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat2_Participants[i] == 1 )
		{
			g_KendoMat2_Participants[i] = 0;
		}
	}
}

stock UnRegisterAllPlayers_Plat2_Mat2()
{
	for( new i = 1; i <= MaxClients; i++ )
	{
		if( g_KendoMat2_Participants[i] == 2 )
		{
			g_KendoMat2_Participants[i] = 0;
		}
	}
}