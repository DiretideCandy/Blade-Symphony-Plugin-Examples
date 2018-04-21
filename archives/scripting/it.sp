//bugs: Judge's HR t1
//
//todo: grabs steal ammo



	//Ryoku, Van
	//больше точек на дистрикте, цветных и белых

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PI 3.1415926535897932384626433832795

#define DELAY_MID 0
#define DELAY_FIRST 1
#define DELAY_LAST 2

#define BEAM_WIDTH_START 9.0
#define BEAM_WIDTH_END 9.0
#define BEAM_WIDTH_START_SWORD 7.5
#define BEAM_WIDTH_END_SWORD 7.5

#define VMAX 3000

#define MAX_ACTIONS 256
#define MAX_DELAYS 200

#define AMMO_EMPTY "-"

#define AMMO_STRING_H "H"
#define AMMO_STRING_B "B"
#define AMMO_STRING_F "F"
#define AMMO_STRING_A "A"
#define AMMO_STRING_ANY "0"

#define AMMO_TIER_3 "3"
#define AMMO_TIER_2 "2"
#define AMMO_TIER_1 "1"
#define AMMO_TIER_ANY "0"

#define POWERUP_R 15.0
#define POWERUP_S 2.0
#define POWERUP_H 50.0
#define POWERUP_LIFE 30.0
#define POWERUP_MAX 3
#define POWERUP_MAXBEAMS 5

#define POWERUP_RESPTIME_MIN 14.0
#define POWERUP_RESPTIME_MAX 16.0

new tar, beam;

new Float:Delay[MAX_ACTIONS*3][MAX_DELAYS]; //Delay[ActId][Point]
new String:Stance[MAX_ACTIONS][5];
//new Float:TEST_Delays[40];
//new TEST_Delays_N = 400;

new ActId_Init, Delay_Init, Float:ActId_AnimTime, String:Act_Char[20];

new String:LastName[MAXPLAYERS+1][32];
new CurrEnt[MAXPLAYERS+1];
new LastEnt[MAXPLAYERS+1];
new Float:LastPoint[MAXPLAYERS+1][3];
new Float:LastPoint_hand[MAXPLAYERS+1][3];

new tempent_E[MAXPLAYERS+1];
new tempent_S[MAXPLAYERS+1];
new NextStep[MAXPLAYERS+1];

new counter[MAXPLAYERS+1];

new Float:TEST_Time;
new Float:TEST_Time_2[MAXPLAYERS+1];

new Vert_Ent[VMAX];
new Vert_Owner[VMAX];
new bool:Vert_Exists[VMAX];
new Float:Vert_Pos[VMAX][3];
new Float:Vert_E[VMAX][3];
new Float:Vert_Vector_N[VMAX][3];
new Float:Vert_Speed[VMAX];
new Float:Vert_MaxDist[VMAX];
new Vert_Beam[VMAX];
new Vert_BeamTarget[VMAX];
new bool:Vert_Last[VMAX];
new String:Vert_St[VMAX][10];
new String:Vert_Ti[VMAX][10];
new VertCounter;

new PowerUpCounter;
new PowerUp_AmmoCount[POWERUP_MAX];
new String:PowerUp_AmmoType[POWERUP_MAX][5];
new Float:PowerUp_Pos[POWERUP_MAX][3];
new PowerUp_Beam[POWERUP_MAX][POWERUP_MAXBEAMS];
new PowerUp_BeamTarget[POWERUP_MAX][5];
new Float:PowerUp_Life[POWERUP_MAX];

new PowerUp_Point[128][3];
new PowerUp_PointCount;
new PowerUp_HighPoint[128][3];
new PowerUp_HighPointCount;

new SwordBeam[MAXPLAYERS+1];
new SwordBeam_Target_E[MAXPLAYERS+1];
new SwordBeam_Target_S[MAXPLAYERS+1];

new bool:OPclient[MAXPLAYERS+1];
new OPClientState[MAXPLAYERS+1];
new CurrActId[MAXPLAYERS+1];
new CurrDelay[MAXPLAYERS+1];

new AmmoCounter[MAXPLAYERS+1];
new String:Ammo[MAXPLAYERS+1][4];

new LastDuelState;

new Handle:g_speed=INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "imba tracers",
	author = "Crystal",
	description = "",
	version = "0.001",
	url = ""
};


	
public OnPluginStart() 
{
		
	g_speed = CreateConVar("sm_laser_speed","275.0");
	
	RegAdminCmd("givelaser", command_givelaser, ADMFLAG_RCON);
	RegAdminCmd("test", command_test, ADMFLAG_RCON);	
	RegAdminCmd("hook_all", command_hook_all, ADMFLAG_RCON);
	
	InitDelays();
	PrintToServer("InitDelays done");
	
	TEST_Time = GetGameTime();
	//TEST_Time = GetEngineTime();
	HookEvent("player_death", PlayerDeath);
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (OPclient[victim])
	{
		AmmoCounter[victim] = 0;
		UpdateHudAmmo(victim);
		LasersOff(victim);
	}
}

AddCounter(client)
{
	counter[client]++;
	if (counter[client]>32000)
		counter[client] = -32000;
}

public OnMapStart()
{
	SetRandomSeed(GetTime());
	
	//PrecacheSound("hl/beamstart10.wav",true);
	//AddFileToDownloadsTable( "sound/hl/beamstart10.wav" );
	
	PrecacheModel("materials/particle/dys_beam3.vmt");
	PrecacheModel("materials/particle/dys_beam_big_rect.vmt");
	
	PrecacheGeneric("particles/sword_hearts.pcf");
	AddToStringTable( FindStringTable( "ParticleEffectNames" ), "sword_hearts" );
	AddToStringTable( FindStringTable( "ExtraParticleFilesTable" ), "particles/sword_hearts.pcf" );
	AddFileToDownloadsTable( "particles/sword_hearts.pcf" );
	
	TEST_Time = GetGameTime();
	//TEST_Time = GetEngineTime();
	
	for (new i=0; i<=MAXPLAYERS; i++)
	{
		OPclient[i] = false;
		OPClientState[i] = 0;
		CurrActId[i] = -1;
		strcopy(Ammo[i], sizeof(Ammo), "-");
		AmmoCounter[i] =0;
	}
	PowerUpCounter = 0;
	
	
	InitPowerUpPoints();
	
	InitSwordBeams();
	
	if ((PowerUp_PointCount > 0) || (PowerUp_HighPointCount > 0))
		CreateTimer( GetRandomFloat(POWERUP_RESPTIME_MIN, POWERUP_RESPTIME_MAX) , timer_SpawnPowerUp );
}

UpdateHudAmmo(client)
{
	new String:Ammotxt1[20];
	new String:Ammotxt2[20];
	new String:Ammotxt3[20];
		
	new String:St[5];
	new String:Ti[5];
	strcopy(St, 2, Ammo[client]);
	strcopy(Ti, 2, Ammo[client][1]);
	if (AmmoCounter[client]>0)
	{
		new String:AmmoChar[3] = "-";
		if (StringToInt(Ti) == 0)
		{
			strcopy(AmmoChar, sizeof(AmmoChar), "|");
		}
		
		if (AmmoCounter[client]>4)
		{
			Format(Ammotxt1, sizeof(Ammotxt1), "%s%s%s%s%s", AmmoChar,AmmoChar,AmmoChar,AmmoChar,AmmoChar);
		}
		else
		{
			for (new i=0; i< AmmoCounter[client]; i++)
			{
				Format(Ammotxt1, sizeof(Ammotxt1), "%s%s", Ammotxt1, AmmoChar);
			}
		}
		
		if (StringToInt(Ti)>2)
			strcopy(Ammotxt3, sizeof(Ammotxt3), Ammotxt1);
		
		if (StringToInt(Ti)>1)
			strcopy(Ammotxt2, sizeof(Ammotxt2), Ammotxt1);
		
		
	}
	else
	{
		
	}
		
	new R, G, B;
	if (StrEqual(St, AMMO_STRING_A))
	{
		R = 255; G = 255; B = 0;
	}
	else if (StrEqual(St, AMMO_STRING_F))
	{
		R = 0; G = 255; B = 75;
	}
	else if (StrEqual(St, AMMO_STRING_B))
	{
		R = 0; G = 0; B = 255;
	}
	else if (StrEqual(St, AMMO_STRING_H))
	{
		R = 255; G = 0; B = 0;
	}
	else //any
	{
		R = 255; G = 255; B = 255;
	}
	SetHudTextParams(0.0, 0.5, 10000.0, R ,G ,B ,255);
	ShowHudText(client, 1, Ammotxt1);
	SetHudTextParams(0.0, 0.51, 10000.0, R ,G ,B ,255);
	ShowHudText(client, 2, Ammotxt2);
	SetHudTextParams(0.0, 0.52, 10000.0, R ,G ,B ,255);
	ShowHudText(client, 3, Ammotxt3);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_PreThink, hookPreThink_Steps);
}

public OnClientDisconnect(client)
{
	if (OPclient[client]) 
	{
		LasersOff(client);
	}
		
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_PreThink, hookPreThink_Steps);
}

InitSwordBeams()
{
	new Float:Zero[3];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		
		
		SwordBeam_Target_E[i] = CreateEntityByName("env_sprite"); 
		SetEntityModel( SwordBeam_Target_E[i], "materials/particle/dys_beam_big_rect.vmt" );
		DispatchKeyValue( SwordBeam_Target_E[i], "renderamt", "255" );
		DispatchKeyValue( SwordBeam_Target_E[i], "rendercolor", "255 255 255" ); 
		DispatchSpawn( SwordBeam_Target_E[i] );
		AcceptEntityInput(SwordBeam_Target_E[i],"ShowSprite");
		ActivateEntity(SwordBeam_Target_E[i]);
		TeleportEntity( SwordBeam_Target_E[i], Zero, NULL_VECTOR, NULL_VECTOR );
		
		SwordBeam_Target_S[i] = CreateEntityByName("env_sprite"); 
		SetEntityModel( SwordBeam_Target_S[i], "materials/particle/dys_beam_big_rect.vmt" );
		DispatchKeyValue( SwordBeam_Target_S[i], "renderamt", "255" );
		DispatchKeyValue( SwordBeam_Target_S[i], "rendercolor", "255 255 255" ); 
		DispatchSpawn( SwordBeam_Target_S[i] );
		AcceptEntityInput(SwordBeam_Target_S[i],"ShowSprite");
		ActivateEntity(SwordBeam_Target_S[i]);
		TeleportEntity( SwordBeam_Target_S[i], Zero, NULL_VECTOR, NULL_VECTOR );
		
	
						SwordBeam[i] = CreateEntityByName( "env_beam" );
						SetEntityModel( SwordBeam[i], "materials/particle/dys_beam_big_rect.vmt" );
						DispatchKeyValue( SwordBeam[i], "renderamt", "100" );
						DispatchKeyValue( SwordBeam[i], "rendermode", "0" );
						 
						DispatchKeyValue( SwordBeam[i], "life", "0" ); 
						
						DispatchKeyValue( SwordBeam[i], "rendercolor", "0 0 0" ); 
							
						DispatchKeyValue( SwordBeam[i], "spawnflags", "0");
						DispatchKeyValue( SwordBeam[i], "damage", "2.0" );
						
						TeleportEntity( SwordBeam[i], Zero, NULL_VECTOR, NULL_VECTOR ); 
						
						DispatchSpawn(SwordBeam[i]);
						SetEntPropEnt( SwordBeam[i], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(SwordBeam_Target_E[i]) );
						SetEntPropEnt( SwordBeam[i], Prop_Send, "m_hAttachEntity", EntIndexToEntRef(SwordBeam_Target_S[i]), 1 );
						SetEntProp( SwordBeam[i], Prop_Send, "m_nNumBeamEnts", 2);
						SetEntProp( SwordBeam[i], Prop_Send, "m_nBeamType", 2);
						
						SetEntPropFloat( SwordBeam[i], Prop_Data, "m_fWidth",  BEAM_WIDTH_START_SWORD );
						SetEntPropFloat( SwordBeam[i], Prop_Data, "m_fEndWidth", BEAM_WIDTH_END_SWORD );
						ActivateEntity(SwordBeam[i]);
						DispatchSpawn(SwordBeam[i]);
						AcceptEntityInput(SwordBeam[i],"TurnOff");
	}
}

LasersOn(client, const String:AddedAmmo[], AmmoCount)
{
	OPclient[client] = true;
	OPClientState[client] = 0;
	CurrActId[client] = -1;
	NextStep[client] = -1;
	CurrActId[client] = -1;
	CurrDelay[client] = -1;
	
	AmmoCounter[client] = AmmoCount;
	
	strcopy(Ammo[client], sizeof(Ammo[]), AddedAmmo);
		
	UpdateHudAmmo(client);
	
	//Show Sword Laser
	new String:St[5];
	strcopy(St, 2, Ammo[client]);
	
	decl Float:fPosition[3];
	GetClientAbsOrigin(client, fPosition);
				
	TeleportEntity(SwordBeam_Target_S[client], fPosition, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(SwordBeam_Target_E[client], fPosition, NULL_VECTOR, NULL_VECTOR);
				
	if (StrEqual(St, AMMO_STRING_A))
	{
		SetVariantString("rendercolor 255 255 0" ); 
	}
	else if (StrEqual(St, AMMO_STRING_F))
	{
		SetVariantString("rendercolor 0 255 75" ); 
	}
	else if (StrEqual(St, AMMO_STRING_B))
	{
		SetVariantString("rendercolor 0 0 255" ); 
	}
	else if (StrEqual(St, AMMO_STRING_H))
	{
		SetVariantString("rendercolor 255 0 0" ); 
	}
	else //any
	{
		SetVariantString("rendercolor 255 255 255" ); 
	}
    AcceptEntityInput(SwordBeam[client], "AddOutput"); 
	
	SetVariantString("!activator");
	AcceptEntityInput(SwordBeam_Target_S[client], "SetParent", client, SwordBeam_Target_S[client], 0);
	SetVariantString("anim_attachment_S");
	AcceptEntityInput(SwordBeam_Target_S[client], "SetParentAttachment");
	
	SetVariantString("!activator");
	AcceptEntityInput(SwordBeam_Target_E[client], "SetParent", client, SwordBeam_Target_E[client], 0);
	SetVariantString("anim_attachment_E");
	AcceptEntityInput(SwordBeam_Target_E[client], "SetParentAttachment");
	
	AcceptEntityInput(SwordBeam[client],"TurnOn");
	
}



LasersOff(client)
{
	OPclient[client] = false;
	OPClientState[client] = 0;
	CurrActId[client] = -1;
	NextStep[client] = -1;
	CurrActId[client] = -1;
	CurrDelay[client] = -1;
	
	AcceptEntityInput( SwordBeam[client], "TurnOff" );
	AcceptEntityInput(SwordBeam[client], "ClearParent");
	AcceptEntityInput(SwordBeam_Target_S[client], "ClearParent");
	AcceptEntityInput(SwordBeam_Target_E[client], "ClearParent");
	new Float:Zero[3];
	TeleportEntity( SwordBeam_Target_S[client], Zero, NULL_VECTOR, NULL_VECTOR );
	TeleportEntity( SwordBeam_Target_E[client], Zero, NULL_VECTOR, NULL_VECTOR );
	
	
	/*
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon,
		Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damage <= 0.0)
		return Plugin_Continue;
	
	
	//PrintToServer("--DEBUG-- Damage Taken from %d", attacker);
	if ((0 < victim) && (victim <= MaxClients))
	{
			for (new i=0; i<VMAX; i++)
			{
				if (Vert_Exists[i])
				{
					//PrintToServer("--DEBUG-- (Vert[%d]'s Beam is %d) <>( attacker is %d)", i, Vert_Beam[i], attacker);
					if (Vert_Beam[i] == attacker)
					{
						//PrintToServer("--DEBUG-- %d == %d", Vert_Beam[i], attacker);
						damage = 0.0;
						if (IsClientInGame(victim))
							if (IsPlayerAlive(victim))
								if (!IsInDuel(victim))
									FakeClientCommand(victim, "kill");
						
						return Plugin_Handled;
					}
				}
			}
			
			for (new i=1; i<=MaxClients; i++)
			{
				if (attacker == SwordBeam[i])
				{
					damage = 0.0;
						if (victim != i)
							if (IsClientInGame(victim))
								if (IsPlayerAlive(victim))
									if (!IsInDuel(victim))
										FakeClientCommand(victim, "kill");
						
						return Plugin_Handled;
				}
			}
			
	}
	
	
	return Plugin_Continue;
}

public Action:command_hook_all(client, args)
{
	for (new i = 1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(i, SDKHook_PreThink, hookPreThink_Steps);
		}
	}
}

public Action:command_it(client, args)
{
	if (args>0)
	{
		decl String:opstr[32];
		GetCmdArg(1, opstr, sizeof(opstr));
		new op = StringToInt(opstr);
		if (op > 0 && op <= MaxClients)
		{
			//OPclient[op] = !OPclient[op];
			if (OPclient[op])
			{
				OPclient[op] = false;
				PrintToChat(client, "[IT] Lasers[%d] off", op);
				if (op!=client)
					PrintToChat(op, "[IT] Lasers[%d] off", op);
				
				LasersOff(op);
			}
			else
			{
				OPclient[op] = true;
				PrintToChat(client, "[IT] Lasers[%d] ON", op);
				if (op!=client)
					PrintToChat(op, "[IT] Lasers[%d] ON", op);
				
				LasersOn(op, "00", 999);
			}
			
		}
	}
}

public OnGameFrame() 
{
	
	//////
	//
	// Verts
	//
	//////
	
	new Float:GameTime = GetGameTime();
	
	//new Float:delta = GameTime - TEST_Time;
	new Float:delta = (1000.0*GameTime - 1000.0*TEST_Time);
	
	new bool:flag = true;
	//Пересчитываем позиции частиц
	for (new i = 0; i<VMAX; i++)
		if (Vert_Exists[i])
		{
						
			Vert_Pos[i][0] += delta*Vert_Speed[i]*Vert_Vector_N[i][0]/1000.0;
			Vert_Pos[i][1] += delta*Vert_Speed[i]*Vert_Vector_N[i][1]/1000.0;
			Vert_Pos[i][2] += delta*Vert_Speed[i]*Vert_Vector_N[i][2]/1000.0;
			
			//PrintToServer("delta = %f", delta);
			
			if (Vert_MaxDist[i] > Dist(Vert_Pos[i], Vert_E[i] ) )
			{
				TeleportEntity(Vert_Ent[i], Vert_Pos[i], NULL_VECTOR, NULL_VECTOR);
				
			}
			else
			{
				RemoveVert(i);
			}
			
			flag = false;
		}
		
	if (flag)
	{
		VertCounter = 0;
	}
	
	//////
	//
	// PowerUps
	//
	//////
	if (PowerUpCounter>0)
	{
		
		for (new i = 0; i<PowerUpCounter; i++)
		{
			PowerUp_Life[i] += delta/1000.0;
			if (PowerUp_Life[i] >= POWERUP_LIFE)
			{
				RemovePowerUp(i);
				//i--;
			}
			else
			{
				for( new j = 0; j < POWERUP_MAXBEAMS; j++)
				{
			
					if (PowerUp_Beam[i][j] > 0)
					{
						new Float:BeamPos[3];
						BeamPos[0] = PowerUp_Pos[i][0] + (POWERUP_LIFE - PowerUp_Life[i]) * POWERUP_R * Sine( POWERUP_S * GameTime + j*2.0*PI/POWERUP_MAXBEAMS)/POWERUP_LIFE;
						BeamPos[1] = PowerUp_Pos[i][1] + (POWERUP_LIFE - PowerUp_Life[i]) * POWERUP_R * Cosine( POWERUP_S * GameTime  + j*2.0*PI/POWERUP_MAXBEAMS)/POWERUP_LIFE;
						BeamPos[2] = PowerUp_Pos[i][2];
						new Float:TarPos[3];
						TarPos[0] = BeamPos[0];
						TarPos[1] = BeamPos[1];
						TarPos[2] = PowerUp_Pos[i][2] + POWERUP_H;
						
						TeleportEntity(PowerUp_Beam[i][j], BeamPos, NULL_VECTOR, NULL_VECTOR);
						TeleportEntity(PowerUp_BeamTarget[i][j], TarPos, NULL_VECTOR, NULL_VECTOR);
					}
				}
				
				for (new j = 1; j <= MaxClients; j++)
				{					
					if (IsClientInGame(j))
						if (IsPlayerAlive(j))
							if (!IsInDuel(j))
							{
								new sheathed = GetEntProp(j, Prop_Send, "m_bSheathed");
								if (!sheathed)
								{
									new Float:origin[3];
									GetClientAbsOrigin(j, origin);
									if (Dist(origin, PowerUp_Pos[i]) < POWERUP_R * 2.5)
									{
										LasersOn(j, PowerUp_AmmoType[i], PowerUp_AmmoCount[i]);
										RemovePowerUp(i);
										//i--;
										break;
									}
								}
							}
				}
			}
		}
		
	}
	
	
	
	TEST_Time = GetGameTime();
	//TEST_Time = GetEngineTime();
}


public hookPreThink_Steps(client)
{
	new sheathed = GetEntProp(client, Prop_Send, "m_bSheathed");
	if ((OPclient[client]) && (sheathed == true))
	{
		OPClientState[client] = 0;
		AmmoCounter[client] = 0;
		UpdateHudAmmo(client);
		LasersOff(client);
	}
	else
	{
		
		
		if (NextStep[client]>1)
		{
			//PrintToServer("--DEBUG-- %d", NextStep[client]);
			
			switch (NextStep[client])
			{
				case 2, 4, 6:
				{
					
					//отцепляем
					AcceptEntityInput(tempent_E[client], "ClearParent");
					AcceptEntityInput(tempent_S[client], "ClearParent");
					//запоминаем S
					GetEntPropVector(tempent_S[client], Prop_Data, "m_vecAbsOrigin", LastPoint_hand[client]);
					GetEntPropVector(tempent_E[client], Prop_Data, "m_vecAbsOrigin", LastPoint[client]);			
									
					NextStep[client]++;
					
					RemoveEntityNow(tempent_S[client]);
					RemoveEntityNow(tempent_E[client]);
				/*}
				case 3, 5, 7:
				{*/
					
					
						
					new temptar = CreateEntityByName("env_sprite"); 
					SetEntityModel( temptar, "materials/particle/dys_beam_big_rect.vmt" );
					TeleportEntity( temptar, LastPoint[client], NULL_VECTOR, NULL_VECTOR );
					DispatchKeyValue( temptar, "renderamt", "255" );
					DispatchKeyValue( temptar, "rendercolor", "255 255 255" );
									
					DispatchSpawn( temptar );
					AcceptEntityInput(temptar,"ShowSprite");
					ActivateEntity(temptar);
					
								
					//DrawBeam(LastPoint[client], LastPoint_hand[client], 255, 0, 0, 100);
					//new Float:tempPoint[3];
					//tempPoint[0] = LastPoint[client][0] + 3*(LastPoint[client][0] - LastPoint_hand[client][0]);
					//tempPoint[1] = LastPoint[client][1] + 3*(LastPoint[client][1] - LastPoint_hand[client][1]);
					//tempPoint[2] = LastPoint[client][2] + 3*(LastPoint[client][2] - LastPoint_hand[client][2]);
					//DrawBeam(LastPoint[client], tempPoint, 0, 0, 225, 100);
					//
					///////
					if (NextStep[client] == 3)
					{
						//это была первая частица, ждём следующую
						new String:St[5];
						new String:Ti[5];
						strcopy(St, 2, Ammo[client]);
						strcopy(Ti, 2, Ammo[client][1]);
						AddVert(client, temptar, LastPoint_hand[client], LastPoint[client], -1, -1, false, St, Ti);
					}
					else
					{
						
						new String:St[5];
						new String:Ti[5];
						strcopy(St, 2, Ammo[client]);
						strcopy(Ti, 2, Ammo[client][1]);
						
						//создаём луч
						new beam = CreateEntityByName( "env_beam" );
						SetEntityModel( beam, "materials/particle/dys_beam_big_rect.vmt" );
						DispatchKeyValue( beam, "renderamt", "100" );
						DispatchKeyValue( beam, "rendermode", "0" );
						 
						DispatchKeyValue( beam, "life", "0" ); 
						
							if (StrEqual(St, AMMO_STRING_A))
							{
								DispatchKeyValue( beam, "rendercolor", "255 255 0" ); 
							}
							else if (StrEqual(St, AMMO_STRING_F))
							{
								DispatchKeyValue( beam, "rendercolor", "0 255 75" ); 
							}
							else if (StrEqual(St, AMMO_STRING_B))
							{
								DispatchKeyValue( beam, "rendercolor", "0 0 255" ); 
							}
							else if (StrEqual(St, AMMO_STRING_H))
							{
								DispatchKeyValue( beam, "rendercolor", "255 0 0" ); 
							}
							else //any
							{
								DispatchKeyValue( beam, "rendercolor", "255 255 255" ); 
							}
						
						DispatchKeyValue( beam, "spawnflags", "0");
						DispatchKeyValue( beam, "damage", "2.0" );
						
						//TeleportEntity( beam, point2, NULL_VECTOR, NULL_VECTOR ); 
						
						DispatchSpawn(beam);
						SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(LastEnt[client]) );
						SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(temptar), 1 );
						SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
						SetEntProp( beam, Prop_Send, "m_nBeamType", 2);
						
						SetEntPropFloat( beam, Prop_Data, "m_fWidth",  BEAM_WIDTH_START );
						SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", BEAM_WIDTH_END );
						ActivateEntity(beam);
						DispatchSpawn(beam);
						AcceptEntityInput(beam,"TurnOn");
						
						//SDKHook(beam, SDKHook_Touch, OnBeamTouch);

						AddVert(client, temptar, LastPoint_hand[client], LastPoint[client], beam, LastEnt[client], NextStep[client] == 7, St, Ti);
						
					}
					
					NextStep[client] = -1;
					
					LastEnt[client] = temptar;
				
				}
				
			}
		}
		else if (OPclient[client])
		{
			if (OPClientState[client] <= 0)
			{
				//ждём, пока он начнёт заряжать
				if (GetEntProp(client, Prop_Send, "m_bCharging"))
				{
					OPClientState[client] = 1; 
					
					new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
					if (((ActId>13) && (ActId<255)))
					{
						CurrActId[client] = ActId;
					}
										  
				}
				/*else
				{
					new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
					if (((ActId>13) && (ActId<255)))
					{
						CurrActId[client] = ActId;
						OPClientState[client] = 1;
					}
					 
				}*/		
			}
			else if (OPClientState[client] == 1)
			{
				//начал заряжать, ждём результат
				
				   new everythingisawesome = true;  
				   //just a flag. 
				   //if player isn't charging anymore and it is still false then we don't know why charge was bad
				   //in theory it won't be needed when all text for bad charge cases are done
				   
				   new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
				   new Tier = GetEntProp(client, Prop_Send, "m_iTierIndex");
				  
					if ((ActId>13) && (ActId<255))
						CurrActId[client] = ActId;
					
					
					//SetHudTextParams(0.2, 0.3, 2.0, 0, 255, 0, 255);
					//ShowHudText(client, 2, "ActId: %d, Delays: %3.5f, %3.5f, %3.5f", ActId, Delay[ActId][0], Delay[ActId+MAX_ACTIONS*1][0], Delay[ActId+MAX_ACTIONS*2][0]);
		
				  
				   if (!(GetEntProp(client, Prop_Send, "m_bCharging")))
				   {                   
			   // baaaadm //
			   //we don't print mistakes of master
			   //before grab-cancel he can do combo, charges, attacks, and then the grab-cancel
						//SetHudTextParams(0.2, 0.5, 2.0, 0, 255, 0, 255);
						//ShowHudText(client, 4, "ActId: %d, Tier: %d, Charging: %b",  ActId, Tier, GetEntProp(client, Prop_Send, "m_bCharging"));
						
						
						//here is all kinds of charge stopping reasons
						// 'bad' is when you need to try again (actually, now only one reason is 'good')
					   
						//feint(bad)
						if (CurrActId[client] == 3)
						{
							 everythingisawesome = BadCharge(client); 
							 //everythingisawesome is true because we know the reason why charge was bad
							 
							 //PrintToChat(client, "\x01This was \x03feint\x01! Use \x03real\x01 charges +\x03 grabs\x01 to cancel them.");
						}
					   
							
					   
					   ///grab at t2(good) t2 = halfcharge here (i think some people use t0-t1-t2 for tiers, i use t1-t2-t3) 
					   //isn't here! grabs don't change m_bCharging o_O

						///[isn't here!]grab at t1 (bad)
					   
						//[isn't here!]dash (bad)
					   
						//disconnect (bad)
					   
						//command /leave (bad)
					   
						// maybe something else is missing
						
						//attack (Good!)
						
						if (everythingisawesome) 
						{
							Attack(CurrActId[client], Tier, client);
							CurrActId[client]+=MAX_ACTIONS*Tier;
						}
						else
						{
							OPClientState[client] = 0;
						}
				   }
				   else if (ActId == 13)
				   {
						everythingisawesome = BadCharge(client);  //yay!
						
							 
						
				   }
				   else if (ActId == 12)
				   {
					   //dash:/
					   everythingisawesome = BadCharge(client);  //yay!
				   }
			  
				
			}
			else if (OPClientState[client] > 2)
			{
				
				
				new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
				new Tier = GetEntProp(client, Prop_Send, "m_iTierIndex");
				  
				/*if (CurrActId[client] != (ActId + MAX_ACTIONS*Tier))
				{
					OPClientState[client] = 0;
				}
				else*/
				{
				  
					new Float:NextCycle = Delay[CurrActId[client]][CurrDelay[client]];
					new Float:CurrTime = GetGameTime();
					//PrintToServer("--DEBUG-- NextCycle = %3.5f, CurrTime - TEST_Time_2[client] = %3.8f", NextCycle, CurrTime - TEST_Time_2[client]);
					if  (NextCycle > 0.0)
					{
						//PrintToServer("--DEBUG-- CurrTime - TEST_Time_2[client] >= NextCycle = %b", (CurrTime - TEST_Time_2[client]) >= NextCycle);
						if ((CurrTime - TEST_Time_2[client]) >= NextCycle)
						{
							//SetHudTextParams(0.2, 0.2, 2.0, 0, 255, 0, 255);
							//ShowHudText(client, 1, "Time: %3.5f", GetGameTime() - TEST_Time_2[client]);
							//SetHudTextParams(0.2, 0.3, 2.0, 0, 255, 0, 255);
							//ShowHudText(client, 2, "Delay: %3.5f, Next: %3.5f", Delay[CurrActId[client]][CurrDelay[client]], Delay[CurrActId[client]][CurrDelay[client]+1]);
							
							//PrintToServer("--DEBUG-- NextCycle = %3.5f", NextCycle);
							if (CurrDelay[client] == 0)
							{
								SpawnPoint(client, DELAY_FIRST);
							}
							else if (Delay[CurrActId[client]][CurrDelay[client] + 1] < 0.0)
							{
								SpawnPoint(client, DELAY_LAST);
								OPClientState[client] = 0;
								AmmoCounter[client]--;
								UpdateHudAmmo(client);
								if (AmmoCounter[client]<=0)
								{
									LasersOff(client);
								}
								
							}
							else
							{
								SpawnPoint(client, DELAY_MID);
							}
							CurrDelay[client] ++;
							while ((Delay[CurrActId[client]][CurrDelay[client]] <= CurrTime - TEST_Time_2[client]) && (Delay[CurrActId[client]][CurrDelay[client]+1]>0.0))
							{
								CurrDelay[client] ++;
							}
							
						}
					}
					else
					{
						OPClientState[client] = 0;
					}
				}
			}
		}
		
	}
	
	//LastDuelState = duel;
	
	//SetHudTextParams(0.2, 0.4, 2.0, 0, 255, 0, 255);
	//ShowHudText(client, 3, "OPClientState: %d", OPClientState[client]);
						
}

public Attack(ActId, Tier, client)
{
	if (IsCorrectAttack(ActId, Tier, client))
	{
	
		OPClientState[client] = 3;
		TEST_Time_2[client] = GetGameTime();
		
		
		if (Delay[ActId+MAX_ACTIONS*Tier][0] >= 0.0)
		{
			CurrDelay[client] = 0;
		}
		else
		{
			OPClientState[client] = 0;
		}
		
		//PrintToServer("--DEBUG-- Attack(client = %d, ActId = %d, Tier = %d)", client, ActId, Tier);
	}
	else 
	{
		OPClientState[client] = 0;
		CurrActId[client] = -1
	}
}

bool IsCorrectAttack(ActId, Tier, client)
{
	
	new String:St[5];
	new String:Ti[5];
	strcopy(St, 2, Ammo[client]);
	strcopy(Ti, 2, Ammo[client][1]);
	//PrintToServer("--DEBUG-- ActId = %d, Tier = %d, Ammo = %s (St=%s,Ti=%s)", ActId, Tier,Ammo[client], St, Ti);
	if ((StrEqual(Stance[ActId], St)) || (StrEqual(AMMO_STRING_ANY, St)))
	{
		if ((Tier == StringToInt(Ti)-1) || (StrEqual(AMMO_TIER_ANY, Ti)))
		{
			//PrintToServer("--DEBUG-- TRUE: ActId = %d, Tier = %d, Ammo = %s", ActId, Tier,Ammo[client]);
			return true;
		}
	}
	//PrintToServer("--DEBUG-- FALSE: ActId = %d, Tier = %d, Ammo = %s", ActId, Tier,Ammo[client]);
	return false;
}


public SpawnPoint(client, delay_pos)
{
	//PrintToServer("--DEBUG-- timer_SpawnPoint(client = %d)", client);
	
	AddCounter(client);
	//кадр первый: создаём частицы на руке и мече
	//(по таймеру)
				
				/*new temptar = CreateEntityByName("env_sprite"); 
								
				DispatchSpawn( temptar );
				AcceptEntityInput(temptar,"ShowSprite");
				ActivateEntity(temptar);*/
				
				
	tempent_E[client] = CreateEntityByName("env_sprite"); 
	tempent_S[client] = CreateEntityByName("env_sprite"); 
				
	decl Float:fPosition[3];
	GetClientAbsOrigin(client, fPosition);
				
	TeleportEntity(tempent_E[client], fPosition, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(tempent_S[client], fPosition, NULL_VECTOR, NULL_VECTOR);
				
	SetEntityModel( tempent_E[client], "materials/particle/dys_beam_big_rect.vmt" );
	SetEntityModel( tempent_S[client], "materials/particle/dys_beam_big_rect.vmt" );
	DispatchKeyValue( tempent_E[client], "renderamt", "255" );
	DispatchKeyValue( tempent_E[client], "rendercolor", "255 255 255" );
	DispatchKeyValue( tempent_S[client], "renderamt", "255" );
	DispatchKeyValue( tempent_S[client], "rendercolor", "255 255 255" );
				
	SetVariantString("!activator");
	AcceptEntityInput(tempent_S[client], "SetParent", client, tempent_S[client], 0);
	SetVariantString("anim_attachment_S");
	AcceptEntityInput(tempent_S[client], "SetParentAttachment");
	SetVariantString("!activator");
	AcceptEntityInput(tempent_E[client], "SetParent", client, tempent_E[client], 0);
	SetVariantString("anim_attachment_E");
	AcceptEntityInput(tempent_E[client], "SetParentAttachment");
				
	/*decl String:Pname[64];
	Format(Pname, sizeof(Pname), "ct_it_temp_particle_E_%d_%d", client, counter[client]);
	DispatchKeyValue(tempent_E[client], "targetname", Pname);
	DispatchKeyValue(tempent_E[client], "cpoint1", Pname);
	Format(Pname, sizeof(Pname), "ct_it_temp_particle_S_%d_%d", client, counter[client]);
	DispatchKeyValue(tempent_S[client], "targetname", Pname);
	DispatchKeyValue(tempent_S[client], "cpoint1", Pname);*/
				
	DispatchSpawn(tempent_E[client]);
	AcceptEntityInput(tempent_E[client], "ShowSprite");
	ActivateEntity(tempent_E[client]);
	DispatchSpawn(tempent_S[client]);
	AcceptEntityInput(tempent_S[client], "ShowSprite");
	ActivateEntity(tempent_S[client]);
	
	//PrintToServer("--DEBUG-- Particles Created: %d",tempent_E[client], tempent_S[client]);
	
	
				/*
	tempent_E[client] = CreateEntityByName("info_particle_system");
	tempent_S[client] = CreateEntityByName("info_particle_system");
				
	decl Float:fPosition[3];
	GetClientAbsOrigin(client, fPosition);
				
	TeleportEntity(tempent_E[client], fPosition, NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(tempent_S[client], fPosition, NULL_VECTOR, NULL_VECTOR);
				
	DispatchKeyValue(tempent_E[client], "effect_name", "sword_hearts");
	DispatchKeyValue(tempent_S[client], "effect_name", "sword_hearts");
				
	SetVariantString("!activator");
	AcceptEntityInput(tempent_S[client], "SetParent", client, tempent_S[client], 0);
	SetVariantString("anim_attachment_S");
	AcceptEntityInput(tempent_S[client], "SetParentAttachment");
	SetVariantString("!activator");
	AcceptEntityInput(tempent_E[client], "SetParent", client, tempent_E[client], 0);
	SetVariantString("anim_attachment_E");
	AcceptEntityInput(tempent_E[client], "SetParentAttachment");
				
	decl String:Pname[64];
	Format(Pname, sizeof(Pname), "ct_it_temp_particle_E_%d_%d", client, counter[client]);
	DispatchKeyValue(tempent_E[client], "targetname", Pname);
	DispatchKeyValue(tempent_E[client], "cpoint1", Pname);
	Format(Pname, sizeof(Pname), "ct_it_temp_particle_S_%d_%d", client, counter[client]);
	DispatchKeyValue(tempent_S[client], "targetname", Pname);
	DispatchKeyValue(tempent_S[client], "cpoint1", Pname);
				
	DispatchSpawn(tempent_E[client]);
	ActivateEntity(tempent_E[client]);
	AcceptEntityInput(tempent_E[client], "Start");
	DispatchSpawn(tempent_S[client]);
	ActivateEntity(tempent_S[client]);
	AcceptEntityInput(tempent_S[client], "Start");
	//PrintToServer("--DEBUG-- Particles Created: %d",tempent_E[client], tempent_S[client]);
				*/
				
				
	if (delay_pos == DELAY_FIRST)
	{
		NextStep[client] = 2;
	}
	else if (delay_pos == DELAY_LAST)
	{
		NextStep[client] = 6;
	}
	else
	{
		NextStep[client] = 4;
	}
	
	
	if (delay_pos == DELAY_LAST)
	{
		//PrintToServer("--DEBUG-- timer_SpawnPoint(client = %d) LAST ONE !!!", client);
	}
	
}

bool BadCharge(client)
{
	OPClientState[client] = 0;
    CurrActId[client] = -1
	
	return false;
}

/*
 * REMOVE PARTICLE ENT NOW
 * 
 * @param particle        Ent to remove.
 */
RemoveEntityNow(any:entity)
{
	if (entity > 32)
		if(IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "Deactivate");
			AcceptEntityInput(entity, "Kill");
		}
}

/*
public Action:OnBeamTouch(beam, ent)
{
	PrintToServer("Touch! beam = %d, ent = %d", beam, ent);
}
*/

AddVert(owner, entity, Float:pos_s[3], Float:pos_e[3], beament, beamtar, bool:last, const String:St[], const String:Ti[])
{
	if (Vert_Exists[VertCounter])
	{
		PrintToServer("ERROR!!! Need bigger VMAX!!!");
	}
	else
	{
		Vert_Ent[VertCounter] = entity;
		Vert_E[VertCounter][0] = pos_e[0];
		Vert_E[VertCounter][1] = pos_e[1];
		Vert_E[VertCounter][2] = pos_e[2];
		Vert_Pos[VertCounter][0] = pos_e[0];
		Vert_Pos[VertCounter][1] = pos_e[1];
		Vert_Pos[VertCounter][2] = pos_e[2];
		Vert_Vector_N[VertCounter][0] = Vert_E[VertCounter][0] - pos_s[0];
		Vert_Vector_N[VertCounter][1] = Vert_E[VertCounter][1] - pos_s[1];
		Vert_Vector_N[VertCounter][2] = Vert_E[VertCounter][2] - pos_s[2];
		//PrintToServer("--DEBUG-- Vert[%d] Vector = ( %3.3f, %3.3f, %3.3f )", VertCounter, Vert_Vector_N[VertCounter][0], Vert_Vector_N[VertCounter][1], Vert_Vector_N[VertCounter][2]);
		new Float:L = SquareRoot(Vert_Vector_N[VertCounter][0]*Vert_Vector_N[VertCounter][0] + Vert_Vector_N[VertCounter][1]*Vert_Vector_N[VertCounter][1] + Vert_Vector_N[VertCounter][2]*Vert_Vector_N[VertCounter][2]);
		Vert_Vector_N[VertCounter][0] = Vert_Vector_N[VertCounter][0]/L;
		Vert_Vector_N[VertCounter][1] = Vert_Vector_N[VertCounter][1]/L;
		Vert_Vector_N[VertCounter][2] = Vert_Vector_N[VertCounter][2]/L;
		//PrintToServer("--DEBUG-- Vert[%d] Vector_L = %3.3f", VertCounter, L);
		//PrintToServer("--DEBUG-- Vert[%d] Vector_N = ( %3.3f, %3.3f, %3.3f )", VertCounter, Vert_Vector_N[VertCounter][0], Vert_Vector_N[VertCounter][1], Vert_Vector_N[VertCounter][2]);
		Vert_Speed[VertCounter] = GetConVarFloat(g_speed);
		Vert_MaxDist[VertCounter] = 1000.0;
		Vert_Owner[VertCounter] = owner;
		Vert_Beam[VertCounter] = beament;
		Vert_BeamTarget[VertCounter] = beamtar;
		Vert_Last[VertCounter] = last;
		//PrintToServer("--DEBUG-- Vert[%d] E = ( %3.3f, %3.3f, %3.3f )", VertCounter, Vert_E[VertCounter][0], Vert_E[VertCounter][1], Vert_E[VertCounter][2]);
		//PrintToServer("--DEBUG-- Vert[%d] S = ( %3.3f, %3.3f, %3.3f )", VertCounter, pos_s[0], pos_s[1], pos_s[2]);
		strcopy(Vert_St[VertCounter], sizeof(Vert_St[]), St);
		strcopy(Vert_Ti[VertCounter], sizeof(Vert_Ti[]), Ti);
		
		Vert_Exists[VertCounter] = true;
		
		VertCounter++;
		if (VertCounter>=VMAX)
			for (new i = 0; i < VMAX; i++)
				if (!Vert_Exists[i])
				{
					VertCounter = i;
					break;
				}
		
	}
}

RemoveVert(i)
{
	Vert_Exists[i] = false;
	
	
	//SDKUnhook(Vert_Beam[i], SDKHook_Touch, OnBeamTouch);
	RemoveEntityNow(Vert_Beam[i]);
	RemoveEntityNow(Vert_BeamTarget[i]);
	
	if (Vert_Last[i])
	{
		RemoveEntityNowRemoveEntityNow(Vert_Ent[i]);
	}
}

//draw-and-forget
DrawBeam(Float:PointFrom[3], Float:PointTo[3])
{
	new tar = CreateEntityByName("env_sprite"); 
    SetEntityModel( tar, "materials/particle/dys_beam_big_rect.vmt" );
    DispatchKeyValue( tar, "renderamt", "255" );
    DispatchKeyValue( tar, "rendercolor", "255 255 255" ); 
    DispatchSpawn( tar );
    AcceptEntityInput(tar,"ShowSprite");
    ActivateEntity(tar);
    TeleportEntity( tar, PointFrom, NULL_VECTOR, NULL_VECTOR );
	
	new beam = CreateEntityByName( "env_beam" );
	SetEntityModel( beam, "materials/particle/dys_beam_big_rect.vmt" );
					
					DispatchKeyValue( beam, "rendermode", "0" );
					
					/*new String:colour[16];
					new String:alpha[5];
					Format(alpha, sizeof(alpha), "%d", A);
					DispatchKeyValue( beam, "renderamt", alpha );
					Format(colour, sizeof(colour), "%d %d %d", R, G, B);
					DispatchKeyValue( beam, "rendercolor", colour );  
					DispatchKeyValue( beam, "life", "0" ); */
					
					DispatchKeyValue( beam, "renderamt", "100" );
					DispatchKeyValue( beam, "rendermode", "0" );
					DispatchKeyValue( beam, "rendercolor", "0 0 255" );  
					DispatchKeyValue( beam, "life", "0" ); 
					
					TeleportEntity( beam, PointTo, NULL_VECTOR, NULL_VECTOR ); 
					
					DispatchSpawn(beam);
					SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beam) );
					SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(tar), 1 );
					SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
					SetEntProp( beam, Prop_Send, "m_nBeamType", 2);
					
					SetEntPropFloat( beam, Prop_Data, "m_fWidth",  1.0 );
					SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", 1.0 );
					ActivateEntity(beam);
					AcceptEntityInput(beam,"TurnOn");
					
	
}

InitPowerUpBeam(PowerUpI)
{
	new String:St[5];
	new String:Ti[5];
	strcopy(St, 2, PowerUp_AmmoType[PowerUpI]);
	strcopy(Ti, 2, PowerUp_AmmoType[PowerUpI][1]);
	
	for (new i = 0; i < POWERUP_MAXBEAMS; i++)
		PowerUp_Beam[PowerUpI][i] = -1;	
	
	for (new i = 0; i < 5; i++)
	{
		new tar = CreateEntityByName("env_sprite"); 
		SetEntityModel( tar, "materials/particle/dys_beam3.vmt" );
		DispatchKeyValue( tar, "renderamt", "255" );
		DispatchKeyValue( tar, "rendercolor", "255 255 255" ); 
		DispatchSpawn( tar );
		AcceptEntityInput(tar,"ShowSprite");
		ActivateEntity(tar);
		TeleportEntity( tar, PowerUp_Pos[PowerUpI], NULL_VECTOR, NULL_VECTOR );
		PowerUp_BeamTarget[PowerUpI][i] = tar;
		
		new beam = CreateEntityByName( "env_beam" );
		SetEntityModel( beam, "materials/particle/dys_beam3.vmt" );
						
		DispatchKeyValue( beam, "rendermode", "0" );
		
		
		/*new String:colour[16];
		new String:alpha[5];
		Format(alpha, sizeof(alpha), "%d", A);
		DispatchKeyValue( beam, "renderamt", alpha );
		Format(colour, sizeof(colour), "%d %d %d", R, G, B);
		DispatchKeyValue( beam, "rendercolor", colour );  
		DispatchKeyValue( beam, "life", "0" ); */
		
		//DispatchKeyValue( beam, "framerate", "20" );
		//DispatchKeyValue( beam, "TextureScroll", "35" );
		
		DispatchKeyValue( beam, "renderamt", "100" );
		DispatchKeyValue( beam, "rendermode", "0" );
		
		if (PowerUp_AmmoCount[PowerUpI] <= i)
		{
			DispatchKeyValue( beam, "rendercolor", "0 0 0" ); 
		}
		else
		{
			if (StrEqual(St, AMMO_STRING_A))
			{
				DispatchKeyValue( beam, "rendercolor", "255 255 0" ); 
			}
			else if (StrEqual(St, AMMO_STRING_F))
			{
				DispatchKeyValue( beam, "rendercolor", "0 255 75" ); 
			}
			else if (StrEqual(St, AMMO_STRING_B))
			{
				DispatchKeyValue( beam, "rendercolor", "0 0 255" ); 
			}
			else if (StrEqual(St, AMMO_STRING_H))
			{
				DispatchKeyValue( beam, "rendercolor", "255 0 0" ); 
			}
			else //any
			{
				DispatchKeyValue( beam, "rendercolor", "255 255 255" ); 
			} 
		}
		DispatchKeyValue( beam, "life", "0" ); 
					
		TeleportEntity( beam, PowerUp_Pos[PowerUpI], NULL_VECTOR, NULL_VECTOR ); 
			
		DispatchSpawn(beam);
		SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beam) );
		SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(tar), 1 );
		SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
		SetEntProp( beam, Prop_Send, "m_nBeamType", 2);
					
		SetEntPropFloat( beam, Prop_Data, "m_fWidth",  6.0 );
		SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", 6.0 );
		ActivateEntity(beam);
		AcceptEntityInput(beam,"TurnOn");
		
		PowerUp_Beam[PowerUpI][i] = beam;
		
		
		//PrintToServer("Spawned tar %d and beam %d", PowerUp_BeamTarget[PowerUpI][i], PowerUp_Beam[PowerUpI][i]);
		//PrintToServer("for PU %d (PUC =  %d)", PowerUpI, PowerUpCounter+1);
	}			
	
}

bool:IsInDuel(client)
{
	
	if(!IsClientInGame(client))
	{
		return false;
	}
	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
	{
		return true;
	}
	
	return false;
}

float Dist(Float:A[3], Float:B[3])
{
	return SquareRoot( (A[0] - B[0])*(A[0] - B[0]) + (A[1] - B[1])*(A[1] - B[1]) + (A[2] - B[2])*(A[2] - B[2]));
}

public Action:timer_SpawnPowerUp(Handle:timer)
{
	
	if (PowerUpCounter < POWERUP_MAX)
	{
		new String:Ti[3];
		//Format(Ti, sizeof(Ti), "%d", GetRandomInt(1, 3));
		Format(Ti, sizeof(Ti), "%d", 0);
		
		new String:St[3];
		if ( (PowerUp_HighPointCount > 0) && (GetRandomFloat(0.0, 1.0) < 0.14) )
		{
			strcopy(St, sizeof(St), AMMO_STRING_ANY);
				
			SpawnPowerUp(PowerUp_HighPoint[GetRandomInt(0, PowerUp_HighPointCount-1)], St, Ti, GetRandomInt(3, 5));
		}
		else
		{
			switch (GetRandomInt(1, 4))
			{
				case 1:
				{
					strcopy(St, sizeof(St), AMMO_STRING_A);
				}
				case 2:
				{
					strcopy(St, sizeof(St), AMMO_STRING_F);
				}
				case 3:
				{
					strcopy(St, sizeof(St), AMMO_STRING_B);
				}
				case 4:
				{
					strcopy(St, sizeof(St), AMMO_STRING_H);
				}
				
			}
			
			SpawnPowerUp(PowerUp_Point[GetRandomInt(0, PowerUp_PointCount-1)], St, Ti, GetRandomInt(3, 5));
		}
		
		
	}
	
	CreateTimer( GetRandomFloat(POWERUP_RESPTIME_MIN, POWERUP_RESPTIME_MAX) , timer_SpawnPowerUp );
}

SpawnPowerUp(Float:Point[3], const String:St[], const String:Ti[], AmmoCount)
{
	//PrintToServer("SpawnPowerUp, %s, %s, %d", St, Ti, AmmoCount);
	
	PowerUp_Pos[PowerUpCounter][0] = Point[0] + GetRandomFloat(-50.0, 50.0);
	PowerUp_Pos[PowerUpCounter][1] = Point[1] + GetRandomFloat(-50.0, 50.0);
	PowerUp_Pos[PowerUpCounter][2] = Point[2];
	
	Format(PowerUp_AmmoType[PowerUpCounter], sizeof(PowerUp_AmmoType[]), "%s%s", St, Ti);
	PowerUp_AmmoCount[PowerUpCounter] = AmmoCount;
		
	InitPowerUpBeam(PowerUpCounter);
	
	PowerUp_Life[PowerUpCounter] = 0.0;
	PowerUpCounter++;
	
}

RemovePowerUp(PowerUpI)
{
	new String:Ti[3];
	strcopy(Ti, 2, PowerUp_AmmoType[PowerUpI][1]);
	
	for (new i=0; i < POWERUP_MAXBEAMS; i++)
	{
		RemoveEntityNow(PowerUp_Beam[PowerUpI][i]);
		RemoveEntityNow(PowerUp_BeamTarget[PowerUpI][i]);
	}
	
	if (PowerUpI < PowerUpCounter-1)
	{
		for (new i = PowerUpI; i < PowerUpCounter-1; i++)
		{
			PowerUp_AmmoCount[i] = PowerUp_AmmoCount[i+1];
			strcopy(PowerUp_AmmoType[i], sizeof(PowerUp_AmmoType[]), PowerUp_AmmoType[i+1]);
			PowerUp_Pos[i][0] = PowerUp_Pos[i+1][0];
			PowerUp_Pos[i][1] = PowerUp_Pos[i+1][1];
			PowerUp_Pos[i][2] = PowerUp_Pos[i+1][2];
			
			for (new j = 0; j < POWERUP_MAXBEAMS; j++)
			{
				PowerUp_Beam[i][j] = PowerUp_Beam[i+1][j];
				PowerUp_BeamTarget[i][j] = PowerUp_BeamTarget[i+1][j];
			}
			
			PowerUp_Life[i] = PowerUp_Life[i+1];
			
		}
	}
	
	PowerUpCounter--;
}

InitPowerUpPoints()
{
	PowerUp_PointCount = 0;
	PowerUp_HighPointCount = 0;
	
	new String:MapName[64];
	GetCurrentMap(MapName, sizeof(MapName));
	
	if (StrEqual("free_district", MapName, false))
	{
		PowerUp_Point[PowerUp_PointCount][0] = -292.650024;
		PowerUp_Point[PowerUp_PointCount][1] = -415.511658;
		PowerUp_Point[PowerUp_PointCount][2] = 538.531250;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -1092.537720;
		PowerUp_Point[PowerUp_PointCount][1] = -263.403625;
		PowerUp_Point[PowerUp_PointCount][2] = -119.968750;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 427.687775;
		PowerUp_Point[PowerUp_PointCount][1] = -379.381134;
		PowerUp_Point[PowerUp_PointCount][2] = 0.031250;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -193.479111;
		PowerUp_Point[PowerUp_PointCount][1] = 422.562592;
		PowerUp_Point[PowerUp_PointCount][2] = 293.596252;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -649.519653;
		PowerUp_Point[PowerUp_PointCount][1] = -52.011387;
		PowerUp_Point[PowerUp_PointCount][2] = 572.031250;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -1237.210083;
		PowerUp_Point[PowerUp_PointCount][1] = -756.017212;
		PowerUp_Point[PowerUp_PointCount][2] = 560.031250;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 237.119766;
		PowerUp_Point[PowerUp_PointCount][1] = 257.720551;
		PowerUp_Point[PowerUp_PointCount][2] = 723.449402;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 430.286804;
		PowerUp_Point[PowerUp_PointCount][1] = -615.598145;
		PowerUp_Point[PowerUp_PointCount][2] = 398.618469;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -657.985168;
		PowerUp_Point[PowerUp_PointCount][1] = 105.819847;
		PowerUp_Point[PowerUp_PointCount][2] = -7.968750;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 719.804443;
		PowerUp_Point[PowerUp_PointCount][1] = 293.301971;
		PowerUp_Point[PowerUp_PointCount][2] = -7.968750;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 226.829269;
		PowerUp_Point[PowerUp_PointCount][1] = 989.952087;
		PowerUp_Point[PowerUp_PointCount][2] = -7.968750;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = -399.553528;
		PowerUp_Point[PowerUp_PointCount][1] = 106.227859;
		PowerUp_Point[PowerUp_PointCount][2] = 160.031250;
		PowerUp_PointCount++;
		
		PowerUp_Point[PowerUp_PointCount][0] = 269.014313;
		PowerUp_Point[PowerUp_PointCount][1] = 485.407196;
		PowerUp_Point[PowerUp_PointCount][2] = 105.031250;
		PowerUp_PointCount++;
				
		// High:
		PowerUp_HighPoint[PowerUp_HighPointCount][0] = 197.469818;
		PowerUp_HighPoint[PowerUp_HighPointCount][1] = 982.047302;
		PowerUp_HighPoint[PowerUp_HighPointCount][2] = 704.031250;
		PowerUp_HighPointCount++;
		
		PowerUp_HighPoint[PowerUp_HighPointCount][0] = -2510.192871;
		PowerUp_HighPoint[PowerUp_HighPointCount][1] = -190.673401;
		PowerUp_HighPoint[PowerUp_HighPointCount][2] = 1360.031250;
		PowerUp_HighPointCount++;
		
		PowerUp_HighPoint[PowerUp_HighPointCount][0] = 373.532684;
		PowerUp_HighPoint[PowerUp_HighPointCount][1] = -568.749023;
		PowerUp_HighPoint[PowerUp_HighPointCount][2] = 1280.031250;
		PowerUp_HighPointCount++;
		
	}
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//		 Init Delays Array
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SetActId(ActId, Float:AnimTime, const String:ActStance[])
{
	ActId_Init = ActId;
	Delay_Init = 0;
	ActId_AnimTime = AnimTime;
	
	if (ActId<255)
	{
		strcopy(Stance[ActId], sizeof(Stance[]), ActStance);
	}
}

SetChar(const String:Character[])
{
	Format(Act_Char, sizeof(Act_Char), "%s", Character);
}

AddDelay(Float:cycle)
{
	Delay[ActId_Init][Delay_Init] = cycle*ActId_AnimTime;	
	
	Delay_Init++;
}

public Action:command_test(client, args)
{
	if (args>1)
	{
		new String:arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		new String:arg2[32];
		GetCmdArg(2, arg2, sizeof(arg2));
		
		SetHudTextParams(StringToFloat(arg1) ,StringToFloat(arg2) , 1000.0 , 255 ,0 ,0 ,255);
		ShowHudText(client, 1, "---");
	}
}

public Action:command_givelaser(client, args)
{
	
	if (args>2)
	{
		new String:arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		new String:arg2[32];
		GetCmdArg(2, arg2, sizeof(arg2));
		new String:arg3[32];
		GetCmdArg(3, arg3, sizeof(arg3));
		
		LasersOn(StringToInt(arg1), arg2, StringToInt(arg3));
	}
	else if (args>1)
	{
		new String:arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		new String:arg2[32];
		GetCmdArg(2, arg2, sizeof(arg2));
		
		LasersOn(client, arg1, StringToInt(arg2));
	}
	else if (args>0)
	{
		new String:arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		
		LasersOn(client, arg1, 1);
	}
	else
	{
		LasersOn(client, "00", 1);
	}
}

bool LoadCycles(const String:AttackKV[])
{
	new Handle:kv = CreateKeyValues("tracers");
	new String:FileName[256];
	Format(FileName, sizeof(FileName), "%s%s%s%s%s", "scripts/characters/", Act_Char, "/tracers/", AttackKV, ".bst");
	//PrintToServer("File <%s> Exists = <%b>", FileName, FileExists(FileName, true));
	if (!FileExists(FileName))
	{
		PrintToServer("Error Loading Action %s", AttackKV);
		return false;
	}
	FileToKeyValues(kv, FileName);
	
	KvJumpToKey(kv, Act_Char);
	KvGotoFirstSubKey(kv);// goto "phalanx" -> attackname -> "trace"
	KvGotoFirstSubKey(kv);
	
	new Float:prev = 0.0;
	new cycleCount = 0;
	do
	{
			
		new Float:cycle = KvGetFloat(kv, "cycle");
		if (cycle>prev)
		{
			AddDelay(cycle);
			
				//if (StrEqual("act_bb_r_left_t1", AttackKV, false))
				//{
				//	PrintToServer("char = %s, cycle = %f, Delay = %f, Anim_Time = %f", Act_Char, cycle, Delay[ActId_Init][Delay_Init-1], ActId_AnimTime);
				//}
				
			prev = cycle;
			cycleCount++;
		}
			
	} while (KvGotoNextKey(kv));
		
	CloseHandle(kv);
	return true;
}


InitDelays()
{
	for (new i = 0; i< MAX_ACTIONS*3; i++)
		for (new j = 0; j< MAX_DELAYS; j++)
		{
			Delay[i][j] = -1.0;
		}
		
	/////////////////
	//             //
	//-- PHALANX --//air = 62
	//             //
	/////////////////
	SetChar("phalanx");
	{
		
		//AL
		{
			SetActId(64 + MAX_ACTIONS*0, 30.0/52.0, "A");	
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(64 + MAX_ACTIONS*1, 30.0/52.0, "A");
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(64 + MAX_ACTIONS*2, 30.0/52.0, "A");	
			LoadCycles("act_bb_a_left_t1");
		}
		//AR
		{
			SetActId(65 + MAX_ACTIONS*0, 30.0/52.0, "A");	
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(65 + MAX_ACTIONS*1, 30.0/52.0, "A");
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(65 + MAX_ACTIONS*2, 30.0/52.0, "A");	
			LoadCycles("act_bb_a_right_t1");
		}
		//A1
		{
			SetActId(62 + MAX_ACTIONS*0, 22.0/30.0, "A");	
			LoadCycles("act_bb_a_c1_t1");
			
			SetActId(62 + MAX_ACTIONS*1, 22.0/30.0, "A");
			LoadCycles("act_bb_a_c1_t1");
			
			SetActId(62 + MAX_ACTIONS*2, 22.0/30.0, "A");	
			LoadCycles("act_bb_a_c1_t1");
		}
		
		//FL
		{
			SetActId(54 + MAX_ACTIONS*0, 21.0/40.0, "F");	
			LoadCycles("act_bb_r_left_t1");
			
			SetActId(54 + MAX_ACTIONS*1, 35.0/40.0, "F");
			LoadCycles("act_bb_r_left_t2");
			
			SetActId(54 + MAX_ACTIONS*2, 45.0/40.0, "F");	
			LoadCycles("act_bb_r_left_t3");
		}
			
		//FR
		{
			SetActId(55 + MAX_ACTIONS*0, 22.0/40.0, "F");	
			LoadCycles("act_bb_r_right_t1");
			
			SetActId(55 + MAX_ACTIONS*1, 35.0/40.0, "F");		
			LoadCycles("act_bb_r_right_t2");
			
			SetActId(55 + MAX_ACTIONS*2, 45.0/40.0, "F");	
			LoadCycles("act_bb_r_right_t3");
		}
			
		//F1
		{
			SetActId(50 + MAX_ACTIONS*0, 27.0/40.0, "F");	
			LoadCycles("act_bb_r_c1_t1");
			
			SetActId(50 + MAX_ACTIONS*1, 30.0/40.0, "F");
			LoadCycles("act_bb_r_c1_t2");
			
			SetActId(50 + MAX_ACTIONS*2, 30.0/40.0, "F");	
			LoadCycles("act_bb_r_c1_t3");
		}
			
		//F2
		{
			SetActId(51 + MAX_ACTIONS*0, 60.0/40.0, "F");	
			LoadCycles("act_bb_r_c2_t1");
			
			SetActId(51 + MAX_ACTIONS*1, 60.0/40.0, "F");
			LoadCycles("act_bb_r_c2_t2");
			
			SetActId(51 + MAX_ACTIONS*2, 55.0/40.0, "F");	
			LoadCycles("act_bb_r_c2_t3");
		}
			
		//F3
		{
			SetActId(52 + MAX_ACTIONS*0, 80.0/33.0, "F");	
			LoadCycles("act_bb_r_c3_t1");
			
			SetActId(52 + MAX_ACTIONS*1, 60.0/45.0, "F");
			LoadCycles("act_bb_r_c3_t2");
			
			SetActId(52 + MAX_ACTIONS*2, 30.0/35.0, "F");	
			LoadCycles("act_bb_r_c3_t3");
		}
			
		//F4
		{
			SetActId(53 + MAX_ACTIONS*0, 46.0/40.0, "F");	
			LoadCycles("act_bb_r_c4_t1");
			
			SetActId(53 + MAX_ACTIONS*1, 56.0/40.0, "F");
			LoadCycles("act_bb_r_c4_t2");
			
			SetActId(53 + MAX_ACTIONS*2, 73.0/40.0, "F");	
			LoadCycles("act_bb_r_c4_t3");
		}
		
		//BL
		{
			SetActId(47 + MAX_ACTIONS*0, 30.0/26.0, "B");	
			LoadCycles("act_bb_b_left_t1");
			
			SetActId(47 + MAX_ACTIONS*1, 22.0/22.0, "B");
			LoadCycles("act_bb_b_left_t2");
			
			SetActId(47 + MAX_ACTIONS*2, 70.0/70.0, "B");	
			LoadCycles("act_bb_b_left_t3");
		}
			
		//BR
		{
			SetActId(48 + MAX_ACTIONS*0, 36.0/23.0, "B");	
			LoadCycles("act_bb_b_right_t1");
			
			SetActId(48 + MAX_ACTIONS*1, 55.0/45.0, "B");		
			LoadCycles("act_bb_b_right_t2");
			
			SetActId(48 + MAX_ACTIONS*2, 70.0/70.0, "B");	
			LoadCycles("act_bb_b_right_t3");
		}
			
		//B1
		{
			SetActId(43 + MAX_ACTIONS*0, 44.0/28.0, "B");	
			LoadCycles("act_bb_b_c1_t1");
			
			SetActId(43 + MAX_ACTIONS*1, 44.0/28.0, "B");
			LoadCycles("act_bb_b_c1_t1");
			
			SetActId(43 + MAX_ACTIONS*2, 70.0/45.0, "B");	
			LoadCycles("act_bb_b_c1_t3");
		}
		//B2
		{
			SetActId(44 + MAX_ACTIONS*0, 60.0/36.0, "B");	
			LoadCycles("act_bb_b_c2_t1");
			
			SetActId(44 + MAX_ACTIONS*1, 45.0/38.0, "B");
			LoadCycles("act_bb_b_c2_t2");
			
			SetActId(44 + MAX_ACTIONS*2, 60.0/40.0, "B");	
			LoadCycles("act_bb_b_c2_t3");
		}
		//B3
		{
			SetActId(45 + MAX_ACTIONS*0, 72.0/60.0, "B");	
			LoadCycles("act_bb_b_c4_t1");
			
			SetActId(45 + MAX_ACTIONS*1, 72.0/60.0, "B");
			LoadCycles("act_bb_b_c4_t1");
			
			SetActId(45 + MAX_ACTIONS*2, 85.0/70.0, "B");	
			LoadCycles("act_bb_b_c4_t3");
		}
		
		//HL
		{
			SetActId(59 + MAX_ACTIONS*0, 45.0/30.0, "H");	
			LoadCycles("act_bb_h_left_t1");
			
			SetActId(59 + MAX_ACTIONS*1, 60.0/15.0, "H");
			LoadCycles("act_bb_h_left_t2");
			
			SetActId(59 + MAX_ACTIONS*2, 75.0/20.0, "H");	
			LoadCycles("act_bb_h_left_t3");
		}
			
		//HR
		{
			SetActId(60 + MAX_ACTIONS*0, 80.0/50.0, "H");	
			LoadCycles("act_bb_h_right_t1");
			
			SetActId(60 + MAX_ACTIONS*1, 60.0/15.0, "H");		
			LoadCycles("act_bb_h_right_t2");
			
			SetActId(60 + MAX_ACTIONS*2, 75.0/20.0, "H");	
			LoadCycles("act_bb_h_right_t3");
		}
			
		//H1
		{
			SetActId(57 + MAX_ACTIONS*0, 88.0/60.0, "H");	
			LoadCycles("act_bb_h_c1_t1");
			
			SetActId(57 + MAX_ACTIONS*1, 52.0/70.0, "H");
			LoadCycles("act_bb_h_c1_t2");
			
			SetActId(57 + MAX_ACTIONS*2, 87.0/50.0, "H");	
			LoadCycles("act_bb_h_c1_t3");
		}
			
	}
	//////////////
	//          //
	//-- PURE --//
	//          //
	//////////////
	SetChar("pure");
	{
		//AL
		{
			SetActId(130 + MAX_ACTIONS*0, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(130 + MAX_ACTIONS*1, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(130 + MAX_ACTIONS*2, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_left_t1");
		}
		//AR
		{
			SetActId(131 + MAX_ACTIONS*0, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(131 + MAX_ACTIONS*1, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(131 + MAX_ACTIONS*2, 48.0/55.0, "A");		
			LoadCycles("act_bb_a_right_t1");
		}
		//A1
		{
			SetActId(129 + MAX_ACTIONS*0, 48.0/60.0, "A");		
			LoadCycles("act_bb_a_c1_t1");
			
			SetActId(129 + MAX_ACTIONS*1, 48.0/60.0, "A");		
			LoadCycles("act_bb_a_c1_t1");
			
			SetActId(129 + MAX_ACTIONS*2, 48.0/60.0, "A");		
			LoadCycles("act_bb_a_c1_t1");
		}
		
		//FL
		{
			SetActId(121 + MAX_ACTIONS*0, 105.0/80.0, "F");		
			LoadCycles("act_bb_r_left_t1");
			
			SetActId(121 + MAX_ACTIONS*1, 77.0/60.0, "F");		
			LoadCycles("act_bb_r_left_t2");
			
			SetActId(121 + MAX_ACTIONS*2, 81.0/60.0, "F");		
			LoadCycles("act_bb_r_left_t3");
		}
		//FR
		{
			SetActId(122 + MAX_ACTIONS*0, 19.0/38.0, "F");		
			LoadCycles("act_bb_r_right_t2");
			
			SetActId(122 + MAX_ACTIONS*1, 28.0/38.0, "F");		
			LoadCycles("act_bb_r_right_t1");
			
			SetActId(122 + MAX_ACTIONS*2, 81.0/70.0, "F");		
			LoadCycles("act_bb_r_right_t3");
		}
		//F1
		{
			SetActId(118 + MAX_ACTIONS*0, 77.0/54.0, "F");		
			LoadCycles("act_bb_r_c1_t1");
			
			SetActId(118 + MAX_ACTIONS*1, 77.0/54.0, "F");		
			LoadCycles("act_bb_r_c1_t2");
			
			SetActId(118 + MAX_ACTIONS*2, 72.0/60.0, "F");		
			LoadCycles("act_bb_r_c3_t1");
		}
		//F2
		{
			SetActId(119 + MAX_ACTIONS*0, 67.0/60.0, "F");		
			LoadCycles("act_bb_r_c2_t1");
			
			SetActId(119 + MAX_ACTIONS*1, 75.0/60.0, "F");		
			LoadCycles("act_bb_r_c2_t3");
			
			SetActId(119 + MAX_ACTIONS*2, 65.0/60.0, "F");		
			LoadCycles("act_bb_r_c2_t2");
		}
		//F3
		{
			SetActId(120 + MAX_ACTIONS*0, 75.0/60.0, "F");		
			LoadCycles("act_bb_r_c3_t2");
			
			SetActId(120 + MAX_ACTIONS*1, 90.0/60.0, "F");		
			LoadCycles("act_bb_r_c3_t3");
			
			SetActId(120 + MAX_ACTIONS*2, 75.0/60.0, "F");		
			LoadCycles("act_bb_r_c3_t2");
		}
		
		
		
		//BL
		{
			SetActId(115 + MAX_ACTIONS*0, 36.0/32.0, "B");		
			LoadCycles("act_bb_b_left_t1");
			
			SetActId(115 + MAX_ACTIONS*1, 30.0/60.0, "B");		
			LoadCycles("act_bb_b_left_t2");
			
			SetActId(115 + MAX_ACTIONS*2, 50.0/60.0, "B");		
			LoadCycles("act_bb_b_left_t3");
		}
		
		//BR
		{
			SetActId(116 + MAX_ACTIONS*0, 78.0/58.0, "B");
			//SetActId(116 + MAX_ACTIONS*0, 1.4);			
			LoadCycles("act_bb_b_right_t1");
			
			SetActId(116 + MAX_ACTIONS*1, 78.0/48.0, "B");
			//SetActId(116 + MAX_ACTIONS*1, 1.4);			
			LoadCycles("act_bb_b_right_t2");
			
			SetActId(116 + MAX_ACTIONS*2, 130.0/60.0, "B");
			//SetActId(116 + MAX_ACTIONS*2, 1.8);			
			LoadCycles("act_bb_b_right_t3");
		}
		
		//B1
		{
			SetActId(112 + MAX_ACTIONS*0, 60.0/60.0, "B");		
			LoadCycles("act_bb_b_c1_t1");
			
			SetActId(112 + MAX_ACTIONS*1, 70.0/60.0, "B");		
			LoadCycles("act_bb_b_c1_t3");
			
			SetActId(112 + MAX_ACTIONS*2, 91.0/60.0, "B");		
			LoadCycles("act_bb_b_c1_t2");
		}
		//B2
		{
			SetActId(113 + MAX_ACTIONS*0, 60.0/50.0, "B");		
			LoadCycles("act_bb_b_c2_t1");
			
			SetActId(113 + MAX_ACTIONS*1, 60.0/34.0, "B");		
			LoadCycles("act_bb_b_c2_t2");
			
			SetActId(113 + MAX_ACTIONS*2, 110.0/60.0, "B");		
			LoadCycles("act_bb_b_c2_t3");
		}
		//B3
		{
			SetActId(114 + MAX_ACTIONS*0, 100.0/70.0, "B");		
			LoadCycles("act_bb_b_c3_t1");
			
			SetActId(114 + MAX_ACTIONS*1, 100.0/55.0, "B");		
			LoadCycles("act_bb_b_c3_t2");
			
			SetActId(114 + MAX_ACTIONS*2, 120.0/60.0, "B");		
			LoadCycles("act_bb_b_c3_t3");
		}
			
		//HL
		{
			SetActId(126 + MAX_ACTIONS*0, 96.0/60.0, "H");		
			LoadCycles("act_bb_h_left_t1");
			
			SetActId(126 + MAX_ACTIONS*1, 160.0/60.0, "H");		
			LoadCycles("act_bb_h_left_t2");
			
			SetActId(126 + MAX_ACTIONS*2, 70.0/30.0, "H");		
			LoadCycles("act_bb_h_left_t3");
		}
		//HR
		{
			SetActId(127 + MAX_ACTIONS*0, 86.0/65.0, "H");		
			LoadCycles("act_bb_h_right_t1");
			
			SetActId(127 + MAX_ACTIONS*1, 118.0/65.0, "H");		
			LoadCycles("act_bb_h_right_t2");
			
			SetActId(127 + MAX_ACTIONS*2, 125.0/30.0, "H");		
			LoadCycles("act_bb_h_right_t3");
		}
		//H1
		{
			SetActId(124 + MAX_ACTIONS*0, 89.0/60.0, "H");		
			LoadCycles("act_bb_h_c1_t1");
			
			SetActId(124 + MAX_ACTIONS*1, 143.0/60.0, "H");		
			LoadCycles("act_bb_h_c1_t2");
			
			SetActId(124 + MAX_ACTIONS*2, 60.0/30.0, "H");		
			LoadCycles("act_bb_h_c1_t3");
		}
		//H2
		{
			SetActId(125 + MAX_ACTIONS*0, 63.0/60.0, "H");		
			LoadCycles("act_bb_h_c2_t1");
			
			SetActId(125 + MAX_ACTIONS*1, 136.0/60.0, "H");		
			LoadCycles("act_bb_h_c2_t2");
			
			SetActId(125 + MAX_ACTIONS*2, 45.0/30.0, "H");		
			LoadCycles("act_bb_h_c2_t3");
		}
	}
	///////////////
	//           //
	//-- JUDGE --//
	//           //
	///////////////
	SetChar("knight");
	{
		//AL
		{
			SetActId(86 + MAX_ACTIONS*0, 24.0/24.0, "A");		
			if (!LoadCycles("act_bb_a_left_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(86 + MAX_ACTIONS*1, 24.0/24.0, "A");		
			if (!LoadCycles("act_bb_a_left_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(86 + MAX_ACTIONS*2, 24.0/24.0, "A");		
			if (!LoadCycles("act_bb_a_left_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//AR
		{
			SetActId(87 + MAX_ACTIONS*0, 16.0/16.0, "A");		
			if (!LoadCycles("act_bb_a_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(87 + MAX_ACTIONS*1, 16.0/16.0, "A");		
			if (!LoadCycles("act_bb_a_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(87 + MAX_ACTIONS*2, 16.0/16.0, "A");		
			if (!LoadCycles("act_bb_a_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		//A1
		{
			SetActId(85 + MAX_ACTIONS*0, 16.0/30.0, "A");		
			if (!LoadCycles("act_bb_a_c1_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(85 + MAX_ACTIONS*1, 30.0/40.0, "A");		
			if (!LoadCycles("act_bb_a_c1_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(85 + MAX_ACTIONS*2, 30.0/30.0, "A");		
			if (!LoadCycles("act_bb_a_c1_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//FL
		{
			SetActId(70 + MAX_ACTIONS*0, 50.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_left_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(70 + MAX_ACTIONS*1, 45.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_left_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(70 + MAX_ACTIONS*2, 59.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_left_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//FR
		{
			SetActId(71 + MAX_ACTIONS*0, 35.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(71 + MAX_ACTIONS*1, 39.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_right_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(71 + MAX_ACTIONS*2, 40.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_right_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		//F1
		{
			SetActId(67 + MAX_ACTIONS*0, 18.0/20.0, "F");		
			if (!LoadCycles("act_bb_r_c1_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(67 + MAX_ACTIONS*1, 30.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_c1_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(67 + MAX_ACTIONS*2, 45.0/40.0, "F");		
			if (!LoadCycles("act_bb_r_c1_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//F2
		{
			SetActId(68 + MAX_ACTIONS*0, 18.0/19.0, "F");		
			if (!LoadCycles("act_bb_r_c2_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(68 + MAX_ACTIONS*1, 36.0/37.0, "F");		
			if (!LoadCycles("act_bb_r_c2_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(68 + MAX_ACTIONS*2, 46.0/33.0, "F");		
			if (!LoadCycles("act_bb_r_c2_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//F3
		{
			SetActId(69 + MAX_ACTIONS*0, 38.0/30.0, "F");			
			if (!LoadCycles("act_bb_r_c3_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(69 + MAX_ACTIONS*1, 39.0/20.0, "F");			
			if (!LoadCycles("act_bb_r_c3_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(69 + MAX_ACTIONS*2, 60.0/35.0, "F");			
			if (!LoadCycles("act_bb_r_c3_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//BL
		{
			SetActId(76 + MAX_ACTIONS*0, 27.0/25.0, "B");	
			if (!LoadCycles("act_bb_b_left_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(76 + MAX_ACTIONS*1, 60.0/40.0, "B");	
			if (!LoadCycles("act_bb_b_left_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(76 + MAX_ACTIONS*2, 80.0/30.0, "B");	
			if (!LoadCycles("act_bb_b_left_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//BR
		{
			SetActId(77 + MAX_ACTIONS*0, 50.0/32.0, "B");		
			if (!LoadCycles("act_bb_b_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(77 + MAX_ACTIONS*1, 60.0/44.0, "B");	
			if (!LoadCycles("act_bb_b_right_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(77 + MAX_ACTIONS*2, 85.0/33.0, "B");	
			if (!LoadCycles("act_bb_b_right_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//B1
		{
			SetActId(73 + MAX_ACTIONS*0, 45.0/38.0, "B");		
			if (!LoadCycles("act_bb_b_c1_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(73 + MAX_ACTIONS*1, 55.0/58.0, "B");		
			if (!LoadCycles("act_bb_b_c1_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(73 + MAX_ACTIONS*2, 75.0/40.0, "B");		
			if (!LoadCycles("act_bb_b_c1_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//B2
		{
			SetActId(74 + MAX_ACTIONS*0, 48.0/45.0, "B");	
			if (!LoadCycles("act_bb_b_c2_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(74 + MAX_ACTIONS*1, 65.0/44.0, "B");		
			if (!LoadCycles("act_bb_b_c2_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(74 + MAX_ACTIONS*2, 75.0/48.0, "B");		
			if (!LoadCycles("act_bb_b_c2_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//B3
		{
			SetActId(75 + MAX_ACTIONS*0, 56.0/40.0, "B");	
			if (!LoadCycles("act_bb_b_c3_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(75 + MAX_ACTIONS*1, 64.0/45.0, "B");	
			if (!LoadCycles("act_bb_b_c3_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(75 + MAX_ACTIONS*2, 90.0/45.0, "B");		
			if (!LoadCycles("act_bb_b_c3_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//HL
		{
			SetActId(82 + MAX_ACTIONS*0, 100.0/58.0, "H");		
			if (!LoadCycles("act_bb_h_left_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(82 + MAX_ACTIONS*1, 100.0/58.0, "H");		
			if (!LoadCycles("act_bb_h_left_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(82+ MAX_ACTIONS*2, 180.0/76.0, "H");		
			if (!LoadCycles("act_bb_h_left_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//HR
		{
			SetActId(83 + MAX_ACTIONS*0, 50.0/20.0, "H");		
			if (!LoadCycles("act_bb_h_right_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(83 + MAX_ACTIONS*1, 120.0/60.0, "H");		
			if (!LoadCycles("act_bb_h_right_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(83 + MAX_ACTIONS*2, 180.0/60.0, "H");		
			if (!LoadCycles("act_bb_h_right_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		//H1
		{
			SetActId(79 + MAX_ACTIONS*0, 80.0/58.0, "H");		
			if (!LoadCycles("act_bb_h_c1_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(79 + MAX_ACTIONS*1, 100.0/58.0, "H");		
			if (!LoadCycles("act_bb_h_c1_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(79 + MAX_ACTIONS*2, 100.0/58.0, "H");		
			if (!LoadCycles("act_bb_h_c1_t3"))
				PrintToServer("Error Loading Action %d", ActId_Init);
		}
		
		//H2
		{
			SetActId(80 + MAX_ACTIONS*0, 100.0/45.0, "H");		
			LoadCycles("act_bb_h_c2_t1");
			
			SetActId(80 + MAX_ACTIONS*1, 100.0/50.0, "H");		
			LoadCycles("act_bb_h_c2_t2");
			
			SetActId(80 + MAX_ACTIONS*2, 100.0/58.0, "H");		
			LoadCycles("act_bb_h_c2_t3");
		}
		
		//H3
		{
			SetActId(81 + MAX_ACTIONS*0, 100.0/58.0, "H");			
			if (!LoadCycles("act_bb_h_c3_t1"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(81 + MAX_ACTIONS*1, 100.0/58.0, "H");			
			if (!LoadCycles("act_bb_h_c3_t2"))
				PrintToServer("Error Loading Action %d", ActId_Init);
			
			SetActId(81 + MAX_ACTIONS*2, 120.0/58.0, "H");		
			LoadCycles("act_bb_h_c3_t3");
		}
		
	}
	
	///////////////
	//           //
	//-- RYOKU --//
	//           //
	///////////////
	SetChar("ryoku");
	{
		//AL
		{
			SetActId(109 + MAX_ACTIONS*0, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(109 + MAX_ACTIONS*1, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(109 + MAX_ACTIONS*2, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_left_t1");
		}
		//AR
		{
			SetActId(110 + MAX_ACTIONS*0, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(110 + MAX_ACTIONS*1, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(110 + MAX_ACTIONS*2, 60.0/60.0, "A");		
			LoadCycles("act_bb_a_right_t1");
		}
		//A1
		{
			SetActId(108 + MAX_ACTIONS*0, 32.0/30.0, "A");	
			LoadCycles("act_bb_a_c2_t1");
			
			SetActId(108 + MAX_ACTIONS*1, 40.0/60.0, "A");
			LoadCycles("act_bb_a_c2_t1");
			
			SetActId(108 + MAX_ACTIONS*2, 40.0/70.0, "A");
			LoadCycles("act_bb_a_c2_t1");
		}
		
		//FL
		{
			SetActId(95 + MAX_ACTIONS*0, 24.0/24.0, "F");		
			LoadCycles("act_bb_r_left_t1");
			
			SetActId(95 + MAX_ACTIONS*1, 40.0/40.0, "F");		
			LoadCycles("act_bb_r_left_t2");
			
			SetActId(95 + MAX_ACTIONS*2, 20.0/24.0, "F");		
			LoadCycles("act_bb_r_left_t3");
		}
		//FR
		{
			SetActId(96 + MAX_ACTIONS*0, 26.0/20.0, "F");		
			LoadCycles("act_bb_r_right_t1");
			
			SetActId(96 + MAX_ACTIONS*1, 36.0/30.0, "F");		
			LoadCycles("act_bb_r_right_t2");
			
			SetActId(96 + MAX_ACTIONS*2, 22.0/15.0, "F");		
			LoadCycles("act_bb_r_right_t3");
		}
		//F1
		{
			SetActId(89 + MAX_ACTIONS*0, 40.0/30.0, "F");	
			LoadCycles("act_bb_r_c1_t1");
			
			SetActId(89 + MAX_ACTIONS*1, 40.0/60.0, "F");
			LoadCycles("act_bb_r_c1_t2");
			
			SetActId(89 + MAX_ACTIONS*2, 40.0/70.0, "F");
			LoadCycles("act_bb_r_c1_t3");
		}
		//F2
		{
			SetActId(90 + MAX_ACTIONS*0, 40.0/44.0, "F");	
			LoadCycles("act_bb_r_c2_t1");
			
			SetActId(90 + MAX_ACTIONS*1, 40.0/50.0, "F");
			LoadCycles("act_bb_r_c2_t2");
			
			SetActId(90 + MAX_ACTIONS*2, 50.0/45.0, "F");	
			LoadCycles("act_bb_r_c2_t3");
		}
		//F3
		{
			SetActId(91 + MAX_ACTIONS*0, 48.0/45.0, "F");	
			LoadCycles("act_bb_r_c3_t1");
			
			SetActId(91 + MAX_ACTIONS*1, 50.0/60.0, "F");
			LoadCycles("act_bb_r_c3_t2");
			
			SetActId(91 + MAX_ACTIONS*2, 60.0/50.0, "F");	
			LoadCycles("act_bb_r_c3_t3");
		}
		//F4
		{
			SetActId(92 + MAX_ACTIONS*0, 60.0/65.0, "F");	
			LoadCycles("act_bb_r_c4_t3");
			
			SetActId(92 + MAX_ACTIONS*1, 40.0/40.0, "F");
			LoadCycles("act_bb_r_c4_t2");
			
			SetActId(92 + MAX_ACTIONS*2, 57.0/40.0, "F");	
			LoadCycles("act_bb_r_c4_t1");
		}
		//F5
		{
			SetActId(93 + MAX_ACTIONS*0, 44.0/44.0, "F");	
			LoadCycles("act_bb_r_c5_t1");
			
			SetActId(93 + MAX_ACTIONS*1, 24.0/40.0, "F");
			LoadCycles("act_bb_r_c5_t2");
			
			SetActId(93 + MAX_ACTIONS*2, 48.0/50.0, "F");	
			LoadCycles("act_bb_r_c5_t3");
		}
		//F6
		{
			SetActId(94 + MAX_ACTIONS*0, 80.0/30.0, "F");	
			LoadCycles("act_bb_r_c6_t1");
			
			SetActId(94 + MAX_ACTIONS*1, 60.0/40.0, "F");
			LoadCycles("act_bb_r_c6_t2");
			
			SetActId(94 + MAX_ACTIONS*2, 80.0/50.0, "F");
			LoadCycles("act_bb_r_c6_t3");
		}
		
		//BL
		{
			SetActId(101 + MAX_ACTIONS*0, 280.0/170.0, "B");		
			LoadCycles("act_bb_b_left_t1");
			
			SetActId(101 + MAX_ACTIONS*1, 170.0/200.0, "B");		
			LoadCycles("act_bb_b_left_t2");
			
			SetActId(101 + MAX_ACTIONS*2, 42.0/26.0, "B");		
			LoadCycles("act_bb_b_left_t3");
		}
		//BR
		{
			SetActId(102 + MAX_ACTIONS*0, 42.0/40.0, "B");		
			LoadCycles("act_bb_b_right_t2");
			
			SetActId(102 + MAX_ACTIONS*1, 75.0/36.0, "B");		
			LoadCycles("act_bb_b_right_t1");
			
			SetActId(102 + MAX_ACTIONS*2, 80.0/32.0, "B");		
			LoadCycles("act_bb_b_right_t3");
		}
		//B1
		{
			SetActId(98 + MAX_ACTIONS*0, 30.0/26.0, "B");	
			LoadCycles("act_bb_b_c1_t1");
			
			SetActId(98 + MAX_ACTIONS*1, 30.0/26.0, "B");
			LoadCycles("act_bb_b_c1_t2");
			
			SetActId(98 + MAX_ACTIONS*2, 45.0/26.0, "B");
			LoadCycles("act_bb_b_c1_t3");
		}
		//B2
		{
			SetActId(99 + MAX_ACTIONS*0, 27.0/20.0, "B");	
			LoadCycles("act_bb_b_c2_t1");
			
			SetActId(99 + MAX_ACTIONS*1, 25.0/24.0, "B");
			LoadCycles("act_bb_b_c2_t2");
			
			SetActId(99 + MAX_ACTIONS*2, 65.0/58.0, "B");
			LoadCycles("act_bb_b_c2_t3");
		}
		
		//HL
		{
			SetActId(106 + MAX_ACTIONS*0, 32.0/22.0, "H");		
			LoadCycles("act_bb_h_left_t1");
			
			SetActId(106 + MAX_ACTIONS*1, 23.0/20.0, "H");		
			LoadCycles("act_bb_h_left_t2");
			
			SetActId(106 + MAX_ACTIONS*2, 35.0/19.0, "H");		
			LoadCycles("act_bb_h_left_t3");
		}
		//HR
		{
			SetActId(105 + MAX_ACTIONS*0, 30.0/22.0, "H");		
			LoadCycles("act_bb_h_right_t1");
			
			SetActId(105 + MAX_ACTIONS*1, 28.0/24.0, "H");		
			LoadCycles("act_bb_h_right_t2");
			
			SetActId(105 + MAX_ACTIONS*2, 45.0/22.0, "H");		
			LoadCycles("act_bb_h_right_t3");
		}
		//H1
		{
			SetActId(104 + MAX_ACTIONS*0, 30.0/20.0, "H");	
			LoadCycles("act_bb_h_c1_t1");
			
			SetActId(104 + MAX_ACTIONS*1, 24.0/24.0, "H");
			LoadCycles("act_bb_h_c1_t2");
			
			SetActId(104 + MAX_ACTIONS*2, 30.0/20.0, "H");
			LoadCycles("act_bb_h_c1_t1");
		}
	}
	//////////////////
	//              //
	//-- VANGUARD --//   <151, 152>
	//              //
	//////////////////
	SetChar("vanguard");
	{
		//AL
		{
			SetActId(151 + MAX_ACTIONS*0, 20.0/30.0, "A");
			LoadCycles("act_bb_a_left_t1");
			
			SetActId(151 + MAX_ACTIONS*1, 20.0/30.0, "A");			
			LoadCycles("act_bb_a_left_t1");
		
			SetActId(151 + MAX_ACTIONS*2, 20.0/30.0, "A");		
			LoadCycles("act_bb_a_left_t1");
		}
		//AR
		{
			SetActId(152 + MAX_ACTIONS*0, 30.0/30.0, "A");
			LoadCycles("act_bb_a_right_t1");
			
			SetActId(152 + MAX_ACTIONS*1, 30.0/30.0, "A");			
			LoadCycles("act_bb_a_right_t1");
		
			SetActId(152 + MAX_ACTIONS*2, 30.0/30.0, "A");		
			LoadCycles("act_bb_a_right_t1");
		}
		//A1
		{
			SetActId(150 + MAX_ACTIONS*0, 20.0/30.0, "A");
			LoadCycles("act_bb_a_c1_t1");
			
			SetActId(150 + MAX_ACTIONS*1, 20.0/30.0, "A");			
			LoadCycles("act_bb_a_c1_t1");
		
			SetActId(150 + MAX_ACTIONS*2, 20.0/30.0, "A");		
			LoadCycles("act_bb_a_c1_t1");
		}
		
		//FL
		{
			SetActId(143 + MAX_ACTIONS*0, 20.0/30.0, "F");
			LoadCycles("act_bb_r_left_t1");
			
			SetActId(143 + MAX_ACTIONS*1, 10.0/30.0, "F");			
			LoadCycles("act_bb_r_left_t2");
		
			SetActId(143 + MAX_ACTIONS*2, 20.0/30.0, "F");		
			LoadCycles("act_bb_r_left_t3");
		}
		//FR
		{
			SetActId(144 + MAX_ACTIONS*0, 20.0/30.0, "F");
			LoadCycles("act_bb_r_right_t1");
			
			SetActId(144 + MAX_ACTIONS*1, 20.0/30.0, "F");			
			LoadCycles("act_bb_r_right_t2");
		
			SetActId(144 + MAX_ACTIONS*2, 20.0/30.0, "F");		
			LoadCycles("act_bb_r_right_t3");
		}
		//F1
		{
			SetActId(140 + MAX_ACTIONS*0, 20.0/30.0, "F");
			LoadCycles("act_bb_r_c1_t1");
			
			SetActId(140 + MAX_ACTIONS*1, 20.0/30.0, "F");			
			LoadCycles("act_bb_r_c1_t2");
		
			SetActId(140 + MAX_ACTIONS*2, 20.0/30.0, "F");		
			LoadCycles("act_bb_r_c1_t3");
		}
		//F2
		{
			SetActId(141 + MAX_ACTIONS*0, 20.0/30.0, "F");
			LoadCycles("act_bb_r_c2_t1");
			
			SetActId(141 + MAX_ACTIONS*1, 20.0/30.0, "F");			
			LoadCycles("act_bb_r_c2_t2");
		
			SetActId(141 + MAX_ACTIONS*2, 20.0/30.0, "F");		
			LoadCycles("act_bb_r_c2_t3");
		}
		//F3
		{
			SetActId(142 + MAX_ACTIONS*0, 30.0/30.0, "F");
			LoadCycles("act_bb_r_c3_t1");
			
			SetActId(142 + MAX_ACTIONS*1, 30.0/30.0, "F");			
			LoadCycles("act_bb_r_c3_t2");
		
			SetActId(142 + MAX_ACTIONS*2, 30.0/30.0, "F");		
			LoadCycles("act_bb_r_c3_t3");
		}
		
		//BL
		{
			SetActId(137 + MAX_ACTIONS*0, 18.0/30.0, "B");
			LoadCycles("act_bb_b_left_t1");
			
			SetActId(137 + MAX_ACTIONS*1, 19.0/30.0, "B");			
			LoadCycles("act_bb_b_left_t2");
		
			SetActId(137 + MAX_ACTIONS*2, 30.0/20.0, "B");		
			LoadCycles("act_bb_b_left_t3");
		}
		//BR
		{
			SetActId(138 + MAX_ACTIONS*0, 25.0/30.0, "B");
			LoadCycles("act_bb_b_right_t1");
			
			SetActId(138 + MAX_ACTIONS*1, 35.0/30.0, "B");			
			LoadCycles("act_bb_b_right_t2");
		
			SetActId(138 + MAX_ACTIONS*2, 25.0/30.0, "B");		
			LoadCycles("act_bb_b_right_t3");
		}
		//B1
		{
			SetActId(133 + MAX_ACTIONS*0, 25.0/30.0, "B");
			LoadCycles("act_bb_b_c4_t2");
			
			SetActId(133 + MAX_ACTIONS*1, 40.0/30.0, "B");			
			LoadCycles("act_bb_b_c3_t2");
		
			SetActId(133 + MAX_ACTIONS*2, 35.0/30.0, "B");		
			LoadCycles("act_bb_b_c3_t3");
		}
		//B2
		{
			SetActId(134 + MAX_ACTIONS*0, 20.0/30.0, "B");
			LoadCycles("act_bb_b_c4_t1");
			
			SetActId(134 + MAX_ACTIONS*1, 40.0/30.0, "B");			
			LoadCycles("act_bb_b_c3_t1");
		
			SetActId(134 + MAX_ACTIONS*2, 50.0/30.0, "B");		
			LoadCycles("act_bb_h_c1_t1");
		}
		//B3
		{
			SetActId(135 + MAX_ACTIONS*0, 30.0/30.0, "B");
			LoadCycles("act_bb_b_c1_t1");
			
			SetActId(135 + MAX_ACTIONS*1, 30.0/30.0, "B");			
			LoadCycles("act_bb_b_c1_t2");
		
			SetActId(135 + MAX_ACTIONS*2, 35.0/30.0, "B");		
			LoadCycles("act_bb_b_c1_t3");
		}
		//B4
		{
			SetActId(136 + MAX_ACTIONS*0, 40.0/30.0, "B");
			LoadCycles("act_bb_b_c2_t2");
			
			SetActId(136 + MAX_ACTIONS*1, 40.0/30.0, "B");			
			LoadCycles("act_bb_b_c2_t2");
		
			SetActId(136 + MAX_ACTIONS*2, 49.0/30.0, "B");		
			LoadCycles("act_bb_b_c2_t3");
		}
		
		//HL
		{
			SetActId(147 + MAX_ACTIONS*0, 40.0/30.0, "H");
			LoadCycles("act_bb_h_left_t1");
			
			SetActId(147 + MAX_ACTIONS*1, 30.0/30.0, "H");			
			LoadCycles("act_bb_h_left_t2");
		
			SetActId(147 + MAX_ACTIONS*2, 30.0/30.0, "H");		
			LoadCycles("act_bb_h_left_t3");
		}
		//HR
		{
			SetActId(148 + MAX_ACTIONS*0, 36.0/30.0, "H");
			LoadCycles("act_bb_h_right_t1");
			
			SetActId(148 + MAX_ACTIONS*1, 60.0/30.0, "H");			
			LoadCycles("act_bb_h_right_t2");
		
			SetActId(148 + MAX_ACTIONS*2, 40.0/30.0, "H");		
			LoadCycles("act_bb_h_right_t3");
		}
		//H1
		{
			SetActId(146 + MAX_ACTIONS*0, 50.0/30.0, "H");
			LoadCycles("act_bb_b_c4_t3");
			
			SetActId(146 + MAX_ACTIONS*1, 50.0/30.0, "H");			
			LoadCycles("act_bb_h_c1_t3");
		
			SetActId(146 + MAX_ACTIONS*2, 50.0/30.0, "H");		
			LoadCycles("act_bb_h_c1_t2");
		}
	}
}

public Action:OnClientCommand(client, args)
{
	if (false)
		return Plugin_Continue;
	
	// выключаем дуэли - лагают
	new String:command[15];
	GetCmdArg(0, command, 15);
	
	if (StrEqual(command, "vs_challenge", false))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
