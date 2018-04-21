	
// todo:
// [test] Защита от внешних атак
// [test] задать границы карты для каждой из них
// [test] антисюрикен
// [test en] перевод на русский
// уменьшение количества вершин вместе с цветом (для этого надо менять цели лучей, как это сделать?)

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_PREFIX "\x03[CM]\x01"

public Plugin myinfo = 
{
	name = "cm",
	author = "Crystal",
	description = "laser circle",
	version = "0.1",
	url = ""
};

//////////////////////////////////
//								//
//		Const and Params		//
//								//
//////////////////////////////////

#define PI 3.1415926535897932384626433832795

// число вершин для каждой стадии
#define VERTEX_GREEN 128
#define VERTEX_ORANGE 64
#define VERTEX_RED 32

// расстояния для переключения цветов (множитель от стартового)
#define RADIUS_ORANGE 700.0
#define RADIUS_RED 200.0

// константы, отвечающие за скорость движения
#define SPEED_TICKRATE 10.0
#define SPEED_GREEN_RANGE 200.0
#define SPEED_ORANGE_RANGE 200.0
#define SPEED_RED_RANGE 10.0

// время на возвращение в круг
#define ALERT_GREEN 10.0
#define ALERT_ORANGE 2.0
#define ALERT_RED 0.5

//////////////////////////
//						//
//		Global Vars		//
//						//
//////////////////////////

// заданы ли параметры для этой карты
bool g_bMapIsCorrect;

//Максимальная высота для проецирования лучей
float g_maxTRHeight;

// высота админа на старте ивента
float g_adminPos[3];

// текущий радиус
float g_radius;

// массив для хранения лазеров
int g_entBeams[VERTEX_GREEN][5]; // для каждой вершины у нас 5 лучей. 2 из них стоят на верхней и нижней вершине

// стандарт
int g_gameState; //0 - 0, 1 - зелёный цвет, 2 - оранжевый, 3 - красный
int g_players[MAXPLAYERS+1]; // 0 - не участвует, 1 - участвует, не получал предупреждений; 2 - участвует, получил предупреждение;

// тот, кто всё это начал
int g_admin;

// главный таймер
Handle g_timer;

// текущее число вершин
int g_vertexNum;

// таймеры предупреждений для каждого игрока
Handle g_alertTimer[MAXPLAYERS+1];

// стартовый радиус
float g_radiusStart;

// время на возврат в круг
float g_alertTime;

// порядок смертей
int g_playerScore[MAXPLAYERS+1];

// счётчик смертей
int g_deathOrder;

// номер триггера для защиты от сюрикенов
int g_antiShuri;

// координаты для браша-антисюрикена
float g_asOrigin[3], g_asSize[3];

// границы карты (если нет явной коробки, то минимальная, вмещающая всю карту, хоть и нет смысла в ней)
float g_mapMaxBounds[3];
float g_mapMinBounds[3];

// шаг основного таймера
float g_tickRate;

//////////////////////////
//						//
//		Plugin Init		//
//						//
//////////////////////////

public OnPluginStart() 
{	
	LoadTranslations("br.phrases");
	
	RegAdminCmd("brstart", StartEvent, ADMFLAG_RCON);
	//RegConsoleCmd("brstart", StartEvent);
	RegAdminCmd("trtest", trtest, ADMFLAG_RCON);
	RegAdminCmd("test", test, ADMFLAG_RCON);
	
	RegAdminCmd("brreset", reset, ADMFLAG_RCON);
	
	
	
	HookEvent("player_death", PlayerDeathEvent);
}

public OnMapStart()
{
	// Laser Texture
	PrecacheModel("materials/particle/dys_beam_big_rect.vmt");
	
	g_bMapIsCorrect = LoadMap();
	
	ResetEvent();
}

bool LoadMap()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	if (StrEqual(mapName, "free_docks", false))
	{
		g_maxTRHeight = 670.0;
		g_radiusStart = 3000.0;
		g_asOrigin = {1168.0, 612.0, 434.0};
		g_asSize = {5597.0, 4681.0, 868.0};
		g_mapMaxBounds = {5130.0, 10501.0, 1128.0};
		g_mapMinBounds = {-3290.0, -3435.0, -816.0};
		
		return true;
	}
	else if (StrEqual(mapName, "free_district", false))
	{
		// todo
	}
	return false;
}


ResetEvent()
{	
	g_gameState = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			SDKUnhook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		
		g_players[i] = 0;
		g_playerScore[i] = -1;
		if (g_alertTimer[i] != INVALID_HANDLE)
		{
			KillTimer(g_alertTimer[i]);
			g_alertTimer[i] = INVALID_HANDLE;
		}
	}
	
	if (g_timer != INVALID_HANDLE)
	{
		KillTimer(g_timer);
		g_timer = INVALID_HANDLE;
	}
	
	for (int i = 0; i < VERTEX_GREEN; i++)
		for (int j = 0; j < 5; j++)
			RemoveEntity(g_entBeams[i][j]);
		
	if (g_antiShuri > MAXPLAYERS)
		RemoveEntity(g_antiShuri);
	g_antiShuri = -1;
	
	
}
//////////////////////////
//						//
//		Start Command	//
//						//
//////////////////////////
public Action StartEvent(int client, int args)
{
	if (!g_bMapIsCorrect)
		return Plugin_Handled;
	
	if (g_gameState > 0)
		return Plugin_Handled;
	
	g_admin = client;
	g_gameState = 1;
	g_radius = g_radiusStart;
	GetClientAbsOrigin(client, g_adminPos);
	g_vertexNum = VERTEX_GREEN;
	g_alertTime = ALERT_GREEN;
	g_tickRate = SPEED_TICKRATE;
	
	
	float vec[3];

	g_antiShuri = CreateBrush(3, g_asOrigin, g_asSize);
	HookSingleEntityOutput(g_antiShuri, "OnStartTouch", AntiShuriTouch, false);
	
	// собираем игроков
	g_deathOrder = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			if (!IsInDuel(i))
				if (IsPlayerAlive(i))
				{
					g_players[i] = 1;
					SetEntData(i, FindDataMapOffs(i, "m_iHealth"), 1, 4, true);
					g_deathOrder++;
					SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
				}
	}
	
	
	//Сначала создаём индексы 0 и 1 - те, что будут геометрическими вершинами.
	GetVertexPos(vec, 0, 0, VERTEX_GREEN);
	g_entBeams[0][0] = CreateBeamEnt(vec, "0 200 0");
		
	//////////////////////////
	GetVertexPos(vec, 1, 0, VERTEX_GREEN);
	g_entBeams[0][1] = CreateBeamEnt(vec, "0 200 0");
	ActivateBeamEnt(g_entBeams[0][0], g_entBeams[0][1],  g_entBeams[0][0]);		
			
	for (int i = 1; i < VERTEX_GREEN; i++)
	{
		
		
		GetVertexPos(vec, 0, i, VERTEX_GREEN);
		g_entBeams[i][0] = CreateBeamEnt(vec, "0 200 0");
		ActivateBeamEnt(g_entBeams[i-1][1], g_entBeams[i][0],  g_entBeams[i-1][1]);		
					
		GetVertexPos(vec, 1, i, VERTEX_GREEN);		
		g_entBeams[i][1] = CreateBeamEnt(vec, "0 200 0");
		ActivateBeamEnt(g_entBeams[i][0], g_entBeams[i][1],  g_entBeams[i][0]);		
		
	}
	ActivateBeamEnt(g_entBeams[VERTEX_GREEN - 1][1], g_entBeams[0][0],  g_entBeams[VERTEX_GREEN - 1][1]);		
	
	
	//Далее добавляем остальные лучи
	for (int i = 0; i < VERTEX_GREEN; i++)
	{
		for (int j = 2; j < 5; j++)
		{
			g_entBeams[i][j] = CreateBeamEnt({0.0, 0.0, 0.0}, "0 200 0");
		}
		
	}
	for (int i = 1; i < VERTEX_GREEN; i++)
	{
		ActivateBeamEnt(g_entBeams[i][2], g_entBeams[i-1][0],  g_entBeams[i][0]);		
		ActivateBeamEnt(g_entBeams[i][3], g_entBeams[i-1][1],  g_entBeams[i][1]);		
		ActivateBeamEnt(g_entBeams[i][4], g_entBeams[i-1][0],  g_entBeams[i][1]);		
		
	}
	ActivateBeamEnt(g_entBeams[0][2], g_entBeams[VERTEX_GREEN-1][0],  g_entBeams[0][0]);
	ActivateBeamEnt(g_entBeams[0][3], g_entBeams[VERTEX_GREEN-1][1],  g_entBeams[0][1]);
	ActivateBeamEnt(g_entBeams[0][4], g_entBeams[VERTEX_GREEN-1][0],  g_entBeams[0][1]);
	
	//PrintToServer("{BR} <timerstrt> Current Radius = %3.3f", g_radius);
	g_timer = CreateTimer(g_tickRate, Timer_Tick, _, TIMER_REPEAT);
	
	return Plugin_Handled;
}


//////////////////////////
//						//
//		Circle Steps	//
//						//
//////////////////////////
public Action Timer_Tick(Handle timer)
{

	if (g_gameState == 1)
	{
		if (g_radius <= RADIUS_ORANGE)
		{
			SwitchToOrange();
		}
		else
		{
			g_radius -= SPEED_GREEN_RANGE;
		}
	}
	else if (g_gameState == 2)
	{
		if (g_radius <= RADIUS_RED)
		{
			SwitchToRed();
		}
		else
		{
			g_radius -= SPEED_ORANGE_RANGE;
		}
	}
	else
	{
		g_radius -= SPEED_RED_RANGE;
	}
	
	if (g_radius <= 0.0)
	{
		//KillTimer(g_timer);
		//g_timer = INVALID_HANDLE;
		//return Plugin_Stop;
	}
	else
	{
		MoveCircle();
	}
	return Plugin_Continue;
}

void MoveCircle()
{
	float vec[3];
	
	for (int i = 0; i < g_vertexNum; i++)
	{
		GetVertexPos(vec, 0, i, g_vertexNum);
		TeleportEntity(g_entBeams[i][0], vec, NULL_VECTOR, NULL_VECTOR);
		GetVertexPos(vec, 1, i, g_vertexNum);
		TeleportEntity(g_entBeams[i][1], vec, NULL_VECTOR, NULL_VECTOR);
	}
}

void SwitchToOrange()
{
	g_alertTime = ALERT_ORANGE;
	g_radius -= SPEED_ORANGE_RANGE;
	g_gameState = 2;
	//
	
	for (int i = 0; i < VERTEX_GREEN; i++)
		for (int j = 0; j < 5; j++)
			SetEntityRenderColor(g_entBeams[i][j], 255, 128, 0);
		
	
}

void SwitchToRed()
{
	g_tickRate = 1.0;
	if (g_timer != INVALID_HANDLE)
		KillTimer(g_timer)
	g_timer = CreateTimer(g_tickRate, Timer_Tick, _, TIMER_REPEAT);
	
	g_alertTime = ALERT_RED;
	g_radius -= SPEED_RED_RANGE;
	g_gameState = 3;
	
	for (int i = 0; i < VERTEX_GREEN; i++)
		for (int j = 0; j < 5; j++)
			SetEntityRenderColor(g_entBeams[i][j], 255, 0, 0);
}

public OnGameFrame() 
{
	if (g_gameState > 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_players[i] == 1)
			{
				// игрок не получал предупреждения, но вышел за забор
				if (DistanceToCenter2d(i) > g_radius + 16.0)
				{
					g_players[i] = 2;
					//показываем предупреждение, запускаем таймер (если время < 1.0, то сразу убиваем)
					if (g_alertTime < 1.0)
					{
						ClientCommand(i, "kill");
					}
					else if (g_alertTimer[i] == INVALID_HANDLE)
					{
						PrintToChat(i, "%s %t", PLUGIN_PREFIX, "OutOfCircleAlert", g_alertTime);
						g_alertTimer[i] = CreateTimer(g_alertTime, Timer_Alert, i);
					}
				}
			}
			else if (g_players[i] == 2) 
			{
				// у игрока есть предупреждение, вошёл обратно в область
				if (DistanceToCenter2d(i) <= g_radius + 16.0)
				{
					g_players[i] = 1;
					//убиваем таймер
					if (g_alertTimer[i] != INVALID_HANDLE)
					{
						KillTimer(g_alertTimer[i]);
						g_alertTimer[i] = INVALID_HANDLE;
					}
				}
			}
			else if (g_players[i] == 0)
			{
				// игрок вообще не при чём, а что-то забыл в этой области
				if (DistanceToCenter2d(i) <= g_radius + 16.0)
				{
					//ClientCommand(i, "kill");
				}
			}
		}	
	}
}

public Action Timer_Alert(Handle timer, any:client)
{
	RemovePlayer(client);
	timer = INVALID_HANDLE;
}

void RemovePlayer(int client)
{
	if (g_players[client] > 0)
		if (IsValidClient(client))
			if (!IsInDuel(client))
			{
				g_playerScore[client] = g_deathOrder;
				char name[64];
				GetClientName(client, name, sizeof(name));
				PrintToChatAll("%s %t", PLUGIN_PREFIX, "OutOfCircleKill", name);
				ClientCommand(client, "kill");
			
			}
	
	g_players[client] = 0;
	g_deathOrder--;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	if (g_alertTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_alertTimer[client]);
		g_alertTimer[client] = INVALID_HANDLE;
	}
	
		// если это последний игрок, то завершаем игру
				int num = 0;
				int lastplayer = -1;
				for (int i = 1; i <= MaxClients; i++)
					if (g_players[i] > 0)
						if (IsValidClient(i))
							if (IsPlayerAlive(i))
								if (!IsInDuel(i))
									num++;
				
				if (num == 1) 
				{
					if (IsValidClient(lastplayer))
						RemovePlayer(lastplayer);
				}
				else if (num <= 0)
				{
					PrintResults();
					ResetEvent();
				}
	
}

void PrintResults()
{
	int min = MAXPLAYERS * 2;
	int minI1st = -1;
	int minI2nd = -1;
	int minI3rd = -1;
	char name[64];
	
	//не сортируем результаты. нам нужна только первая тройка (это ужасно, но пусть пока будет так)
	
	// первое место:
	for (int i = 1; i <= MaxClients; i++)
		if ((g_playerScore[i] >= 0) && (g_playerScore[i] <= min))
		{
			minI1st = i;
			min = g_playerScore[i];
		}
		
	if (minI1st < 0)
		return;
	
	PrintToChatAll("%s %t", PLUGIN_PREFIX, "ResultsHead");
	GetClientName(minI1st, name, sizeof(name));
	PrintToChatAll("%s %t", PLUGIN_PREFIX, "Results1st", name);
	
	
	// второе
	min = MAXPLAYERS * 2;
	for (int i = 1; i <= MaxClients; i++)
		if ((g_playerScore[i] >= 0) && (g_playerScore[i] <= min) && (i != minI1st))
		{
			minI2nd = i;
			min = g_playerScore[i];
		}
		
	if (minI2nd < 0)
		return;
	
	GetClientName(minI2nd, name, sizeof(name));
	PrintToChatAll("%s %t", PLUGIN_PREFIX, "Results2nd", name);
	
	// третье
	min = MAXPLAYERS * 2;
	for (int i = 1; i <= MaxClients; i++)
		if ((g_playerScore[i] >= 0) && (g_playerScore[i] <= min) && (i != minI1st) && (i != minI2nd))
		{
			minI3rd = i;
			min = g_playerScore[i];
		}
		
	if (minI3rd < 0)
		return;
	
	GetClientName(minI3rd, name, sizeof(name));
	PrintToChatAll("%s %t", PLUGIN_PREFIX, "Results3rd", name);
}
//////////////////////////
//						//
//		Misc Logics		//
//						//
//////////////////////////

public OnClientDisconnect(client)
{
	if (g_players[client] > 0)
		RemovePlayer(client);

}

void GetVertexPos(float[] vec, int index2, int index, int ColorNum)
{
	float dirDown[3] = {90.0, 0.0, 0.0};

	float temp[3];
	temp[0] = g_adminPos[0] + g_radius * Sine(index * PI*2.0/ColorNum);
	temp[1] = g_adminPos[1] + g_radius * Cosine(index * PI*2.0/ColorNum);
		
	if ((index2 == 0) || (index2 == 2))
	{
		temp[2] = g_adminPos[2] + 70.0;
	}
	else 
	{
		temp[2] = g_maxTRHeight;
		
		TR_TraceRayFilter(temp, dirDown, MASK_ALL, RayType_Infinite, TraceRayFilter, g_admin); 
		if ( TR_DidHit())
		{
			TR_GetEndPosition(temp);
			temp[2] += 10.0
		}
		else
		{
			temp[2] = g_maxTRHeight;
		}
	}
	
	// после всего этого проверяем на границы (чтобы совсем диких значений не было)
	if (temp[0] < g_mapMinBounds[0])
	{
		temp[0] = g_mapMinBounds[0];
	}
	else if (temp[0] > g_mapMaxBounds[0])
	{
		temp[0] = g_mapMaxBounds[0];
	}
	if (temp[1] < g_mapMinBounds[1])
	{
		temp[1] = g_mapMinBounds[1];
	}
	else if (temp[1] > g_mapMaxBounds[1])
	{
		temp[1] = g_mapMaxBounds[1];
	}
	if (temp[2] < g_mapMinBounds[2])
	{
		temp[2] = g_mapMinBounds[2];
	}
	else if (temp[2] > g_maxTRHeight)
	{
		temp[2] = g_maxTRHeight;
	}
	
	//всё:
	vec[0] = temp[0];
	vec[1] = temp[1];
	vec[2] = temp[2];

}

public bool TraceRayFilter(entity, mask, any:data)
{
    if ((entity == data) || IsValidClient(entity))
        return false;
	return true;
}

float DistanceToCenter2d( int client)
{
	float vec[3];
	GetClientAbsOrigin(client, vec);
	return SquareRoot( (g_adminPos[0] - vec[0]) *(g_adminPos[0] - vec[0]) + (g_adminPos[1] - vec[1]) * (g_adminPos[1] - vec[1]) ); 
}

public Action:PlayerDeathEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	//get victim
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_players[victim] > 0)
		RemovePlayer(victim);
}

public AntiShuriTouch(const String:output[], caller, activator, Float:delay)
{
	if (activator > 32)
	{
		char name[32];
		GetEdictClassname(activator, name, sizeof(name));
		
		if (StrEqual(name, "berimbau_throwable"))
		{
			RemoveEntity(activator);
		}
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{		
	if (g_gameState > 0)
	{
		if ((IsValidClient(attacker)) && (IsValidClient(victim)))
		{
			if (IsInDuel(attacker))
				RemovePlayer(attacker);
			
			if (IsInDuel(victim))
				RemovePlayer(victim);
			
			//блокируем урон между участником и не-участником
			if (g_players[attacker] != g_players[victim])
				return Plugin_Handled;

		}
	}		
	return Plugin_Continue;
}

//////////////////////////
//						//
//		Basic			//
//						//
//////////////////////////
int CreateBeamEnt(float[] pos, char[] color)
{
	float vec[3];
	vec[0] = pos[0];
	vec[1] = pos[1];
	vec[2] = pos[2]; // <-  тупость какая-то, но пусть пока будет так
	
	
		int ent = CreateEntityByName( "env_beam" );
		SetEntityModel( ent, "materials/particle/dys_beam_big_rect.vmt" );
						
		DispatchKeyValue( ent, "rendermode", "0" );
					
						
		DispatchKeyValue( ent, "renderamt", "100" );
		DispatchKeyValue( ent, "rendermode", "0" );
		DispatchKeyValue( ent, "rendercolor", color );  
		DispatchKeyValue( ent, "life", "0" ); 
		
		TeleportEntity( ent, vec, NULL_VECTOR, NULL_VECTOR ); 
						
		DispatchSpawn(ent);
		SetEntProp( ent, Prop_Send, "m_nNumBeamEnts", 2);
		SetEntProp( ent, Prop_Send, "m_nBeamType", 2);
						
		SetEntPropFloat( ent, Prop_Data, "m_fWidth",  3.0 );
		SetEntPropFloat( ent, Prop_Data, "m_fEndWidth", 3.0 );

	return ent;
}

void ActivateBeamEnt(int beam, int start, int end)
{
		SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(start) );
		SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(end), 1 );
		ActivateEntity(beam);
		AcceptEntityInput(beam,"TurnOn");	
}

bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}

bool IsInDuel(int client)
{
	if(!IsClientInGame(client))
	{
		return false;
	}
	
	int g_DuelState[MAXPLAYERS+1];
	int m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	int ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
	{
		return true;
	}
	
	return false;
}

RemoveEntity(entity)
{
	if (entity > 32)
	{
		if (IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "Deactivate");
			AcceptEntityInput(entity, "Kill");
		}
	}
}
int CreateBrush(int entType, float vecPos[3],/* float vecDir[3],*/ float size[3])
{
	// *CreateInvisibleBrush	
	int ent;
	if (entType == 1) // trigger_hurt for Doom Bridge
	{
		ent = CreateEntityByName("trigger_hurt");
			
		DispatchKeyValue(ent, "spawnflags", "1"); 
		DispatchKeyValue(ent, "wait", "0.0");
		DispatchKeyValue(ent, "damage", "1000");
		DispatchKeyValue(ent, "damagecap", "2000");
		DispatchKeyValue(ent, "nodmgforce", "1");
	}
	else if (entType == 2) // trigger_multiple //
	{
		ent = CreateEntityByName("trigger_multiple");
		
		DispatchKeyValue(ent, "spawnflags", "1"); 
		DispatchKeyValue(ent, "wait", "0.0");
	}
	else if (entType == 3)  // trigger_multiple for shuris
	{
		ent = CreateEntityByName("trigger_multiple");
		
		DispatchKeyValue(ent, "spawnflags", "1103"); 
		DispatchKeyValue(ent, "wait", "0.0");
	}
	else if (entType == 0)//func_brush for invisible wall
	{
		ent = CreateEntityByName("func_brush");
	}
	
	if (ent > MAXPLAYERS)
	{
		
		
		DispatchSpawn(ent);
		ActivateEntity(ent);
		TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
		//TeleportEntity(ent, NULL_VECTOR, vecDir, NULL_VECTOR);  //not working:(
		
		SetEntityModel(ent, "models/extras/info_speech.mdl");
		
		float minBounds[3]; 
		float maxBounds[3];
		for (int i; i < 3; i++)
		{
			maxBounds[i] = size[i]/2.0;
			minBounds[i] = -maxBounds[i];
		}
		SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
		SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
		
		SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
		
		int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
		enteffects |= 32;
		SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	}
	return ent;
}
//////////////////////////
//						//
//		Tests			//
//						//
//////////////////////////
public Action trtest(int client, int args)
{
	char name[64];
	GetClientName(client, name, sizeof(name));
	PrintToServer("client = %s", name);
	PrintToChat(client, "%s %t", PLUGIN_PREFIX, "TestMessage", name, "<[My Server Name]>");
	
	
	char lang[64], code[64];
	GetLanguageInfo(GetClientLanguage(client), code, sizeof(code), lang, sizeof(lang)); 
	PrintToConsole(client, "lang #%d: <%s> <%s>", GetClientLanguage(client), code, lang )
}

public Action test(int client, int args)
{
	if (args > 1)
	{
		char arg[64];
		char arg2[64];
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		
		PrintToChat(client, "%s VecPos[%s,%s] = ", PLUGIN_PREFIX,  arg, arg2);
		
		float vec[3];
		GetVertexPos(vec, StringToInt(arg2), StringToInt(arg), VERTEX_GREEN);
		
		PrintToChat(client, "%s <%3.3f, %3.3f, %3.3f>", PLUGIN_PREFIX , vec[0], vec[1], vec[2]);
		
	}
}

public Action reset(int client, int args)
{
	ResetEvent();
}



























