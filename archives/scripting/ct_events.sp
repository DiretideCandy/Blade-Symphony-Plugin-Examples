/** [TODO: Gamemodes]

[high][unknown][no skeleton] 							FFA
[low][unknown][no skeleton] 							Battle Chess
[low][unknown][no skeleton] 							Doom Bridge
[low][unknown][no skeleton] 							Machine
[very very low][unknown][no skeleton] 					Weakest Link (1 hp? class restrictions?)

[low][unknown][no skeleton] 							 ^ Auto-Events for these ^

[test][][][]											TDM
*/

/** next  High Priority Features:

[]	/event join menu for players
[]	captain's player picking menu

*/


/** [TODO: new features]

[reason/status][priority:high][difficulty:easy][test result]
[need skeleton of event to work][high]		[easy]		[]Do not forget to add sounds!! (Fight! Round One! Round Two! Final Round!)
[no skeleton][low]							[unknown]	[]move loading configs from file to another file. It is possible!
[no skeleton][low]							[unknown]	[]Add these new (not in /ge plugin) params to event in MapConfig:
[no skeleton][low]							[unknown]	[]		leave arena timer (kick immediately by default)
[no skeleton][low]							[unknown]	[]		block commands section for players (block /tele)
[no skeleton][low]							[unknown]	[]		global anti-shuri (0 - goes to roundEntities, 1 - goes to eventEntities. default is 0)
[no skeleton][low]							[unknown]	[]		also, option to disable anti-shuri? this means shuris from spectators! (which won't do damage but can interrupt jumps
[no skeleton][low]							[unknown]	[]		round limit
[no skeleton][low]							[unknown]	[]		round limit alternatives: bo3, bo5, something else
[no skeleton][low]							[unknown]	[]		time limit
[no skeleton][low]							[unknown]	[]		"Max players for one team" limit
[no skeleton][low]							[unknown]	[]		default: set hp to 100, heal. options: don't heal/heal to current max hp without changing
[no skeleton][low]							[unknown]	[]		teleport spawns out of spectator area (needs destination point)
[no skeleton][lowest]						[unknown]	[]		?class restrictions?
[no skeleton][lowest]						[unknown]	[]		round end condition: captain's death
[no skeleton][lowest]						[unknown]	[]		Spawns: add phi angle for "teams" spawns (0 180 degrees -> 90 270, etc)
[lazy][optional]							[unknown]	[]Add optional Z limits to Circle areas 
[done?][][stays in test section]						[]Visualize Event Locations with lasers!
[lazy][low]									[unknown]	[]Add not-oriented points? (link type)


[too lazy][low][impossibiru]							[]rename variables to our standard
[no idea how to][low][impossibiru]						[]fix tag mismaches with index passing (switch-case?! no way!)
[lazy][optional][easy]									[]don't teleport many players to one point.
[no skeleton][high][easy]								[]Block damage to players on picking phase (== outside of rounds)
[no skeleton][low][unknown]								[]Swap command for switching player's team number (admin only)
[no skeleton][low][unknown]								[]Invitation menu for players in spectator area (only at event start)
[lazy][low][easy]										[]Remove int activator = -1 where it is not used
[no skeleton][medium][unknown]							[]OnDeath event: 	if player dies before round starts ==> wait for spawn
[no skeleton][medium][unknown]							[]OnDeath event: 	if player is out but still IsInEvent ==> respawn at TeleOut pos
[no skeleton][low][unknown]								[]command for admin: /restartround (should work only if everyone alive)
[no skeleton][low][unknown]								[]vs_challenge block (see Elmo's bchess)
[no skeleton][low][unknown]								[]Spawn particle effects
[no skeleton][low][unknown]								[]change from spawning triggers and beams every round to turning them off between rounds
[no skeleton][low][unknown]								[]somehow make roundlimit and matchpoints for teamcount > 2
[no skeleton][low][unknown]								[]make mixed spawn random
[no skeleton][low][unknown]								[]


*/

/** [TESTING]
[status:done][result: 32.0 should be ok]				find minimum comfortable teleporting distance for two players
[not a test][keep in mind]								changed hook placement a little, care
[][]													wrote the ffa's default StartTP but didn't test it
[fixed][]												border lasers don't remove
[][]													teleportingOnStart teleports Howl to TeleOut
[removed for now]										[Event] Player has left event area - what is it for???
[test][]												don't change color when it is right
[][]													test duel button blocks
[][]													EndTouch_MainArea called when someone connects to server?! wtf?!
[][]													sometimes /test init 0 says invalid event index?
														
														
	
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <bsstocks.inc>

#define PLUGIN_PREFIX "\x03[Event]\x01"

public Plugin myinfo = 
{
	name = "Auto-Events",
	author = "Crystal",
	description = "/events command and settings",
	version = "1.0",
	url = ""
};

//////////////////////////////////
//								//
//		Consts 					//
//								//
//////////////////////////////////

#define PI 3.1415926535897932384626433832795

// public events: everyone can start them
#define MAXPUBLICEVENTS 8
// custom events: only for admins
#define MAXCUSTOMEVENTS 8

// max size of EventParamChar strings
#define MAXSTRINGSIZE 48

// max entities for one event (trigger brushes, laserbeams, props?, particle effects, ... )
#define MAXEVENTENTITIES 128	// these removed only when event ends
#define MAXROUNDENTITIES 128	// these only last for one round

// default menu time. somehow is not float
#define MENU_DURATION 20

// indexes for g_eventConfig
enum EventConfig
{
	//basic
	Nothing,				// for optional arguments
	String:sName[MAXSTRINGSIZE],
	EventType:Type,
			//IsAvailable,			// == 0 if errors detected
    IsPublic,				// 0 - only admins can start, 1 - anyone can start
	//default locations
    MainArena_shape,		// 0 - rect, 1 - circle
	Float:vecMainArena_pos[3],
	Float:vecMainArena_size[3],
	Float:fMainArena_radius,
	Float:vecSpawn_pos[3],
	Float:fSpawn_radius,
	Float:vecTeleOut_pos[3],
	Float:vecTeleOut_dir[3],
	Float:vecSpectatorArea_pos[3],
	Float:vecSpectatorArea_size[3],
	
	//specific locations 
	
	// data
	FriendlyFire,
	Teams,
	StartTP,
	RespawnTele,
	RespawnTeleTeams,
	HasBorder,
	Float:fBorderHeight,
	RoundLimit,
	MinimumPlayers,
	
	COUNT
}

//indexes for g_playerData
enum PlayerData
{
	IsInSpectatorArea = 0, // go to spectator area < join event (== join queue) < join team (or join team zero for ffa) (==IsInEvent)
	IsInQueue,
	IsInEvent,
	IsOut, // for example: player died in tdm. he still IsInEvent, but IsOut. Waiting for next round.
	Team,
	
	String:sSavedColor[MAXSTRINGSIZE],
	
	COUNT
}

enum EventState
{
	NoEvent = 0,
	Picking,
	Started,
	
	COUNT
}
// indexes for g_eventTypeName
enum EventType
{
	TDM = 0,
	FFA,
	COUNT
};

// indexes for area/point requirements
enum EventLocation
{
	// for every event
	MainArena = 0,
	Spawn,
	TeleOut,
	SpectatorArea,
	BASIC, //separator
	//special
	// ...to be continued...
	COUNT //should be named LAST, but ok
};

// color names for g_color[] array
enum TeamColor
{
	Red = 0,
	Blue,
	Green,
	Yellow,
	Purple,
	Teal,
	Orange,
	White,	// should do Gorm's Black here!
	
	COUNT
}

// current autotimer waiting reason
enum AutoTimer
{
	NONE,
	EnoughInQueue,
	
	COUNT
}

// waiting timers for autoevents
enum Wait
{
	Float:EnoughInQueue = 60.0,
	
	COUNT
}


//////////////////////////
//						//
//	More "Consts"		//
//						//
//////////////////////////
// basic event types
char g_eventTypeName[EventType:COUNT][] = {
	"tdm",
	"ffa"
}

// default names for "links". 
//for example: TDM main area will be "tdm_arena" == (g_eventTypeName[EventType:TDM] + "_" + g_eventBasicLocationName[EventLocation:MainArena])
// "tdm" section VS "tdm_" prefix? "tdm_" prefix, because it is easier to link this by multiple custom events (but maybe harder for default events?)
char g_eventBasicLocationName[EventLocation:BASIC][] = {
	"arena",		
	"spawn",
	"teleout",
	"spectator_area"
}
// colors for teams (should match g_teamName[] strings)
char g_color[TeamColor:COUNT][] = {
	"1 0 0",
	"0 0 1",
	"0 1 0",
	"1 1 0",
	"1 0 1",
	"0 1 1",
	"1 0.5 0",
	"1 1 1"	
}
char g_teamName[TeamColor:COUNT][] = {
	"Red Team",
	"Blue Team",
	"Green Team",
	"Yellow Team",
	"Purple Team",
	"Teal Team",
	"Orange Team",
	"White Team"
}

char g_sFightSound[] = "common/announcer/fight.wav";
char g_sRoundSound[][] = {
	"common/announcer/round1.wav",
	"common/announcer/round2.wav",
	"common/announcer/round3.wav",
	"common/announcer/round4.wav",
	"common/announcer/round5.wav",
	"common/announcer/round6.wav",
	"common/announcer/round7.wav",
	"common/announcer/round8.wav",
	"common/announcer/finalround.wav" 
}

//////////////////////////
//						//
//	Loaded Events Data	//
//						//
//////////////////////////

// event counter
int g_event_count;

// params, loaded from settings text file (only changed at MapStart)
new g_eventConfig[ MAXPUBLICEVENTS + MAXCUSTOMEVENTS ][ EventConfig ];

// map is correct if at least one event found
bool g_bMapIsCorrect;

//////////////////////////
//						//
//		Global Vars		//
//						//
//////////////////////////

// player data
new g_playerData[ MAXPLAYERS + 1 ][ PlayerData ];

// current event (event index for EventConfig data)
int g_event; 		

// event's current phase
//int g_eventState;	// damn, this var always gets useless

// event's round counter
int g_eventRound;

// event's current phase (will use g_eventState if bool will be to small)
bool g_bRoundStarted;

// entities for event (remembering them to remove after event)
int g_eventEntity[MAXEVENTENTITIES];
int g_eventEntity_count;
// eventEntity removed only when event ends.
// roundEntity removed when each round ends
int g_roundEntity[MAXEVENTENTITIES];
int g_roundEntity_count;

// player queue. people who joined event but waiting for round (or pickng) to end
int g_queue[MAXPLAYERS];
int g_queue_count;

// player counter for round end conditions
int g_team_counter[TeamColor:COUNT];

// sheduled teleportation (-1 if none, 0 if TeleOut, others are for team spawns)
int g_teleQueue[MAXPLAYERS + 1];

// :( 
// global var for passing values between menus? really?
int g_temp_client[MAXPLAYERS + 1]; 

// Score for each team (how it will work for ffa?)
int g_eventScore[TeamColor:COUNT];

// Automatic event is a sequence of timers. 
// Current timer for auto-events (I can't into KillTimer and such things, so I'll track them manually)
int g_autotimer;

// Id for timers so we can confirm we still waiting for this timer (id is not random)
int g_autotimerId;

//
AutoTimer:g_autotimerType;

//////////////////////////
//						//
//		Convars			//
//						//
//////////////////////////

// must do them at least in this plugin ...


//////////////////////////
//						//
//		Debug, etc		//
//						//
//////////////////////////
//int debug_admin;
int testafk;

//////////////////////////////
//							//
//		Initialization		//
//							//
//////////////////////////////

public OnPluginStart() 
{	
	HookEvent("player_death", PlayerDeathEvent);
	
	
	
	//RegAdminCmd("sm_show_loc", DrawLocations, ADMFLAG_RCON, "temp command for showing MapConfig areas");
	//RegAdminCmd("sm_test", testtest, ADMFLAG_RCON, "testtesttest");
	RegConsoleCmd("sm_show_loc", DrawLocations);
	RegConsoleCmd("sm_test", testtest);
	
	RegConsoleCmd("sm_event", EventCmd, "Main menu for events");
	RegConsoleCmd("sm_events", EventCmd, "Main menu for events"); // just in case
	
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		// color: init here because ResetClient is just for restoring it
		strcopy(g_playerData[client][sSavedColor], MAXSTRINGSIZE, "-");
	}
	//convars
	
	// prepare sounds
	// default sounds, no need to add to downloads table
	PrecacheSound(g_sFightSound,true);
	for (int i = 0; i < sizeof(g_sRoundSound); i++)
		PrecacheSound(g_sRoundSound[i],true);

}

public OnPluginEnd()
{
	ResetEvent(); // should remove entities and restore player colors
}

public OnMapStart()
{
	LoadResources();
	
	g_bMapIsCorrect = LoadMap();
	
	if (g_bMapIsCorrect)
	{
		ResetEvent();
		for (int i = 1; i <= MaxClients; i++)
			g_playerData[i][IsInSpectatorArea] = 0;
			
	}
}

LoadResources()
{
	// Laser Texture  
	PrecacheModel("materials/particle/dys_beam_big_rect.vmt");
	
	
}
ResetEvent()
{
	g_queue_count = 0; ///! for safety reasons. will change for autoevents
	
	g_event = -1;
	g_eventRound = 0;
	g_bRoundStarted = false;
	ResetAutoTimer();
	RemoveAllRoundEntities();
	RemoveAllEventEntities();
	for (int team = 0; team < _:TeamColor:COUNT; team++)
	{
		g_eventScore[team] = 0;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		
		g_playerData[i][IsInQueue] = 0;
		ResetClient(i);
	}
	
}

ResetAutoTimer()
{
	// technically, timers are still there, but we don't care, they will know they are not needed anymore
	// this is not right, but I can't do it another way
	g_autotimer = 0;
	g_autotimerId = 0;
	g_autotimerType = AutoTimer:NONE;
}

ResetClient(int client)
{
	if (g_playerData[client][IsInQueue])
		RemovePlayerFromQueue(client);
	
	//g_playerData[client][IsInSpectatorArea] = -1; 
	if (g_playerData[client][IsInEvent] > 0)
	{
		g_playerData[client][IsInEvent] = 0;
		g_playerData[client][IsOut] = 0;
		RestoreColor(client);
		g_playerData[client][Team] = 0;
	
		g_teleQueue[client] = -1;
		SDKUnhook(client, SDKHook_SpawnPost, OnSpawn);
	}
}

public OnClientDisconnect(client)
{
	
	// if event is going ==> damage tracking everyone
	if (g_event >= 0)
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if (g_bRoundStarted)
		PlayerOut(client);
	
	ResetClient(client);
	
	// check if this was last player in event
	bool last = true;
	for (int i = 1; i <= MaxClients; i++)
		if (g_playerData[i][IsInEvent])
		{
			last = false;
			break;
		}
		
	if (last && g_queue_count == 0 && (g_bRoundStarted && g_eventRound > 0)) 
	{
		PrintToSpectators("Last player left. Aborting the event");
		ResetEvent();
	}
	
	///! if it was admin ==> end event
	///!if (g_eventBlock == client)
	///!	ResetEvent();
}

public OnClientConnected(int client)
{
	// if event is going ==> damage tracking everyone
	if (g_event >= 0)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

//////////////////////////////
//							//
//		Main				//
//							//
//////////////////////////////

public Action EventCmd(int client, int args)
{
	// if event started: join or spectate
	if (g_event >= 0)
	{
		// if player already in event ==> he wants to leave?
		if (g_playerData[client][IsInEvent] || g_playerData[client][IsInQueue])
		{
			ShowMenu_LeaveEvent(client);
		}
		else
		{
			ShowMenu_JoinEvent(client);
		}
	}
	// if no event found: choose event
	else
	{
		
		//PrintToChat(client, "%s Event chooser is under construction", PLUGIN_PREFIX);
		ShowMenu_StartEvent(client);
		//if admin condition: (GetUserFlagBits(client) != 0)
	}
	return Plugin_Handled;
}

// setup event, create spectator area and other things
bool InitEvent(int event, int activator = -1)
{
	// g_event = -1 only right after ResetEvent(), this should be safe
	if (g_event >= 0)
	{
		PrintToActivator(activator, "Blocked by ongoing \"%s\" event", g_eventConfig[g_event][sName]);
		return false;
	}

	g_event = event;
	g_bRoundStarted = false;
	
	// Create entities, which will be destroyed only when event ends completely 
	if (!CreateEventEntities())
		return false;
	
	// hook damage dealing for everyone
	for (int i = 1; i < MaxClients; i++)
		if (IsValidClient(i))
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	
	// send invitations
	ShowMenu_JoinEvent(activator);
	
	for (int i = 1; i <= MaxClients; i++)
		if (g_playerData[i][IsInSpectatorArea]
			&& !IsInDuel(i)
			&& (i != activator))
			ShowMenu_JoinEvent(i);
	
	CreateTimer(1.0, Timer_EventStep, _, TIMER_REPEAT);
	
	PrintToChatAll("%s \"%s\" event is starting. Type /event in chat for join menu", PLUGIN_PREFIX, g_eventConfig[event][sName]);
	
	if (activator < 0)
	{
		// no activator ==> auto-event
		StartTimer_AutoTimer(AutoTimer:EnoughInQueue);
		
		//
	}
	return true;
}

StartRound(int activator = -1)
{
	if (g_event < 0)
	{
		PrintToActivator(activator, "Event cancelled");
		return;
	}
	
	g_bRoundStarted = true;

	// prepare players 
	PreparePlayers();
	
	// brushes, beams, etc
	CreateRoundEntities();
	
	// hooks moved elsewhere
	//
	PlayFightSound();
	
	// starting positions
	TeleportOnRoundStart();
		
	PrintToSpectators("Round %d!", g_eventRound + 1);
}

PreparePlayers()
{
	// init team counters
	for (int team = 0; team < g_eventConfig[g_event][Teams]; team++)
		g_team_counter[team] = 0;
	
	// for all players in event
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i)
			&& g_playerData[i][IsInEvent]
			&& IsPlayerAlive(i))
		{
			///! get max health, heal to max hp. 
			//default option: heal to 100
			SetVariantInt(100);
			AcceptEntityInput(i, "SetHealth");
			
			// IsOut == 1 means player is not in event but will join on next round (for example: if died in tdm)
			g_playerData[i][IsOut] = 0;
			
			// team counters (for tracking round end conditions)
			g_team_counter[g_playerData[i][Team]]++;	// for ffa g_playerData[i][Team] == 0 
		}		
		
	// debugprint
	//for (int team = 0; team < g_eventConfig[g_event][Teams]; team++)
		//PrintToSpectators("team [%d] has %d players", team, g_team_counter[team]);
}

bool CreateEventEntities()
{
	
	int ent;
	// default entities:
	
	///! AntiShuri
	// if globalAntiShuri != 0 then spawn AntiShuri trigger
	// else spawn it on roundstart
	
	//SpectatorArea
	ent = CreateBrush("trigger_multiple", GetConfigVector(g_event, _:vecSpectatorArea_pos), GetConfigVector(g_event, _:vecSpectatorArea_size));
	
	if (!AddEventEntity(ent))
		return false;
	
	HookSingleEntityOutput(ent, "OnStartTouch", StartTouch_SpectatorArea, false); 
	HookSingleEntityOutput(ent, "OnEndTouch", EndTouch_SpectatorArea, false);		
	
	// specific entities
	
	// done!
	return true;
}

CreateRoundEntities()
{
	int ent, target;
	
	// default entities:
	 
	///! AntiShuri
	// if globalAntiShuri == 0 then spawn AntiShuri trigger
	// else spawn it on eventstart
	 
	ent = CreateBrush("trigger_multiple", GetConfigVector(g_event, _:vecMainArena_pos), GetConfigVector(g_event, _:vecMainArena_size), 1103);
	if (!AddRoundEntity(ent))
		return;
	HookSingleEntityOutput(ent, "OnStartTouch", AntiShuriTouch, false);

	//PrintToSpectators("created ent %d", ent);
	
	// main area: trigger for tele'ing spectators out and tracking event leavers (if needed)
	ent = CreateBrush("trigger_multiple", GetConfigVector(g_event, _:vecMainArena_pos), GetConfigVector(g_event, _:vecMainArena_size));
	if (!AddRoundEntity(ent))
		return;
	HookSingleEntityOutput(ent, "OnStartTouch", StartTouch_MainArea, false); 
	HookSingleEntityOutput(ent, "OnEndTouch", EndTouch_MainArea, false);		
	
	// draw borders
	if (g_eventConfig[g_event][HasBorder])
	{
		if (g_eventConfig[g_event][MainArena_shape] == 0) // rect
		{
			float vecRect[4][3];
			float vecCenter[3], vecSize[3];
			MemberToVec(g_eventConfig[g_event][vecMainArena_pos], vecCenter);
			MemberToVec(g_eventConfig[g_event][vecMainArena_size], vecSize);
			vecCenter[2] = g_eventConfig[g_event][fBorderHeight];
			
			for (int i = 0; i < 4; i++)
			{
				vecRect[i][2] = vecCenter[2];
				
				// ?!
				vecRect[i][0] = vecCenter[0] + ((i%2) * 2 - 1) * vecSize[0]/2;
				vecRect[i][1] = vecCenter[1] + ((i/2) * 2 - 1) * vecSize[1]/2;
				
				//PrintToSpectators("vecRect[%d] = (%3.3f, %3.3f, %3.3f)", i, vecRect[i][0], vecRect[i][1], vecRect[i][2]);
			}
			
			//PrintToSpectators("round entities: %d", g_roundEntity_count);
			for (int i = 0; i < 4; i++)
			{
				// 0 1
				// 2 3
				// doing (0-1 1-2 2-3 3-0) will cross them
				// we doing here (0-1 0-2 1-3 2-3)
				DrawBeam(target, ent, vecRect[(i-1>0) ? i-1 : 0], vecRect[(i+1<4) ? i+1 : 3], "60 176 40");
				AddRoundEntity(target);
				AddRoundEntity(ent);
				///! creating 8 ents instead of 4... not good
				
				//PrintToSpectators(" added entities: %d, %d", ent, target);
			}
			//PrintToSpectators("round entities: %d", g_roundEntity_count);
		}
		else if (g_eventConfig[g_event][MainArena_shape] == 1) // arena
		{
			
		}
	}
	
	//PrintToSpectators("created ent %d", ent);
}

public Action:PlayerDeathEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	//int temp = GetClientOfUserId(GetEventInt(event, "userid"));
	//PrintToSpectators("death: %d", temp);
	
	if (g_bRoundStarted)
	{
		//get victim
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		
		PlayerOut(victim);
	}
}

PlayerOut(int client)
{
	//PrintToSpectators("PlayerOut(%d). IsInEvent=%d, IsOut=%d", client, g_playerData[client][IsInEvent], g_playerData[client][IsOut]);
	if (g_playerData[client][IsInEvent] && !g_playerData[client][IsOut])
	{
		g_playerData[client][IsOut] = 1;
		g_team_counter[g_playerData[client][Team]]--;
		
		if ((g_eventConfig[g_event][Type] == TDM) && (g_team_counter[g_playerData[client][Team]] <= 0) /*  ///! && captains don't matter */)
			PrintToSpectators("%s is out!", g_teamName[g_playerData[client][Team]]);
		
		//TeleportOut(client);
		
		EndRoundConditions(client);
	}
}

EndRoundConditions(int client = -1)
{
	///! there will be MapConfig parameter for this. Maybe this will become "switch (g_eventConfig[g_event][<new param>])" ?
	switch (g_eventConfig[g_event][Type])
	{
		case TDM:
		{
			// default: team is out when every member is dead
			
			// if someone died but team still has alive members
			if ((client > 0) && (g_team_counter[g_playerData[client][Team]] > 0))
				return;
			
			//else
			// count alive teams
			int aliveNum = 0;
			int aliveTeam = -1;
			for (int team = 0; team < g_eventConfig[g_event][Teams]; team++)
				if (g_team_counter[team] > 0)
				{
					aliveNum++;
					aliveTeam = team;
				}
			
			if (aliveNum > 1)
				return;
			
			if (aliveNum == 1)
				g_eventScore[aliveTeam]++;
			
			char scoreStr[32] = "";
			
			//scores string for TDM:
			if (g_eventConfig[g_event][Teams] > 0)
			{
				Format(scoreStr, sizeof(scoreStr), " Score: %d", g_eventScore[0]);
				if (g_eventConfig[g_event][Teams] > 1)
					for (int team = 1; team < g_eventConfig[g_event][Teams]; team++)
						Format(scoreStr, sizeof(scoreStr), "%s-%d", scoreStr, g_eventScore[team]);
			}
				
			if (aliveNum == 1)
			{
				// we have a winner team!
				PrintToSpectators("%s wins the round!%s", g_teamName[aliveTeam], scoreStr);
			}
			else
			{
				// draw? how is it possible?
				PrintToSpectators("Draw!%s", scoreStr);
			}
			
			EndRound();
		}
		case FFA:
		{
			///!
		}
	}
}

EndRound()
{
	g_eventRound++;
	g_bRoundStarted = false;
	
	RemoveAllRoundEntities();
	
	// round limit check
	
	/*
	Пусть число команд равно n
	количество очков у команд: s1, s2, ... , sn
	лимит раундов равен RL

	очевидное: если счёт команды достиг RL/2 + 1, то она побеждает. Но этого условия мало для n > 2
	тогда: пусть S_f - количество очков у команды, занимающей первое место, S_s - второе.
	оставшееся число раундов равно RoundsLeft.
	Если между раундами S_f - S_s > RoundsLeft, то смысла продолжать нет (например: у одной команды 4, у остальных трёх по 1. Если осталось меньше 4-1=3 раундов, то игра заканчивается
	Достаточно ли этого правила? думаю да, там увидим
	*/
	//Тогда условие матчпоинта - выигрыш команды с S_f в следующем раунде: (S_f+1 /*счёт*/ - S_s > RoundsLeft-1 /*следующий раунд*/)
	
	//check for win conditions
	int S_f = g_eventScore[0], S_s = 0, S_f_pos = 0;
	// find max score
	for (int i = 1; i < g_eventConfig[g_event][Teams]; i++)
		if (g_eventScore[i] > S_f)
		{
			S_f = g_eventScore[i];
			S_f_pos = i;
		}
	// find second score (could be == first score)
	for (int i = 0; i < g_eventConfig[g_event][Teams]; i++)
		if ((i != S_f_pos) && (g_eventScore[i] > S_s))
			S_s = g_eventScore[i];
		
	if (S_f - S_s > g_eventConfig[g_event][RoundLimit] - g_eventRound)
	{
		//PrintToSpectators("End event! %d-%d>%d-%d",S_f - S_s, g_eventConfig[g_event][RoundLimit], g_eventRound);
		EndEvent();
	}
	// check for  matchpoints
	else
	{
		if ((S_f+1) - S_s > g_eventConfig[g_event][RoundLimit] - (g_eventRound+1))
		{
			//PrintToSpectators("MatchPoint! %d-%d>%d-%d",(S_f+1), S_s, g_eventConfig[g_event][RoundLimit], g_eventRound+1);
			PrintToSpectators("MatchPoint!");
		}
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{		
	if ((IsValidClient(attacker)) && (IsValidClient(victim)))
	{
		//block damage between participant and non-participant
		if (g_playerData[attacker][IsInEvent] != g_playerData[victim][IsInEvent])
			return Plugin_Handled;

		//block damage between rounds
		if (!g_bRoundStarted && g_playerData[attacker][IsInEvent] && g_playerData[victim][IsInEvent])
			return Plugin_Handled;
		
		// block friendly fire 
		if (g_eventConfig[g_event][FriendlyFire] == 0) // if ff is off
			if (g_eventConfig[g_event][Teams] > 1)
				if ((g_playerData[victim][Team] == g_playerData[attacker][Team]) && g_playerData[attacker][IsInEvent] && g_playerData[victim][IsInEvent])
					return Plugin_Handled;
				
		///! block participant damage on picking phase
		
	}	
	return Plugin_Continue;
}

public OnSpawn(entity)
{
	if (IsValidClient(entity))
		if (!IsInDuel(entity))
			if (IsPlayerAlive(entity))
				if (g_playerData[entity][IsInEvent])
				{
					//if (g_teleQueue[entity] == 0)
					//{
					//	g_teleQueue[entity] = -1;
					//	TeleportOut(entity);
					//}
				}
}

//////////////////////////////
//							//
//		Menus				//
//							//
//////////////////////////////

ShowMenu_LeaveEvent(int client)
{
	if (!IsValidClient(client))
		return;
	
	Menu menu = new Menu(MenuHandler_LeaveEvent, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = false;
		
	menu.SetTitle("Leave event?");
	
	menu.AddItem("Yes", "Yes");
	menu.AddItem("No", "No");
		
	menu.AddItem("--", "---", ITEMDRAW_SPACER);
	
	// lul
	if (GetUserFlagBits(client) != 0)
		menu.AddItem("queue", "Queue Explorer");
	
	menu.Display(client, MENU_DURATION);
}

public int MenuHandler_LeaveEvent(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		if (g_event >= 0)
		{
			if (StrEqual(info, "Yes"))
			{
				PrintToActivator(param1, "%s Leaving event", PLUGIN_PREFIX);
				ResetClient(param1);
			}
			else if (StrEqual(info, "queue"))
			{
				ShowMenu_QueueExplorer(param1);
			}
			else if (StrEqual(info, "No"))
			{
				// do nothing 
			}
		}
		else
		{
			PrintToActivator(param1, "%s Event ended", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

ShowMenu_JoinEvent(int client)
{
	if (!IsValidClient(client) || g_event < 0)
		return;
	
	Menu menu = new Menu(MenuHandler_JoinEvent, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = false;
		
	menu.SetTitle("Join event?");
	
	menu.AddItem("Exit", "Exit");
	
	// spacers for 1-2-3 stance buttons
	menu.AddItem("--", "---", ITEMDRAW_SPACER);
	menu.AddItem("--", "---", ITEMDRAW_SPACER);
	
	menu.AddItem("join", "Join");
	menu.AddItem("spec", "Spectate");
	
	if (GetUserFlagBits(client) != 0)
		menu.AddItem("queue", "Queue Explorer");
	
	menu.Display(client, MENU_DURATION);
}

public int MenuHandler_JoinEvent(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		//if (StrEqual(info, "Exit"))
		//{
			// do nothing?
		//}
		
		if (g_event >= 0)
		{
			if (StrEqual(info, "join"))
			{
				AddPlayerToQueue(param1);
				
				// teleport to event, but only if he is not already there
				if (!g_playerData[param1][IsInSpectatorArea])
					TeleportOut(param1);
			}
			else if (StrEqual(info, "spec"))
			{
				TeleportOut(param1);
			}
			else if (StrEqual(info, "queue"))
			{
				ShowMenu_QueueExplorer(param1);
			}
		}
		else
		{
			PrintToActivator(param1, "%s Event ended", PLUGIN_PREFIX)
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

ShowMenu_QueueExplorer(int client)
{
	if (!IsValidClient(client) || g_event < 0)
		return;
	
	Menu menu = new Menu(MenuHandler_QueueExplorer, MENU_ACTIONS_DEFAULT);
	menu.Pagination = true;
	menu.ExitButton = true;
		
	menu.SetTitle("Queue Explorer: TDM");
	
	menu.AddItem("refresh", "Refresh");
	
	// start round button is disabled when someone is dead
	int deadPlayers = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (g_playerData[i][IsInEvent] && !IsPlayerAlive(i))
			deadPlayers++;
	
	if (deadPlayers > 0)
	{
		char startStr[32];
		Format(startStr, sizeof(startStr), "Start round (%d dead)", deadPlayers);
		menu.AddItem("--", startStr, ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("start", "Start round");
	}
	
	
	// don't look here (show team counters)
	if (g_eventConfig[g_event][Teams] > 0)
	{
		char teamsStr[32] = "Teams: ";
		Format(teamsStr, sizeof(teamsStr), "%s %d", teamsStr, PlayersInTeam(0));
		if (g_eventConfig[g_event][Teams] > 1)
			for (int team = 1; team < g_eventConfig[g_event][Teams]; team++)
				Format(teamsStr, sizeof(teamsStr), "%s-%d", teamsStr, PlayersInTeam(team));
		menu.AddItem("teams", teamsStr, ITEMDRAW_DISABLED);
	}
	
	// add queue list
	bool bNoPlayers = true;
	// first is client:
	if (g_playerData[client][IsInQueue])
	{
		char name[64], clientStr[4];
		GetClientName(client, name, sizeof(name));
		Format(clientStr, sizeof(clientStr), "%d", client);
		menu.AddItem(clientStr, name);
		
		bNoPlayers = false;
	}
	
	// other players in queue
	for (int i = 0; i < g_queue_count; i++)
		if ((g_queue[i] != client)
			&& IsValidClient(g_queue[i])
			&& g_playerData[g_queue[i]][IsInQueue] // just in case
			&& !IsInDuel(g_queue[i]))
		{
			char name[64], clientStr[4];
			GetClientName(g_queue[i], name, sizeof(name));
			Format(clientStr, sizeof(clientStr), "%d", g_queue[i]);
			menu.AddItem(clientStr, name);
			
			bNoPlayers = false;
		}
	
	if (bNoPlayers)
	{
		menu.AddItem("--", "Queue empty", ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, 9999);
}

StartTimer_RoundStart()
{
	PlayRoundSound(g_eventRound);
	TeleportOnRoundStart();
	
	CreateTimer(2.0, FireTimer_RoundStart);
}

public Action FireTimer_RoundStart(Handle timer)
{
	StartRound();
	return Plugin_Stop; 
}


public int MenuHandler_QueueExplorer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice string
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		if (g_event >= 0)
		{
			if (StrEqual(info, "refresh"))
			{
				ShowMenu_QueueExplorer(param1);
			}
			else if (StrEqual(info, "start"))
			{
				int deadPlayers = 0;
				for (int i = 1; i <= MaxClients; i++)
					if (g_playerData[i][IsInEvent] && !IsPlayerAlive(i))
						deadPlayers++;
				
				if (deadPlayers == 0)
				{
					StartTimer_RoundStart();
				}
				else
				{
					ShowMenu_QueueExplorer(param1);
				}
			}
			else 
			{
				int client = StringToInt(info);
				if (IsValidClient(client))
				{
					g_temp_client[param1] = client;
					ShowMenu_ChooseTeam(param1); 
				}
			}
		}
		else
		{
			PrintToActivator(param1, "%s Event ended", PLUGIN_PREFIX)
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

ShowMenu_ChooseTeam(int client)
{	
	if (!IsValidClient(client) || g_event < 0)
		return;
	
	Menu menu = new Menu(MenuHandler_ChooseTeam, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = false;

	menu.SetTitle("Choose Team");
	
	menu.AddItem("Back", "Back");
	
	char teamName[32], teamStr[4];
	for (int team = 0; team < g_eventConfig[g_event][Teams]; team++)
	{
		Format(teamStr, sizeof(teamStr), "%d", team);
		Format(teamName, sizeof(teamName), "%s (%d)", g_teamName[team], PlayersInTeam(team));
		menu.AddItem(teamStr, teamName);
	}
	
	menu.Display(client, 9999);
}

public int MenuHandler_ChooseTeam(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice string
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		if (g_event >= 0)
		{
			if (StrEqual(info, "Back"))
			{
				ShowMenu_QueueExplorer(param1);
			}
			else 
			{
				int team = StringToInt(info);
				if ((team >= 0) && (team < g_eventConfig[g_event][Teams]))
				{
					AddPlayerToEvent(g_temp_client[param1], team, param1);
					ShowMenu_QueueExplorer(param1);
				}
			}
		}
		else
		{
			PrintToActivator(param1, "%s Event ended", PLUGIN_PREFIX)
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

ShowMenu_StartEvent(int client)
{
	if (g_event_count <= 0)
	{
		PrintToChat(client, "%s No events available", PLUGIN_PREFIX);
		return;
	}
	
	if (g_event > 0)
	{
		PrintToChat(client, "%s Another event already started", PLUGIN_PREFIX);
		return;
	}
	
	// count public and admin events
	int publicCount = 0;
	int adminCount = 0;
	for (int i = 0; i < g_event_count; i++)
		if (g_eventConfig[i][IsPublic])
		{
			publicCount++;
		}
		else
		{
			adminCount++;
		}
	
	// if no public events: don't show menu for non-admins
	if ((publicCount <= 0) && (GetUserFlagBits(client) == 0))
	{
		PrintToChat(client, "%s No events available", PLUGIN_PREFIX);
		return;
	}
	
	//there are public events or client is admin ==> show menu
	Menu menu = new Menu(MenuHandler_StartEvent, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = false;
	
	menu.SetTitle("Choose event");
	
	menu.AddItem("Exit", "Exit");
	if (adminCount && GetUserFlagBits(client)) 
		menu.AddItem("adminevents", "Special events");
	
	if (publicCount <= 0)
	{
		menu.AddItem("--", "No public events", ITEMDRAW_DISABLED);
	}
	else
	{
		// add public events
		for (int i = 0; i < g_event_count; i++)
			if (g_eventConfig[i][IsPublic])
			{
				char eventStr[4];
				Format(eventStr, sizeof(eventStr), "%d", i);
				menu.AddItem(eventStr, g_eventConfig[i][sName]);
			}
	}
	
	menu.Display(client, 9999);
}



public int MenuHandler_StartEvent(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice string
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		
		if (!StrEqual(info, "Exit"))
		{
			if (g_event <= 0)
			{
				
				if (StrEqual(info, "adminevents"))
				{
					ShowMenu_AdminEvents(param1);
				}
				else
				{
					int eventI = StringToInt(info);
					if ((eventI>=0) && (eventI < g_event_count) && g_eventConfig[eventI][IsPublic])
						InitEvent(eventI); // activator isn't set ==> we know event must be automatic
				}
			}
			else
			{
				PrintToActivator(param1, "Another event already started");
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

ShowMenu_AdminEvents(int client)
{
	if (g_event_count <= 0)
	{
		PrintToChat(client, "%s No events available", PLUGIN_PREFIX);
		return;
	}
	if (g_event > 0)
	{
		PrintToChat(client, "%s Another event already started", PLUGIN_PREFIX);
		return;
	}
	
	Menu menu = new Menu(MenuHandler_AdminEvents, MENU_ACTIONS_DEFAULT);
	menu.Pagination = false;
	menu.ExitButton = false;
	
	menu.AddItem("back", "Back");
	// find at least one admin event
	int adminCount = 0;
	for (int i = 0; i < g_event_count; i++)
		if (!g_eventConfig[i][IsPublic])
		{
			adminCount++;
			break;
		}
		
	if (!adminCount)
	{
		menu.AddItem("--", "No special events", ITEMDRAW_DISABLED);
	}
	else
	{
		// add admin events
		for (int i = 0; i < g_event_count; i++)
			if (!g_eventConfig[i][IsPublic])
			{
				char eventStr[4];
				Format(eventStr, sizeof(eventStr), "%d", i);
				menu.AddItem(eventStr, g_eventConfig[i][sName]);
			}
	}
	

	
	menu.Display(client, 9999);
}

public int MenuHandler_AdminEvents(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{		
		// param1 = menu's chooser
		// param2 = (kinda) choice
		// info = actual choice string
		char info[64];
		menu.GetItem(param2, info, sizeof(info));
		
		if (g_event <= 0)
		{
			if (StrEqual(info, "back"))
			{
				ShowMenu_StartEvent(param1);
			}
			else
			{
				int eventI = StringToInt(info);
				if ((eventI>=0) && (eventI < g_event_count) && g_eventConfig[eventI][IsPublic])
					InitEvent(eventI, param1); // activator != default ==> event is not automatic
			}
		}
		else
		{
			PrintToActivator(param1, "Another event already started");
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return;
}

PlayersInTeam(int team)
{
	int counter = 0;
	if (g_eventConfig[g_event][Teams] > team)
	{
		for(int i = 1; i <= MaxClients; i++)
			if (g_playerData[i][IsInEvent] 
				&& IsValidClient(i)
				&& g_playerData[i][Team] == team)
				counter++;
	}
	return counter;
}

//////////////////////////////
//							//
//		Load map			//
//							//
//////////////////////////////
bool LoadMap()
{
	// load kv's from file plugins/settings/ct_events/<mapName>.txt
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/settings/ct_events/%s.txt", mapName);
	
	Handle kv = CreateKeyValues("MapConfig");
	if (!FileToKeyValues(kv, path))
	{
		PrintToServer("[Events][MapConfig] Map file <%s> not found. Events disabled.", path);
		CloseHandle(kv);
		return false;
	}
	
	// event counters
	int publicCount = 0;
	int customCount = 0;
	g_event_count = 0;
	
	// "_Events_" section
	if (!KvJumpToKey(kv, "_Events_"))
	{
		PrintToServer("[Events][MapConfig] \"_Events_\" section not found");
		CloseHandle(kv);
		return false;
	}
	// from "_Events_" to first event name
	if (!KvGotoFirstSubKey(kv))
	{
		PrintToServer("[Events][MapConfig] No events in \"_Events_\" section");
		CloseHandle(kv);
		return false;
	}
		
	// prepare second kv handle for the _Links_ section
	// I should remember positions with KvGetSectionSymbol instead, but symbols feel weird :(
	Handle kvLinks = CreateKeyValues("MapConfig");
	FileToKeyValues(kvLinks, path);
	
	// load event
	do
	{
		////////////////////begin:
		
		// if (something goes wrong) then {Available param stays == 0}
		//g_eventConfig[g_event_count][IsAvailable] = 0;
		
		// Event name in /event menu
		KvGetSectionName(kv, g_eventConfig[g_event_count][sName], MAXSTRINGSIZE);
		PrintToServer("[Events][MapConfig] Loading event \"%s\"", g_eventConfig[g_event_count][sName]);
		
		// primary params:
		////////////////////////////
		// "public" "0"	// boolean ( 0 - only admins can start, 1 - anyone can start)
		g_eventConfig[g_event_count][IsPublic] = KvGetNum(kv, "public", false);
		
		//check if more events allowed:
		if (g_eventConfig[g_event_count][IsPublic] == 0)
		{
			if (publicCount >= MAXPUBLICEVENTS)
			{
				PrintToServer("[Events][MapConfig] Skipping event \"%s\": Public event limit reached", g_eventConfig[g_event_count][sName]);
				continue;
			}
		}
		else if (customCount >= MAXCUSTOMEVENTS)
		{
			PrintToServer("[Events][MapConfig] Skipping event \"%s\": Custom event limit reached", g_eventConfig[g_event_count][sName]);
			continue;
		}	
	
		////////////////////////////
		//"type" "tdm" // one of g_eventTypeName strings. basic skeleton of event. defines rules, picking, etc. should be an event itself (without any modifiers or special params)
		char kvStr[MAXSTRINGSIZE] = "";
		KvGetString(kv, "type", kvStr, sizeof(kvStr), "--");
		
		//check type name
		bool wrongType = true;
		for (new EventType:typeI = EventType:0; typeI < EventType:COUNT; typeI++)// alright, tag mismatch hunt went a bit too far
			if (StrEqual(kvStr, g_eventTypeName[_:typeI], false))
			{
				wrongType = false;
				g_eventConfig[g_event_count][Type] = typeI;
				break;
			}
		
		if (wrongType)
		{
			PrintToServer("[Events][MapConfig] Unknown \"type\" value: \"%s\". Must be one of those:", kvStr);
			// Print values in g_eventTypeName
			for (new EventType:typeI = EventType:0; typeI < EventType:COUNT; typeI++)
				PrintToServer("[Events][MapConfig] \"%s\"", g_eventTypeName[_:typeI]);
			
			continue;
		}
		else
		{
			
		// load event params (depending on event type)
		///////////////////////////////////////////////
			KvGetEventParams(kv);
		
		}
		
		// load areas and points
		////////////////////////////
		//"default_links" "1" // boolean. 1 - loader searches for areas and points with default names. 0 - manually set links or even areas and points in this events
		int default_links = KvGetNum(kv, "default_links", 1);
		
		// first we load only tdm/ffa points and areas (every event requires them: arena, spawn positions, teleOut, spectator area)
		// we don't need to spawn anything, just store values in memory.
		
		if (!KvGetBasicLocations(kv, kvLinks, default_links))
			continue; //PrintToServer should be inside KvGetBasicLocations
		
		//debug print
		//PrintEventConfig(g_event_count)
		
		
		////////////////////end:
		// no one called "continue;", everything should be fine
		//g_eventConfig[g_event_count][IsAvailable] = 1;
		g_event_count++;
		if (g_eventConfig[g_event_count][IsPublic])
			publicCount++;
		else
			customCount++;
		
		
	} while (KvGotoNextKey(kv) && (g_event_count < MAXPUBLICEVENTS + MAXCUSTOMEVENTS));
	CloseHandle(kv);
	CloseHandle(kvLinks);
	
	// print total event count
	if (g_event_count == MAXPUBLICEVENTS + MAXCUSTOMEVENTS)
		PrintToServer("[Events][MapConfig] Events loaded: %d (Maximum)", g_event_count); 
	else
		PrintToServer("[Events][MapConfig] Events loaded: %d", g_event_count);
	
	
	// return false if no events found.
	return (g_event_count > 0);
}

KvGetEventParams(Handle& kv)
{
	char kvStr[MAXSTRINGSIZE] = "";
	//bool wrongStr = true;
	
	// "?
	///////////////////////////////////////
	g_eventConfig[g_event][FriendlyFire] = 1;
	
	// "borderheight" laser borders for arena. no borders if param not found
	///////////////////////////////////////
	
	// check if there is this param (are there no better ways to do it?)
	KvGetString(kv, "borderheight", kvStr, sizeof(kvStr), "--");
	if (!StrEqual(kvStr, "--"))
	{
		g_eventConfig[g_event_count][HasBorder] = 1;
		g_eventConfig[g_event_count][fBorderHeight] = KvGetFloat(kv , "borderheight");
	}
	
	///! RoundLimit
	///////////////////////////////////////
	g_eventConfig[g_event_count][RoundLimit] = 9;
	
	// "minplayers" 
	// Minimum players for autoevent
	///////////////////////////////////////
	g_eventConfig[g_event_count][MinimumPlayers] = KvGetNum(kv, "minplayers", 4);
	
	// "team_count"
	///////////////////////////////////////
	
	// (could be 1?) default is 2
	if  (g_eventConfig[g_event_count][Type] == TDM)
	{
		g_eventConfig[g_event_count][Teams] = KvGetNum(kv, "team_count", 2);
		if ((g_eventConfig[g_event_count][Teams] <= 0) || (g_eventConfig[g_event_count][Teams] > TeamColor:COUNT))
			g_eventConfig[g_event_count][Teams] = 2;	
	}
	else
	{
		g_eventConfig[g_event_count][Teams] = 0;
	}
	// "starttp" 
	///////////////////////////////////////
	
	// TeleportOnRoundStart positions
	// default is "teams" for tdm. possible values: "none", "mixed"
	// default for ffa (circle) has no name, but you can change it to "none"
	KvGetString(kv, "starttp", kvStr, sizeof(kvStr), "--");
	
	//check spawn name
	if (StrEqual(kvStr, "--"))
	{
		// default for any mode
		g_eventConfig[g_event_count][StartTP] = 0;
	}
	else if (StrEqual(kvStr, "none"))
	{
		// no start tele for any mode
		g_eventConfig[g_event_count][StartTP] = -1;
	}
	else if (StrEqual(kvStr, "mixed"))
	{
		// circle spawn with teams mixed (like in TDM Tourney)
		g_eventConfig[g_event_count][StartTP] = 1;
	}
	else
	{
		switch (g_eventConfig[g_event_count][Type])
		{
			case TDM:
			{
				PrintToServer("[Events][MapConfig] Unknown \"starttp\" value: \"%s\". \"%s\" event must have one of those:", kvStr, g_eventTypeName[g_eventConfig[g_event_count][Type]]);
				PrintToServer("[Events][MapConfig] \"%s\" (default if found nothing)", "teams");
				PrintToServer("[Events][MapConfig] \"%s\"", "mixed");
				PrintToServer("[Events][MapConfig] \"%s\"", "none");
			}
			case FFA:
			{
				PrintToServer("[Events][MapConfig] Unknown \"starttp\" value: \"%s\". \"%s\" event always set to default unless \"none\" value found", kvStr, g_eventTypeName[g_eventConfig[g_event_count][Type]]);
			}
		}
		
		// switch to default
		g_eventConfig[g_event_count][StartTP] = 0;
	}
}

bool KvGetBasicLocations(Handle& kv, Handle& kvLinks, int default_links = 1)
{
	
	// kv is inside event
	
	// for each basic location
	for (new EventLocation:locI = EventLocation:0; locI < BASIC; locI++) 
	{
		char linkName[MAXSTRINGSIZE];
		if (default_links)
		{
			// default_links == true means we don't have list of locations in kv. We don't need this handle then
			Format(linkName, sizeof(linkName), "%s_%s", g_eventTypeName[g_event_count], g_eventBasicLocationName[locI]);
		}
		else
		{
			// default_links == false means we need to find location section inside event.
			if (!KvJumpToKey(kv, g_eventBasicLocationName[locI]))
			{
				PrintToServer("[Events][MapConfig] Location info not found: \"%s\" (default_links==false)", g_eventBasicLocationName[locI]);
				return false;
			}
			// location info found! 
			
			// if == "--" then it is not a link ==> values must be right there 
			KvGetString(kv, "link", linkName, sizeof(linkName), "--");
			
		}
			
		//now we are were we want: inside location info in kv or with linkName for kvLinks
		switch (locI)
		{
			case MainArena:
			{
				KvGetArea(kv, kvLinks, linkName,
					_:MainArena_shape,
					_:vecMainArena_pos,
					_:vecMainArena_size,
					_:fMainArena_radius);
			} 
			case Spawn:
			{
				KvGetArea(kv, kvLinks, linkName,
					_:Nothing,	// shape of area
					_:vecSpawn_pos,
					_:Nothing, //size of rect
					_:fSpawn_radius,
					1/* force circle "area" */);
			}
			case TeleOut:
			{
				KvGetPoint(kv, kvLinks, linkName,
					_:vecTeleOut_pos,
					_:vecTeleOut_dir);
			}
			case SpectatorArea:
			{
				KvGetArea(kv, kvLinks, linkName,
					_:Nothing, // shape of area
					_:vecSpectatorArea_pos,
					_:vecSpectatorArea_size,
					_:Nothing, // radius of circle area
					0 /* force rect */);
			}
		}
		
		// go back from location section to event section
		if (!default_links)
			KvGoBack(kv);
	}		
	
	return true;
}


KvGetArea(Handle& kv, Handle& kvLinks, char[] linkName,
	int shapeI, // indexes for g_eventConfig arrays
	int posI, 
	int sizeI, 
	int radiusI, 
	int forceShape = -1) // shape and after should be references, but idk how array references work
{
	float vec[3];
	
	bool link = !StrEqual("--", linkName);
	// kv is already where we want
	
	if (link)
	{
		// if this a link
		if (!KvJumpToLink(kvLinks, linkName))
			return false;
	}
	// now kv is inside location info.
	
	// position
	KvGetVector(link ? kvLinks : kv , "position", vec);
	VecToMember(vec, g_eventConfig[g_event_count][posI]);  // tag mismatch. don't know how to avoid it if I want to pass enum index here
																// (maybe write a function with big pile of switch(posI), each leads to something mismatch-less like VecToMember(vec, g_eventConfig[g_event_count][vecMainArena_pos]); ) 
	
	//get shape of area
	if (forceShape == 0)
	{
		KvGetVector(link ? kvLinks : kv , "size", vec);
		VecToMember(vec, Float:g_eventConfig[g_event_count][sizeI]);	// tag mismatch. don't know how to avoid it if I want to pass enum index here
		return true;
	}
	else if (forceShape == 1)
	{
		g_eventConfig[g_event_count][radiusI] = KvGetFloat(link ? kvLinks : kv , "radius");		// tag mismatch. don't know how to avoid it if I want to pass enum index here
		return true;
	}
							
	char shapeStr[MAXSTRINGSIZE];
	KvGetString(link ? kvLinks : kv , "shape", shapeStr, sizeof(shapeStr), "-");
	if (StrEqual(shapeStr, "rectangle") || StrEqual(shapeStr, "0"))
	{
		g_eventConfig[g_event_count][shapeI] = 0;
		KvGetVector(link ? kvLinks : kv , "size", vec);
		VecToMember(vec, g_eventConfig[g_event_count][sizeI]);	// tag mismatch. don't know how to avoid it if I want to pass enum index here
	}
	else if (StrEqual(shapeStr, "circle") || StrEqual(shapeStr, "1"))
	{
		g_eventConfig[g_event_count][shapeI] = 1;
		g_eventConfig[g_event_count][radiusI] = KvGetFloat(link ? kvLinks : kv , "radius");	// tag mismatch. don't know how to avoid it if I want to pass enum index here
	}
	else
	{
		PrintToServer("[Event][MapConfig] Invalid shape: \"%s\"", shapeStr);
		return false;
	}
	return true;
}

KvGetPoint(Handle& kv, Handle& kvLinks, char[] linkName, int posI, int dirI) 
{

	
	
	bool link = !StrEqual("--", linkName);
	// kv is already where we want
	
	if (link)
	{
		// if this a link
		if (!KvJumpToLink(kvLinks, linkName))
			return false;
	}
	// now kv is inside location info.
	
	float vec[3];
	// position
	KvGetVector(link ? kvLinks : kv , "position", vec);
	VecToMember(vec, g_eventConfig[g_event_count][posI]);	// tag mismatch. don't know how to avoid it if I want to pass enum index here
	
	// view direction after teleportation
	KvGetVector(link ? kvLinks : kv , "orientation", vec);
	VecToMember(vec, g_eventConfig[g_event_count][dirI]);	// tag mismatch. don't know how to avoid it if I want to pass enum index here
	
	return true;
}

bool KvJumpToLink(Handle& kvLinks, char[] linkName)
{
	KvRewind(kvLinks);
	KvJumpToKey(kvLinks, "_Links_");
	if (!KvJumpToKey(kvLinks, linkName)) 
	{
		PrintToServer("[Event][MapConfig] Link \"%s\" not found", linkName);
		return false;
	}
	return true;
}


//////////////////////////////
//							//
//		Useful things		//
//							//
//////////////////////////////



// Spammy prints
void PrintToSpectators(const char[] myString, any ...)
{
	int len = strlen(myString) + 255;
	char[] myFormattedString = new char[len];
	VFormat(myFormattedString, len, myString, 2);
 
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if ((g_playerData[i][IsInSpectatorArea] == 1) 
				|| (g_playerData[i][IsInEvent] == 1)
				|| (g_playerData[i][IsInQueue] == 1))
				PrintToChat(i, "%s %s", PLUGIN_PREFIX, myFormattedString);
} 

// Print to chat if player exists
void PrintToActivator(int client, const char[] myString, any ...)
{
	int len = strlen(myString) + 255;
	char[] myFormattedString = new char[len];
	VFormat(myFormattedString, len, myString, 3);
 
	if (IsValidClient(client))
		PrintToChat(client, "%s %s", PLUGIN_PREFIX, myFormattedString);
} 

// draw beam and remove it after delay
DrawTempBeam(float delay, const float targetPos[3], const float beamPos[3], const char[] color)
{
	int ent1, ent2;
	DrawBeam(ent1, ent2, targetPos, beamPos, color);
	
	CreateTimer(delay, RemoveEntTimer, ent2);
	CreateTimer(delay+0.1, RemoveEntTimer, ent1);
}

public Action RemoveEntTimer(Handle timer, any:ent)
{
	RemoveEntity(ent);
	return Plugin_Stop; 
}

/*

// real distance between origins
float DistanceToClient(int client1, int client2)
{
	//from admin to client
	
	float vec1[3], vec2[3];
	GetClientAbsOrigin(client1, vec);
	GetClientAbsOrigin(client2, vec); 
	
	return SquareRoot((vec1[0]-vec2[0])*(vec1[0]-vec2[0])+(vec1[1]-vec2[1])*(vec1[1]-vec2[1])+(vec1[2]-vec2[2])*(vec1[2]-vec2[2]));
}

*/

// distance on xOy plane
float DistanceXY(float vec1[3], float vec2[3])
{	
	return SquareRoot((vec1[0]-vec2[0])*(vec1[0]-vec2[0])+(vec1[1]-vec2[1])*(vec1[1]-vec2[1]));
}
 

//////////////////////////////
//							//
//		Misc 				//
//							//
//////////////////////////////

  
SaveColor(int client)
{
	if (StrEqual(g_playerData[client][sSavedColor], "-"))
		GetClientInfo(client, "vs_color", g_playerData[client][sSavedColor], MAXSTRINGSIZE);
	
	//char temp[MAXSTRINGSIZE]; 
	//GetClientInfo(client, "vs_color", temp, MAXSTRINGSIZE);
	
}

RestoreColor(int client)
{
	
	if (!StrEqual(g_playerData[client][sSavedColor], "-"))
	{
		SetClientInfo(client, "vs_color", g_playerData[client][sSavedColor]);
		strcopy(g_playerData[client][sSavedColor], MAXSTRINGSIZE, "-");
	}
	
}

float[3] GetConfigVector(int event, int paramName) 
{
	float tempVec[3];
	MemberToVec(g_eventConfig[event][EventConfig:paramName], tempVec);
	
	return tempVec;
}

public StartTouch_TestAfk(const String:output[], caller, activator, Float:delay)
{
	
	
	if ((activator != testafk) && IsValidClient(activator))
	{
		float vec1[3], vec2[3], vec3[3]; 
		GetClientAbsOrigin(testafk, vec1);
		GetClientAbsOrigin(activator, vec2);
		
		vec3[2] = vec1[2];
		vec3[0] = 2*vec2[0] - vec1[0];
		vec3[1] = 2*vec2[1] - vec1[1];
		TeleportEntity(activator, vec3, NULL_VECTOR, NULL_VECTOR);
	}
}
public StartTouch_MainArea(const String:output[], caller, activator, Float:delay)
{
	if (!g_bRoundStarted) // well, idk, main area doesn't exist outside of rounds but still.. 
		return;
	
	if (!IsValidClient(activator))
		return;
	
	if (!IsPlayerAlive(activator))
		return;
	
	if (!g_playerData[activator][IsInEvent])
	{
		PrintToChat(activator, "%s Restricted by \"%s\" event. Type /event in chat to join", PLUGIN_PREFIX, g_eventConfig[g_event][sName]);
		TeleportOut(activator);
	}
	else if (g_playerData[activator][IsOut])
	{
		PrintToChat(activator, "%s You are out. Wait for next round or event", PLUGIN_PREFIX);
		TeleportOut(activator);
	}
	
}

public EndTouch_MainArea(const String:output[], caller, activator, Float:delay)
{
	/*
	///! weird bug: if someone connects while round is going -> this event is called with another player as activator...	
	///! since we don't have luxury of triggers for circle areas and we need to track leavers in timer ticks -> moved this to timer too
	
	if (!g_bRoundStarted) // well, idk, main area doesn't exist outside of rounds but still.. 
		return;
		
	if (!IsValidClient(activator))
		return;
	
	//if (!IsPlayerAlive(activator))
		//return;
	
	//float vec[3];
	//GetClientAbsOrigin(activator, vec);
	//PrintToActivator(activator, "%3.3f, %3.3f, %3.3f", vec[0], vec[1], vec[2]);	
	
	// check if someone important is leaving
	if (g_playerData[activator][IsInEvent] && !g_playerData[activator][IsOut])
	{
		///! default penalty: death (add death timer and nopenalty)
		//PrintToChat(activator, "%s Leaving event arena: %d, %d", PLUGIN_PREFIX, caller, activator);
		//ClientCommand(activator, "kill");
	}*/
}

public StartTouch_SpectatorArea(const String:output[], caller, activator, Float:delay)
{
	if (IsValidClient(activator))
	{
		g_playerData[activator][IsInSpectatorArea] = true;
	}
}

public EndTouch_SpectatorArea(const String:output[], caller, activator, Float:delay)
{
	if (IsValidClient(activator))  
	{
		g_playerData[activator][IsInSpectatorArea] = false;
	}
}

// add to g_eventEntity[] array. only works with numbers, doesn't really create brushes or beams or something
bool AddEventEntity(int entity)
{
	if (g_eventEntity_count == MAXEVENTENTITIES)
	{
		PrintToServer("[CT] Error: too many event entities. Closing event");
		RemoveEntity(entity); // it doesn't go to array, so we kill it here
		ResetEvent();
		return false;
	}
	
	g_eventEntity[g_eventEntity_count] = entity;
	g_eventEntity_count++;
	return true;
}

// add to g_roundEntity[] array. only works with numbers, doesn't really create brushes or beams or something
bool AddRoundEntity(int entity)
{
	if (g_roundEntity_count == MAXROUNDENTITIES)
	{
		PrintToServer("[CT] Error: too many 'round' entities. Closing event");
		RemoveEntity(entity); // it doesn't go to array, so we kill it here
		ResetEvent();
		return false; 
	}
	
	g_roundEntity[g_roundEntity_count] = entity;
	g_roundEntity_count++;
	return true;
}

// remove entity from g_eventEntity[] array. This one removes entity from the game too!
/*RemoveEventEntity(int entityI)
{
	//  [0 1 2 3 >4< 5 6 7 8]	(9 entities)
	RemoveEntity(g_eventEntity[entityI]);
	//  [0 1 2 3 >< 5 6 7 8]	(9 entities)
	
	if ((g_eventEntity_count > 1) && (entityI != g_eventEntity_count - 1)) // if something is left and entity was not the last one
		for (int i = entityI; i < g_eventEntity_count - 1; i++)
			g_eventEntity[i] = g_eventEntity[i + 1];
			//  [0 1 2 3 >5< 5 6 7 8] (9 entities)
			//  ...
			//  [0 1 2 3 >5< 6 7 8 8] (9 entities)
			
	g_eventEntity_count--;
	// [0 1 2 3 >5< 6 7 8] 8		(8 entities)
}*/

// same thing but for circle entities:)
/*RemoveRoundEntity(int entityI)
{
	RemoveEntity(g_roundEntity[entityI]);
	if ((g_roundEntity_count > 1) && (entityI != g_roundEntity_count - 1))
		for (int i = entityI; i < g_roundEntity_count - 1; i++)
			g_roundEntity[i] = g_roundEntity[i + 1];
		
	g_roundEntity_count--;
}*/

RemoveAllEventEntities()
{
	if (g_eventEntity_count > 0)
		for (int i = 0; i < g_eventEntity_count; i++)
			RemoveEntity(g_eventEntity[i]);
	
	g_eventEntity_count = 0;
}

RemoveAllRoundEntities()
{
	if (g_roundEntity_count > 0)
		for (int i = 0; i < g_roundEntity_count; i++)
			RemoveEntity(g_roundEntity[i]);
	
	g_roundEntity_count = 0;
}

ApplyTeamColor(int client)
{
	if (g_playerData[client][IsInEvent]
		&& IsValidClient(client)
		&& (g_eventConfig[g_event][Teams] > 0))
	{
		// if color is already good ==> don't change (to prevent non-english-names chat spam)
		char tempStr[MAXSTRINGSIZE];
		GetClientInfo(client, "vs_color", tempStr, MAXSTRINGSIZE);
		if (StrEqual(tempStr, g_color[g_playerData[client][Team]]))
			return;
		
		SaveColor(client);
		
		SetClientInfo(client, "vs_color", g_color[g_playerData[client][Team]]);
		
	}	
}

//////////////////////////////
//							//
//		Debug & Tests		//
//							//
//////////////////////////////

public void DebugPrint(const char[] section, const char[] myString, any ...)
{
	int len = strlen(myString) + 255;
	char[] myFormattedString = new char[len];
	VFormat(myFormattedString, len, myString, 3);
 
	PrintToServer("[Events][DEBUG][%s] %s", section, myFormattedString);
} 



// shouldn't be in debug section, but it must be nicer to get out of here
public Action DrawLocations(int client, int args)
{
	if (args==1)
	{
		if (g_bMapIsCorrect)
		{
			float entCl[3];
			GetClientAbsOrigin(client, entCl);
			entCl[2]+=50.0;
				
			char arg[MAXSTRINGSIZE];
			GetCmdArg(1, arg, sizeof(arg));
			int event = StringToInt(arg);
			if ((event>=0) && (event<g_event_count))
			{
				float delay = 30.0;
				float ent[30][3];
				
				float vec[3];
				// Step One. 
				// Arena.
				if (g_eventConfig[event][MainArena_shape] == 0)
				{
					// draw rect arena
					for (int i = 0; i<8; i++)
					{
						MemberToVec(g_eventConfig[event][vecMainArena_pos], ent[i]);
						MemberToVec(g_eventConfig[event][vecMainArena_size], vec);
						if (i%2==0)
							ent[i][0]+=vec[0]/2.0;
						else
							ent[i][0]-=vec[0]/2.0;
						
						if (i%4<2)
							ent[i][1]+=vec[1]/2.0;
						else
							ent[i][1]-=vec[1]/2.0;
						
						if (i/4==0)
							ent[i][2]+=vec[2]/2.0;
						else
							ent[i][2]-=vec[2]/2.0;
					}
					
					DrawTempBeam(delay, ent[0], ent[1], "0 0 128");
					DrawTempBeam(delay, ent[1], ent[3], "0 0 128");
					DrawTempBeam(delay, ent[2], ent[3], "0 0 128");
					DrawTempBeam(delay, ent[2], ent[0], "0 0 128");
					DrawTempBeam(delay, ent[0], ent[4], "0 0 128");
					DrawTempBeam(delay, ent[1], ent[5], "0 0 128");
					DrawTempBeam(delay, ent[2], ent[6], "0 0 128");
					DrawTempBeam(delay, ent[3], ent[7], "0 0 128");
					DrawTempBeam(delay, ent[4], ent[5], "0 0 128");
					DrawTempBeam(delay, ent[5], ent[7], "0 0 128");
					DrawTempBeam(delay, ent[6], ent[7], "0 0 128");
					DrawTempBeam(delay, ent[6], ent[4], "0 0 128");
					
					
					
					
				}
				else
				{
					float entCirc[32][3];
					
					// draw circle arena
					MemberToVec(g_eventConfig[event][vecMainArena_pos], vec);
					
					float vecR = g_eventConfig[event][fMainArena_radius];
					
					for (int i = 0; i < sizeof(entCirc); i++)
					{
						entCirc[i] = vec;
						
						entCirc[i][0] += vecR * Cosine( 2*PI*i/sizeof(entCirc) );
						entCirc[i][1] += vecR * Sine( 2*PI*i/sizeof(entCirc) );
						
					}
					
					
					for (int i = 0; i < sizeof(entCirc)-1; i++)
						DrawTempBeam(delay, entCirc[i], entCirc[i+1], "0 0 128");
					DrawTempBeam(delay, entCirc[sizeof(entCirc)-1], entCirc[0], "0 0 128");
					
				}
				
				
				//draw spawn 0, 90, 180 and 270 degree spawns
				
				
				MemberToVec(g_eventConfig[event][vecSpawn_pos], ent[12]);
				
				//PrintToChat(client, "g_eventConfig[event][vecSpawn_pos] = (%3.3f, %3.3f, %3.3f)", ent[12][0], ent[12][1], ent[12][2]);
				ent[13] = ent[12];
				ent[13][2] += 72.0;
				float rad = Float:g_eventConfig[event][fSpawn_radius];
				
				for (int i = 0; i<4; i++)
				{
					MemberToVec(g_eventConfig[event][vecSpawn_pos], ent[14+4*i]);
								
					ent[14+4*i][0] +=  rad * Cosine(PI * i/ 2);
					ent[14+4*i][1] +=  rad * Sine(PI * i/ 2);
					
					ent[14+4*i+1] = ent[14+4*i];
					ent[14+4*i+1][2] += 72.0;
					
					ent[14+4*i+2] = ent[14+4*i];
					ent[14+4*i+2][2] += 72.0*3.0/4.0;
					ent[14+4*i+3] = ent[14+4*i+2];
					
					ent[14+4*i+2][0] -= 40.0*Cosine( PI * float(i)/2.0);
					ent[14+4*i+2][1] -= 40.0*Sine(PI * float(i)/2.0);
					
					
					
				}
				
				for (int i=0; i<(30-12)/2; i++)
					DrawTempBeam(delay, ent[12+2*i], ent[12+2*i+1],"255 255 255");
				
				
				// draw teleout point
				MemberToVec(g_eventConfig[event][vecTeleOut_pos], ent[8]);
				MemberToVec(g_eventConfig[event][vecTeleOut_pos], ent[9]);
				MemberToVec(g_eventConfig[event][vecTeleOut_pos], ent[10])
				ent[9][2]+=72.0;
				
				ent[10][2]+=72.0*3.0/4.0;
				
				ent[11] = ent[10];
				
				MemberToVec(g_eventConfig[event][vecTeleOut_dir], vec);
				ent[11][0] += 40.0*Cosine(vec[1] * PI/180.0) * Cosine(vec[0] * PI/180.0);
				ent[11][1] += 40.0*Sine(vec[1] * PI/180.0) * Cosine(vec[0] * PI/180.0);
				ent[11][2] -= 40.0*Sine(vec[0] * PI/180.0);
				
				//DebugPrint(TeleOut_pos, TeleOut_dir)
				
				DrawTempBeam(delay, ent[8], ent[9], "128 128 0");
				DrawTempBeam(delay, ent[10], ent[11], "128 128 0");
				
				
				//draw beams from player to other points
				
				for (int i = sizeof(ent) - 18; i<sizeof(ent); i++)
					DrawTempBeam(delay/10.0, ent[i], entCl, "0 128 0");
				
				float specPos[3], specSize[3], specC[3];
				MemberToVec(g_eventConfig[event][vecSpectatorArea_pos], specPos);
				MemberToVec(g_eventConfig[event][vecSpectatorArea_size], specSize);
				
				//draw beams from player to spectator area origin
				DrawTempBeam(delay/10.0, specPos, entCl, "128 0 0");
				
				// 
				specC[1] = specPos[1] + specSize[1]/2;
				
				specC[0] = specPos[0] + specSize[0]/2;
				specC[2] = specPos[2] + specSize[2]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[2] = specPos[2] - specSize[2]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[0] = specPos[0] - specSize[0]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[2] = specPos[2] + specSize[2]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				
				specC[1] = specPos[1] - specSize[1]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[2] = specPos[2] - specSize[2]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[0] = specPos[0] + specSize[0]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				specC[2] = specPos[2] + specSize[2]/2;
				//DrawTempBeam(delay, specC, entCl, "255 0 0");
				
			}
			else
			{
				PrintToChat(client, "%s Invalid event index. 0<=i<=%d", PLUGIN_PREFIX, g_event_count-1);
			}
		}
		else
		{
			PrintToChat(client, "%s No events on this map", PLUGIN_PREFIX);
		}
	}
	else
	{
		PrintToChat(client, "%s Usage: /ct_show_loc <event index>", PLUGIN_PREFIX);
	}
	return Plugin_Handled;
}



public Action testtest(int client, int args)
{
	
	//draw temp beam at client's pos
	//float pos[3], pos2[3];
	//GetClientAbsOrigin(client, pos);
	//GetClientAbsOrigin(client, pos2);
	//pos[2] += 70.0;
	//DrawTempBeam(10.0, pos, pos2, "0 128 0");
	
	//	print loaded data
	//	PrintEventConfig(1);
	
	// get client's color
	//char col[64];
	//GetClientInfo(client, "vs_color", col, 64);
	//PrintToChat(client, "%s Your color is %s", PLUGIN_PREFIX, col);

	// print int
	//PrintToChat(client, "MaxClients = %d", MaxClients); 
		
	if (args > 0)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		
		// abort event
		if (StrEqual(arg1, "reset"))
		{
			if (g_event < 0)
			{
				PrintToChat(client, "No event found");
			}
			else
			{
				PrintToSpectators("Aborting event");
				ResetEvent();
			}
		}
		// afk tests
		//else if (StrEqual(arg1, "afk"))
		//{
			// afk tests result: between 70 and 76 units
		//}
		// test safety trigger distance
		else if (StrEqual(arg1, "end"))
		{
			EndEvent();
		}		
		// test timer id generation 
		else if (StrEqual(arg1, "id"))
		{
			PrintToChat(client, "NewTimerId = %d", NewTimerId());
		}
		else if (StrEqual(arg1, "init"))
		{
			
			if (args > 1)
			{
				char arg2[32];
				GetCmdArg(2, arg2, sizeof(arg2));
			
				if ((StringToInt(arg2) >=0) && (StringToInt(arg2) < g_event_count))
				{
					InitEvent(StringToInt(arg2), client);
				}
				else
				{
					PrintToChat(client, "Invalid event index: %s", arg2);
				}
				

			}
			else
			{
				PrintToChat(client, "Invalid event index");
			}
		}
		//get ent className
		else if (StrEqual(arg1, "ent"))
		{
			
			if (args > 1)
			{
				char arg2[32];
				GetCmdArg(2, arg2, sizeof(arg2));
				
				if (IsValidEdict(StringToInt(arg2)))
				{
					char strName[50] = "-";
					GetEdictClassname(StringToInt(arg2), strName, sizeof(strName));
					
					float pos[3];
					GetEntPropVector(StringToInt(arg2), Prop_Data, "m_vecOrigin", pos);
					PrintToChat(client, "ent class = %s", strName);
					PrintToChat(client, "ent pos = %3.3f, %3.3f, %3.3f", pos[0], pos[1], pos[2]);
				}
				else
				{
					PrintToChat(client, "edict doesn't exist");
				}
			}
		}
		
		// join command (will be in /event menu)
		else if (StrEqual(arg1, "join"))
		{
			// IsInQueue != IsInEvent != IsInSpectatorArea
			
			
			//PrintToChat(client, "g_event = %d", g_event);
			
			// check if this command is allowed (should be in itemdraw_disable checks for menu)
			if (g_event < 0)// if no one chose any event yet
				return Plugin_Handled;
				
			//if ((g_bRoundStarted || (g_eventRound > 0)) && ("you cannot join after first round started" config param is 1))
			//	return Plugin_Handled;
		
			//PrintToChat(client, "g_playerData[client][IsInQueue] = %d", g_playerData[client][IsInQueue]);
			//PrintToChat(client, "g_playerData[client][IsInEvent] = %d", g_playerData[client][IsInEvent]);
		
			// if player is in queue or already in event
			if (g_playerData[client][IsInQueue] || g_playerData[client][IsInEvent])
				return Plugin_Handled;
			
			//PrintToChat(client, "AddPlayerToQueue(%d)", client);
			
			//add to queue (all player checks should be there)
			AddPlayerToQueue(client);
		}
		// force join another player
		else if (StrEqual(arg1, "fjoin"))
		{
			if (args > 1)
			{
				
				// debug only 
				if (g_event < 0)
					return Plugin_Handled;
				
				char arg2[32];
				GetCmdArg(2, arg2, sizeof(arg2));
				
				if (g_playerData[StringToInt(arg2)][IsInQueue] || g_playerData[StringToInt(arg2)][IsInEvent])
					return Plugin_Handled;
				
				AddPlayerToQueue(StringToInt(arg2));
			}
			else
			{
				PrintToChat(client, "%s Usage: /test fjoin <client>", PLUGIN_PREFIX);
			}
		}
		//add client to team
		else if (StrEqual(arg1, "add"))
		{
			if (args > 2)
			{
				char arg2[32];
				GetCmdArg(2, arg2, sizeof(arg2));
				char arg3[32];
				GetCmdArg(3, arg3, sizeof(arg3));
				
				AddPlayerToEvent(StringToInt(arg2),StringToInt(arg3), client);
				
				
			}
			else
			{
				PrintToChat(client, "%s Usage: /test add <client> <team>", PLUGIN_PREFIX);
			}
			
			PrintToConsole(client, "Players in queue: %d", g_queue_count);
			for (int i = 1; i <= MaxClients; i++)
				if (g_playerData[i][IsInQueue])
				{
					char tempStr[32];
					GetClientName(i, tempStr, 32);
					PrintToConsole(client, "%d  -  %s", i, tempStr);
				}
		}
		// start round by admin
		else if (StrEqual(arg1, "startround"))
		{
			StartTimer_RoundStart();
		}
		else
		{
			PrintToChat(client, "Unknown Command");
		}
	}
	return Plugin_Handled;
}

EndEvent()
{
	//EndEventConditions()
	//{
	if (g_event < 0)
		return;
	
	//if TDM?
	
	if (g_eventConfig[g_event][Teams] == 2)
	{
		if (g_eventScore[0] > g_eventScore[1])
		{
			PrintToSpectators("%s wins! Final score: %d-%d", g_teamName[0], g_eventScore[0], g_eventScore[1]);
		}
		else if (g_eventScore[0] < g_eventScore[1])
		{
			PrintToSpectators("%s wins! Final score: %d-%d", g_teamName[1], g_eventScore[0], g_eventScore[1]);
		}
		else
		{
			PrintToSpectators("Draw! Final score: %d-%d", g_eventScore[0], g_eventScore[1]);
		}
	}
	else
	{
		
	}
	//}
	
	ResetEvent();
}

bool AddPlayerToQueue(int client/*, int activator = -1*/)
{
	if (!IsValidClient(client))
		return false;
	
	if (IsInDuel(client))
	{
		PrintToChat(client, "%s Can't join while in duel", PLUGIN_PREFIX);
		return false;
	}
	if (g_playerData[client][IsInQueue])
	{	
		PrintToChat(client, "%s Already in queue", PLUGIN_PREFIX);
		return false;
	}
	if (g_playerData[client][IsInEvent])
	{
		PrintToChat(client, "%s Already in event", PLUGIN_PREFIX);
		return false;
	}
	
	g_playerData[client][IsInQueue] = 1;
	g_queue[g_queue_count] = client;
	g_queue_count++;
	
	///! default: player waits for next round. (there should be option to join instantly. example: Machine)
	g_playerData[client][IsOut] = 1;
	
	// if (first in queue)
	// check queue even if client's position > 0
	// for example: event could be waiting for N players to gather to split them into teams
	if (MoveQueue(client))
		PrintToChat(client, "%s Joined event queue, position: %d", PLUGIN_PREFIX, g_queue_count);
	
	return true;
}

// activator is for printing result of joining to event
bool MoveQueue(int activator = -1)
{
	// default settings for ffa: add everyone to event if round didn't start yet
	// -->  default settings for tdm (admin-mode): do nothing! admin or captains should clear queue themselves
	// default settings for tdm (auto-mode): add people to teams if queue length >= Teams
	
	// add every one to event
	if (g_queue_count > 0)
	{
		if (g_eventConfig[g_event][Teams] == 0) // one team is possible?.. we will see
		{
			// add everyone instantly
			for (int i = 0; i < g_queue_count; i++)
			{
				AddPlayerToEvent(g_queue[i], 0, activator);
			}
			return false; // no need to print anything more
		}
	}
	return true;
}

AddPlayerToEvent(int client, int team, int activator = -1)
{
	if (!IsValidClient(client))
	{
		PrintToActivator(activator, "Player is not available");
		return;
	}
	//else if (!g_playerData[client][IsInSpectatorArea])
	//{
	//	PrintToActivator(activator, "Player has left event area");
	//	return;
	//}
	else if (!g_playerData[client][IsInQueue])
	{
		PrintToActivator(activator, "Player is not in queue");
		return;
	}
	else if (g_playerData[client][IsInEvent])
	{
		PrintToActivator(activator, "Player is already joined");
		return;
	}
	
	
	g_playerData[client][IsInEvent] = 1;
	RemovePlayerFromQueue(client);
	
	// assign to team
	g_playerData[client][Team] = team;
	ApplyTeamColor(client);
	
	// hook spawn event
	SDKHook(client, SDKHook_SpawnPost, OnSpawn);
	
	//print
	char name[64];
	GetClientName(client, name, sizeof(name));
						
	if (g_eventConfig[g_event][Teams] == 0)
		PrintToSpectators("%s joined", name);
	else
		PrintToSpectators("%s joined %s", name, g_teamName[team]);
}

RemovePlayerFromQueue(int client)
{
	if (!g_playerData[client][IsInQueue])
		return;
	
	g_playerData[client][IsInQueue] = 0;
	
	bool found = false;
	for (int i = 0; i < g_queue_count; i++)
	{
		if (g_queue[i] == client)
			found = true;
	
		if (found && (i < g_queue_count - 1))
			g_queue[i] = g_queue[i+1];
	}
	
	g_queue_count--;
}

TeleportOut(int client)
{
	if ((g_event >=0) 
		&& IsValidClient(client))
	{
		if (IsPlayerAlive(client))
		{
			TeleportEntity(client, GetConfigVector(g_event, _:vecTeleOut_pos), GetConfigVector(g_event, _:vecTeleOut_dir), NULL_VECTOR);
		}
		else
		{
			//g_teleQueue[client] = 0; // teleout after spawn
		}
	}
}

TeleportOnRoundStart()
{
	// -1 means "starttp" = "none" for any gamemode
	if (g_eventConfig[g_event][StartTP] == -1)
		return;
	
	switch (g_eventConfig[g_event][Type])
	{
		case TDM:
		{
			if (g_eventConfig[g_event][StartTP] == 1)
			{
				///! smart mixed? 
				
				//PrintToSpectators("mixed tele");
				
				// dumb mixed for even teams (also not random)
				// get biggest team
				int biggestTeamCount = PlayersInTeam(0); 
				for (int i = 1; i < g_eventConfig[g_event][Teams]; i++)
				{	
					int num = PlayersInTeam(0);
					if (num > biggestTeamCount)
						biggestTeamCount = num;
				}
				// so there are biggestTeamCount*Teams number of places for players
				
				//PrintToSpectators("biggestTeamCount = %d", biggestTeamCount);
				
				// prepare vars
				float vecCenter[3];
				float vecResult[MAXPLAYERS][3];
				float radius = g_eventConfig[g_event][fSpawn_radius];
				MemberToVec(g_eventConfig[g_event][vecSpawn_pos], vecCenter);
				float vecDir[MAXPLAYERS][3];
				for (int i = 0; i < g_eventConfig[g_event][Teams]; i++)
				{
					vecDir[i][0] = 10.0;
					vecDir[i][1] = 0.0;
					vecDir[i][2] = 0.0;
				}
				float phi;
				
				int lastteleported[TeamColor:COUNT] = {0, ...};
				
				// write to vecResult and vecDir
				for (int i = 0; i < biggestTeamCount*g_eventConfig[g_event][Teams]; i++)
				{
					phi = 2*PI*i/(biggestTeamCount*g_eventConfig[g_event][Teams]);
					vecResult[i][0] = vecCenter[0] + radius * Cosine(phi);
					vecResult[i][1] = vecCenter[1] + radius * Sine(phi);
					vecResult[i][2] = vecCenter[2];
					
					vecDir[i][1] = 360.0 * i/(biggestTeamCount*g_eventConfig[g_event][Teams]) + 180.0;
					
					int team = i%g_eventConfig[g_event][Teams];
					
					//PrintToSpectators("i = %d, team = %d", i, team);
					
					bool teleported = false;
					if (lastteleported[team] < MaxClients)
						for (int client = lastteleported[team] + 1; client <= MaxClients; client++)
							if (g_playerData[client][IsInEvent] && (g_playerData[client][Team] == team))
							{
								TeleportEntity(client, vecResult[i], vecDir[i], NULL_VECTOR);
								teleported = true;
								lastteleported[team] = client;
								break;
							}
					
					// if no one found ==> no point to look next time. disable this team
					if (!teleported)
						lastteleported[team] = MaxClients;
					//PrintToSpectators("vecResult[%d] = (%3.3f, %3.3f, %3.3f)", i, vecResult[i][0], vecResult[i][1], vecResult[i][2]);
					
				}
			}
			else
			{
				//default is "teams"
				//circle is same as ffa's but for teams
				
				// Step One: prepare teams' positions!
				
				// prepare vars
				float vecCenter[3];
				float vecResult[TeamColor:COUNT][3];
				float radius = g_eventConfig[g_event][fSpawn_radius];
				MemberToVec(g_eventConfig[g_event][vecSpawn_pos], vecCenter);
				float vecDir[TeamColor:COUNT][3];
				
				
				//PrintToSpectators("vecCenter = (%3.3f, %3.3f, %3.3f)", vecCenter[0], vecCenter[1], vecCenter[2]);
				//PrintToSpectators("radius = %3.3f", radius);
				
				for (int i = 0; i < g_eventConfig[g_event][Teams]; i++)
				{
					vecDir[i][0] = 10.0;
					vecDir[i][1] = 0.0;
					vecDir[i][2] = 0.0;
				}
				float phi;
				
				// write to vecResult and vecDir
				for (int i = 0; i < g_eventConfig[g_event][Teams]; i++)
				{
					
					phi = 2*PI*i/g_eventConfig[g_event][Teams];
					vecResult[i][0] = vecCenter[0] + radius * Cosine(phi);
					vecResult[i][1] = vecCenter[1] + radius * Sine(phi);
					vecResult[i][2] = vecCenter[2];
					
					vecDir[i][1] = 360.0 * i/g_eventConfig[g_event][Teams] + 180.0;
					
					//PrintToSpectators("vecResult[%d] = (%3.3f, %3.3f, %3.3f)", i, vecResult[i][0], vecResult[i][1], vecResult[i][2]);
					
				}
				for (int i = 1; i <= MaxClients; i++)
					if (IsValidClient(i) && g_playerData[i][IsInEvent] && IsPlayerAlive(i))
						TeleportEntity(i, vecResult[g_playerData[i][Team]], vecDir[g_playerData[i][Team]], NULL_VECTOR);
			}
				
		}
		case FFA:
		{
			
			//default: circle
			// Step One: count available players
			int counter = 0;
			for (int i = 1; i <= MaxClients; i++)
				if (IsValidClient(i) && g_playerData[i][IsInEvent] && IsPlayerAlive(i))
					counter++;
				
			if (counter <= 0)
				return;
			
			// Step Two: teleport!
			// prepare vars
			int j = 0;
			float vecCenter[3];
			float vecResult[3];
			float radius = g_eventConfig[g_event][fSpawn_radius];
			MemberToVec(g_eventConfig[g_event][vecSpawn_pos], vecCenter);
			float vecDir[3] = {10.0, 0.0, 0.0};
			float phi;

			for (int i = 1; i <= MaxClients; i++)
				if (IsValidClient(i) && g_playerData[i][IsInEvent] && IsPlayerAlive(i))
				{
					phi = 2*PI*j/counter;
					vecResult[0] = vecCenter[0] + radius * Cosine(phi);
					vecResult[1] = vecCenter[1] + radius * Sine(phi);
					vecResult[2] = vecCenter[2];
					
					vecDir[1] = 360.0 * j/counter + 180.0;
					TeleportEntity(i, vecResult, vecDir, NULL_VECTOR);
					j++;
				}
		}
	}
}

public Action Timer_EventStep(Handle timer)
{
	// if event is in progress (rounds and between rounds)
	///////////////////////////////////////////////////
	if (g_event < 0)
		return Plugin_Stop;
	
	// force team colors
	ForceTeamColors();
	
	// if round is in progress 
	///////////////////////////////////////////////////
	if (!g_bRoundStarted)
		return Plugin_Continue;
	
	// kill players outside of arena
	KillLeavers();
	
	return Plugin_Continue
}

KillLeavers()
{
	// if ( eventConfig[KillLeavers] )
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i) && g_playerData[i][IsInEvent] && !g_playerData[i][IsOut])	
				if (!IsInMainArena(i))
					ClientCommand(i, "kill");
}

bool IsInMainArena(int client)
{
	if (!IsValidClient(client)) // checking 2 times? hmm..
		return false;
		
	float posP[3], posA[3];
	
	// get player's position
	GetClientAbsOrigin(client, posP);
	
	// get arena pos
	MemberToVec(g_eventConfig[g_event][vecMainArena_pos], posA);
	
	if (g_eventConfig[g_event][MainArena_shape] == 0) // rect
	{
		// get arena size
		float size[3];
		MemberToVec(g_eventConfig[g_event][vecMainArena_size], size);
		
		for (int i = 0; i < 2; i++)
			if ((posP[i] < posA[i] - size[i]/2) || (posP[i] > posA[i] + size[i]/2))
				return false;
	}
	else if (g_eventConfig[g_event][MainArena_shape] == 1) // circle
	{
		return (DistanceXY(posP, posA) <= g_eventConfig[g_event][fMainArena_radius]);
	}
	return true;
}

ForceTeamColors()
{
	if (g_eventConfig[g_event][Teams] > 0)
		for (int i = 1; i <= MaxClients; i++)
		{
			ApplyTeamColor(i);
		}
}

public Action OnClientCommand(int client, int args)
{
	//block duelling for participants	
	if( g_playerData[client][IsInSpectatorArea])
	{
		new String:cl_cmd[16];
		GetCmdArg(0, cl_cmd, sizeof(cl_cmd));
		if( StrEqual(cl_cmd, "vs_challenge", false) )
		{
			PrintToActivator(client, "Can't duel in this area.");
			return Plugin_Handled;
		}
	}
	// this isn't pretty but
	else if (g_playerData[client][IsInQueue] 
		|| g_playerData[client][IsInEvent])
	{
		new String:cl_cmd[16];
		GetCmdArg(0, cl_cmd, sizeof(cl_cmd));
		if( StrEqual(cl_cmd, "vs_challenge", false) )
		{
			PrintToActivator(client, "Can't duel here. Use /event menu to leave event.");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

PlayFightSound()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i))
			if ((g_playerData[i][IsInSpectatorArea]) 
				|| (g_playerData[i][IsInEvent])
				|| (g_playerData[i][IsInQueue]))
			{
				ClientCommand(i, "play %s", g_sFightSound);
			}
}

PlayRoundSound(int round)
{
	int soundI = -1;
	// "final round!"
	if (round == g_eventConfig[g_event][RoundLimit] - 1)
	{
		soundI = sizeof(g_sRoundSound) - 1;
	}
	// rounds from 1 to 8
	else if ((round >=0) && (round < 9))
	{
		soundI = round;
	}
	
	if (soundI >= 0)
		for (int i = 1; i <= MaxClients; i++)
			if (IsValidClient(i))
				if ((g_playerData[i][IsInSpectatorArea]) 
					|| (g_playerData[i][IsInEvent])
					|| (g_playerData[i][IsInQueue]))
				{
					char cmd[64];
					Format(cmd, sizeof(cmd), "play %s", g_sRoundSound[soundI]);
					ClientCommand(i, cmd);
				}
	
}

int NewTimerId()
{
	// note to self: this is no longer random, IDs can't be equal for different timers anymore
	// note to self #2: damn, still keep coming here to make it more random... get out of here!
	static int id = 0;
	id++;
	if (id > 30000)
		id = 0;
	return id;
}

StartTimer_AutoTimer(AutoTimer:timerType)
{
	// generate id for timer (we must know if timer restarted or something)
	int id = NewTimerId();
	// create timer
	g_autotimer = _:CreateTimer(Wait:EnoughInQueue, FireTimer_AutoTimer, id, TIMER_FLAG_NO_MAPCHANGE);
	g_autotimerId = id;
	g_autotimerType = AutoTimer:timerType;
}

public Action FireTimer_AutoTimer(Handle timer, any:timerId)
{	
	// event aborted
	if (g_event <= 0)
		return Plugin_Stop;
	
	// check if everyone still waiting for THIS timer
	PrintToServer("DEBUG: g_autotimer = %d, timer = %d, id = %d", g_autotimer, _:timer, timerId);
	if ((g_autotimer != _:timer) || (g_autotimerId != timerId))
		return Plugin_Stop;
	
	// we need to reset autotimer in this procedure, but we can't make it after switch-case, because some of cases should start new autotimers
	// so we are storing its type and reseting it here
	new AutoTimer:tempType = g_autotimerType;
	ResetAutoTimer();
	
	switch (tempType)
	{
		case (AutoTimer:EnoughInQueue):
		{
			// no people in queue ==> aborting event
			PrintToSpectators("Aborting event: not enough people in queue");
			ResetEvent(); // <- this also resets autotimer; but its alright
		}
		default: // NONE
		{
			// right id but timerType is NONE? something went wrong!
			PrintToServer("[Events] FireTimer_AutoTimer's g_autotimerType == NONE");
		}
	}
	
	return Plugin_Stop;
}