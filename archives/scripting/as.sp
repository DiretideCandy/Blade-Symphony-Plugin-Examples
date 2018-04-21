//Text Search:

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>



#define TheName "Archimonde Says"	// game name:) this one is same minigame from wc3 map "Uther Party":)

#define CT_ATTACKID_BIAS 1			// explained below // +1 again!

/////////////////////////////////////////////
//const menu choices
// Master's Invitation menu
#define MENU_INVALL_TEXT ""
#define MENU_INVALL_1_NAME "#choice1"
#define MENU_INVALL_1_TEXT "Invite All!"
#define MENU_INVALL_2_NAME "#choice2"
#define MENU_INVALL_2_TEXT "Invite All in Radius 300"
#define INV_RANGE 300.0 //duel_box arena is 768x768
#define MENU_INVALL_3_NAME "#choice3"
#define MENU_INVALL_3_TEXT "Cancel"
// Player's Invite menu
#define MENU_INV_1_NAME "#choice10"
#define MENU_INV_1_TEXT "Accept!"
#define MENU_INV_2_NAME "#choice20"
#define MENU_INV_2_TEXT "No."
/////////////////////////////////////////////

//no rule sets: !only 1 game mode!

//TODO:

// high priority
//	- Make Replayable, 1 game at a time
//	- Add Vanguard
//	- heal Players and Players' victims
//	- get out command for kicking (Master's menu if more of them needed)
//	- leave command for players

// low priority
//	- all bad charge cases with texts
//	- Console Stats command (only stats for 1 player)
//	- new text on round end: "%s, %s, %s are leading" (print names of leaders)
//	- replace "Round N!" text with sound

// highest priority but...
//	- make everything like Elmo's ClientData? ( not a question:) )

////////////////////
// make convars
#define CT_ClientTime 20.0 //no decay! playing for points, not for speed (for now)
new Rule_RoundLimit = 10;			//[one and only Rule_ kv?] - number of rounds
////////////////////

new bool:GameEnabled;

new bool:LastRound = false;	// add comment
new Game_State;				// add comment

new Handle:Timer_Client;	// Timer for Players' answers


new CT_Master;				//Masta
new CT_Players[32];			//Players in Charges
new CT_PlayerCount;			//number of Players in Charges

new CT_THE_ATTACK;			// current Master's attack to guess
//new CT_THE_ATTACK_mem;

new CT_MasterState;			// Game State (Master) - defines preThink's variation
new CT_PlayerState[32];		// Game State (Player) - defines preThink's variation
new CT_PlayerAttack[32];			// Players' answers
//new CT_PlayerAttack_mem[32];		//
new CT_PlayerAttackNames[32+1][32] 	// 
new CT_PlayerPoints[32];	//
new CT_RoundNumber;			//
new debug_printed = 5;		// number of times to print new info in preThink

new RemainingPlayers;		// counter for invitations and/or answering players

new String:Aname[64];



public Plugin:myinfo =
{
	name = "[CT] Archimonde Says",
	author = "CT",
	description = "Simple guess-attack-by-charge-animation game",
	version = "0.1.0.0"
};


public OnPluginStart()
{	
	GameEnabled = false;

	Game_State = 0;
	
	//RegConsoleCmd("tests", tests);						//-debug- or something
	RegAdminCmd("sm_as_toggle", Toggle_AS, ADMFLAG_RCON);
	RegConsoleCmd("as_leave", leave);
	RegConsoleCmd("as_start", Menu_InvAll);			//start game
	RegAdminCmd("te", test, ADMFLAG_RCON);			//get attack name
	
	CT_MasterState = 0;
}

public Action:leave(client, args)
{
	
	if (Game_State>0)
	{
		RemovePlayer(client);
	}
	return Plugin_Handled;
}
public Action:Toggle_AS(client, args)
{
	GameEnabled = !GameEnabled;
	PrintToConsole(client, "Game_Enabled = %b", GameEnabled);
	
	return Plugin_Handled;
}

Game_Init()
{
	CT_PlayerCount = 0;
	LastRound = false;
	CT_RoundNumber = 1;
	CT_MasterState = 1;
	CT_THE_ATTACK = -1;			
	
	for(new i; i>MaxClients;i++)
	{
		CT_PlayerState[i] = 0;	
		CT_PlayerPoints[i] = 0;
	}

}


public OnClientDisconnect(client)
{
	if (Game_State>0)
	{
		RemovePlayer(client);
	}
}

StartGame()
{
	for (new i;i<MaxClients;i++)
	{	SDKUnhook(i, SDKHook_PreThink, hookPreThink_Charges);  }
	
	
	
		
		  
        PrintToChat(CT_Master, "\x04[CT]\x01 Welcome to <%s>!",TheName);
        PrintToChat(CT_Master, "\x04[CT]\x03 Round %d", CT_RoundNumber);
        PrintToChat(CT_Master, "\x04[CT]\x01 You are the Master! Charge something", CT_RoundNumber);
		SetEntProp(CT_Master, Prop_Send, "m_ActionId", 255);
		SetEntProp(CT_Master, Prop_Send, "m_bCharging", false);
		
		SDKHook(CT_Master, SDKHook_PreThink, hookPreThink_Charges);
		
				
		for(new i=0; i<CT_PlayerCount; i++)
        {
			SetEntProp(CT_Players[i], Prop_Send, "m_ActionId", 255);
			SetEntProp(CT_Players[i], Prop_Send, "m_bCharging", false);
			
			SDKHook(CT_Players[i], SDKHook_PreThink, hookPreThink_Charges);
						
			CT_PlayerState[i] = 0; 
			CT_PlayerAttack[i] = -1;
			CT_PlayerPoints[i] = 0;
			PrintToChat(CT_Players[i], "\x04[CT] \x01Welcome to <%s>!", TheName);
			PrintToChat(CT_Players[i], "\x04[CT] \x03Round %d", CT_RoundNumber);
        }
		
}



public hookPreThink_Charges(client)
{
	
	if (Game_State>0) // Game State <= 0 is when game is off
	{

     if (client == CT_Master)     
     {
          if (CT_MasterState == 1) // 1 = waiting for master to start charging
          {
               if (GetEntProp(client, Prop_Send, "m_bCharging"))
               {
                    CT_MasterState = 2; 
					//if (CT_THE_ATTACK<0)
					//{
						new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
						if (((ActId>13) && (ActId<255)) || ActId == 3)
						{
							//if (CT_THE_ATTACK != ActId) {PrintToServer("CT_THE_ATTACK->ActId (%d -> %d)", CT_THE_ATTACK , ActId);}
							CT_THE_ATTACK = ActId;
						}
						
					//}
                                        
               }
          }
          else if (CT_MasterState == 2) // 2 - Master is charging! let's see what happens
          {
			
               new everythingisawesome = false;  
			   //just a flag. 
			   //if player isn't charging anymore and it is still false then we don't know why charge was bad
			   //in theory it won't be needed when all text for bad charge cases are done
			   
               new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
               new Tier = GetEntProp(client, Prop_Send, "m_iTierIndex");
              
				if (((ActId>13) && (ActId<255)) || ActId == 3)
					CT_THE_ATTACK = ActId;
				
				
			  
               if (!(GetEntProp(client, Prop_Send, "m_bCharging")))
               {               
			   
		   //we don't print mistakes of master
		   //before grab-cancel he can do combo, charges, attacks, and then the grab-cancel
                    
					
					
                    //here is all kinds of charge stopping reasons
					// 'bad' is when you need to try again (actually, now only one reason is 'good')
                   
                    //feint(bad)
                    if (CT_THE_ATTACK == 3)
                    {
                         everythingisawesome = BadCharge(); 
						 //everythingisawesome is true because we know the reason why charge was bad
						 
                         //PrintToChat(client, "\x01This was \x03feint\x01! Use \x03real\x01 charges +\x03 grabs\x01 to cancel them.");
                    }
                   
                    //attack (bad)
                   
                   ///grab at t2(good) t2 = halfcharge here (i think some people use t0-t1-t2 for tiers, i use t1-t2-t3) 
				   //isn't here! grabs don't change m_bCharging o_O

					///[isn't here!]grab at t1 (bad)
                   
                    //[isn't here!]dash (bad)
                   
                    //disconnect (bad)
                   
                    //command /leave (bad)
                   
					// maybe something else is missing
				   
                    if (!everythingisawesome) 
                    {
						//we don't know the reason -> reset 
                         CT_MasterState = 1;
                         //PrintToChat(client, "Something went wrong! Retry pls.");
                    }
               }
               else if (ActId == 13)
               {
                    //grabs are here, because grabs don't change m_bCharging
                   
                    //grab after t2 (good)
                   
							//cancelling charge. some problems could be here
							// i think some problems are when player/master starts a game/round with m_bCharging = true (after grab for example)
                         SetEntProp(client, Prop_Send, "m_ActionId", 255);
                         SetEntProp(client, Prop_Send, "m_bCharging", false); 
						 
                         if (Tier == 1)
                         {
                              everythingisawesome = GoodCharge();  //yay!
                         }
                        
                    //grab after t1 (bad)
                         else if (Tier == 0)
                         {
							
							//if help is enabled...{
                                //PrintToChat(client, "\x01This wasn't charged attack! Use\x03 grab \x01 right after sparks effect.");
                            //}
							  everythingisawesome = BadCharge();
                              //CT_MasterState = 3;
                             
                         }
                        
                    //don't sure if this is needed here but:    
                    if (!everythingisawesome)
                    {
						
                         CT_MasterState = 1;
                         //PrintToChat(client, "Something went wrong! Retry plz.");
                    }
					
               }
               else if (ActId == 12)
               {
                    //dash:/
                   
               }
          
			
          }
          else if (CT_MasterState == 3) // 3 => good charge! waiting for others now
          {
               
          }
         
     }
     else // if this client is not a master
     {
          // need to remove this loop:(
          for (new i=0; i<CT_PlayerCount; i++)
          {
               if (client == CT_Players[i])
               {

						// most of it is copypaste from master
						
                    if (CT_PlayerState[i] == 1)  // // 1 = waiting for client to start charging
                    {
                         if (GetEntProp(client, Prop_Send, "m_bCharging"))
                         {
                              CT_PlayerState[i] = 2; 
                               
                   
							new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
							if (((ActId>13) && (ActId<255)) || ActId == 3)
							{
								//if (CT_PlayerAttack[i] != ActId) {PrintToServer("CT_PlayerAttack[i]->ActId (%d -> %d)", CT_THE_ATTACK , ActId);}
								CT_PlayerAttack[i] = ActId;
							}
				   
				   
                              //decl String:Pname[MAX_NAME_LENGTH];
                              //GetAttackName(CT_PlayerAttack[i], Pname);
                              //PrintToChat(client,"You charging %s Attack!! ",  Pname);
                         }
                    }
                    else if (CT_PlayerState[i] ==2) // 2 - charging!
                    {
						
                              // same cases
                   
                              new everythingisawesome = false;
                              new ActId = GetEntProp(client, Prop_Send, "m_ActionId");
                              new Tier = GetEntProp(client, Prop_Send, "m_iTierIndex");
              
			  
							if (((ActId>13) && (ActId<255)) || ActId == 3)
									CT_PlayerAttack[i] = ActId;
			  
                              if (!(GetEntProp(client, Prop_Send, "m_bCharging")))
                              {
                   
                                   //PrintToServer("m_ActionId = %d", ActId);
                                   //PrintToServer("m_iTierIndex = %d", Tier);
                   
                   
                                   //faint (bad)
                                   if (CT_PlayerAttack[i] == 3)
                                   {
                                        everythingisawesome = BadCharge_Player(i);
                                        PrintToChat(client, "\x04[CT] \x03Feint\x01! Use real charge and grab-cancel it between t2 and t3");
                                   }
                   
                                   //attack (bad)
                   
                                   //air(isn't it an 'attack'?) (bad)
                   
                                   //disconnet (bad)
                   
                                   //command /leave (bad)
                   
                                   //duel (bad)
                   
                                   //death (bad)
                   
                   
                                   if (!everythingisawesome)
                                   {
                                        CT_PlayerState[i] = 1; 
                                        //reset;
                                        //PrintToChat(client, "\x04[CT] \x01Something went wrong! You can retry.");
                                   }
                              }
                              else if (ActId == 13)
                              {
                                   //grabs here
                   
										// still errors here:(
										// i think some of them when player/master starts a game/round with m_bCharging = true (after grab for example)
										SetEntProp(client, Prop_Send, "m_ActionId", 255);
                                        SetEntProp(client, Prop_Send, "m_bCharging", false);
										
                                        //grab after t2 (good)
                                        if (Tier == 1)
                                        {
											
                                            //everythingisawesome = GoodCharge(); //GoodCharge() is for master only
											everythingisawesome = true;
                                        
										
											 CT_PlayerState[i] = 3; 
                                             RemainingPlayers--;
                                            
                                            // decl String:PGname[MAX_NAME_LENGTH];
                                             GetAttackName(CT_PlayerAttack[i],i);
                                             if (RemainingPlayers>0)
                                             {
                                                  PrintToChat(client, "\x04[CT] \x01Your answer is %s! Wait for other players...", CT_PlayerAttackNames[i]);
                                             }
                                             else
                                             {
                                                  PrintToChat(client, "\x04[CT] \x01Your answer is %s!", CT_PlayerAttackNames[i]);
                                                 
                                                  EndRound();
                                             }
                                        }
                        
                                   //grab after t1 (bad)
                                   else if (Tier == 0)
                                   {
										//if help then
                                        PrintToChat(client, "This wasn't charged attack! Use grab right after halfcharge effect.");
                                        //end if
										
										everythingisawesome = BadCharge_Player(i); // =true
                             
                                   }
                        
                        
                                   if (!everythingisawesome)
                                   {
                                        CT_PlayerState[i] = 1;  
                                        //reset
                                        //PrintToChat(client, "Something went wrong! You can retry.");
                                   }
                              }
                              else if (ActId == 12)
                              {
                                   //dash here
                   
                              }
                        //}    
                    }
                    else if (CT_PlayerState[i] ==3) // 3 - good charge! wait for other players
                    {
                   
                    }
               break;
			   }
			   
          }
     }
	}
}


EndRound()
{
	//PrintToServer("Killing Client's Timer");
	KillTimer(Timer_Client);
	
     //we know master's attack Id (CT_THE_ATTACK)
     //we  know players' attacks (CT_PlayerAttack[i]).
     //let's count winners!
    
    GetAttackName(CT_THE_ATTACK,32);
	
     new RightCount = 0;  // number of right people
     new LeftCount = 0;	 // number of not right people
     
	 for(new i=0; i<CT_PlayerCount; i++)
     {
          PrintToChat(CT_Players[i], "\x04[CT] \x01%s",  CT_PlayerAttackNames[32]);
         
		 //PrintToServer("CT_THE_ATTACK = %d, CT_PlayerAttack[%d] = %d", CT_THE_ATTACK, i, CT_PlayerAttack[i] );
          if (CT_THE_ATTACK == CT_PlayerAttack[i])
          {
               CT_PlayerPoints[i]++;
               PrintToChat(CT_Players[i], "\x04[CT] \x01You were right! You now have \x03%d\x01 points!", CT_PlayerPoints[i]);
              
               RightCount++;
          }
          else
          {
				if (CT_PlayerAttack[i] != -1)
				{
					
   				GetAttackName(CT_PlayerAttack[i],i);
               PrintToChat(CT_Players[i], "\x04[CT] \x01You were wrong! Your attack was %s", CT_PlayerAttackNames[i]);
              
				}
				else
				{
					PrintToChat(CT_Players[i], "\x04[CT] \x01Too slow!");
				}
               LeftCount++;
          }
     }
    
     //print stats to all (1 str is enough. rest should be in console)
    
     PrintToChat(CT_Master, "\x04[CT] \x03%d \x01were right and \x03%d \x01were wrong.", RightCount, LeftCount);
     for(new i=0; i<CT_PlayerCount; i++)
     {
          PrintToChat(CT_Players[i], "\x04[CT] \x03%d \x01were right and \x03%d \x01were wrong.", RightCount, LeftCount);
     }
       
		
	
	 if (LastRound)
	 {
		Game_Over();
	 }
	 else
	 {
		
		if (Rule_RoundLimit <= CT_RoundNumber+1)// i think this is bad code :)
		{
			LastRound = true;
		}
		
		CT_RoundNumber++;

	
		// 
		//CT_TIME_..._START 		//time at first round
		//CT_TIME_..._END 			//time at ENDATROUNDN round
		//CT_TIME_..._ENDATROUNDN 	//after this round time is constant
	
		/*  ! not needed ! we need simple plugin as quick as possible^^
		if ((CT_TIME_MASTER_ENDATROUNDN>1) && (CT_RoundNumber<=CT_TIME_MASTER_ENDATROUNDN))
		{
			if (CT_MasterTime>CT_TIME_MASTER_END+1.0)
			{
				CT_MasterTime += (CT_TIME_MASTER_END - CT_TIME_MASTER_START) / (CT_TIME_MASTER_ENDATROUNDN-1.0);
			}
			else if (CT_MasterTime>CT_TIME_MASTER_END)
			{
				CT_MasterTime = CT_TIME_MASTER_END;
			}	
		}
		if (CT_TIME_CLIENT_ENDATROUNDN>1)
		{
			if (CT_ClientTime>CT_TIME_CLIENT_END+1.0)
			{
				CT_ClientTime += (CT_TIME_CLIENT_END - CT_TIME_CLIENT_START) / (CT_TIME_CLIENT_ENDATROUNDN-1.0);
			}
			else if (CT_ClientTime>CT_TIME_CLIENT_END)
			{
			CT_ClientTime = CT_TIME_CLIENT_END;
			}	
		}*/
	
    NewRound();
    }

}




NewRound()
{
     CT_MasterState = 1;
     CT_THE_ATTACK = -1;
     for(new i=0; i<CT_PlayerCount; i++)
     {
          CT_PlayerState[i] = 0; 
          CT_PlayerAttack[i] = -1;
     }
    
     for(new i=0; i<CT_PlayerCount; i++)
     {
          PrintToChat(CT_Players[i], "\x04[CT] \x03Round %d", CT_RoundNumber);
     }
	 
	 PrintToChat(CT_Master, "\x04[CT]\x03 Round %d\x01. Charge Something!", CT_RoundNumber);
	 
}


BadCharge_Player(index)
{
     CT_PlayerState[index] = 1;
     CT_PlayerAttack[index] = -1; 
     //PrintToServer("Bad Charge by Player %d!", CT_Players[index]);
    
     return true;
}

BadCharge()//  BadCharge_Master()
{
     CT_MasterState = 1;
     CT_THE_ATTACK = -1;
     //PrintToServer("Bad Charge!");
    
     return true;
}

GoodCharge() //by Master
{
		
	
     CT_MasterState = 3;
	 
     GetAttackName(CT_THE_ATTACK, 32);
	 
     PrintToChat(CT_Master, "\x04[CT] \x01%s! Now wait for players to repeat it.", CT_PlayerAttackNames[32]);
    
     RemainingPlayers = CT_PlayerCount;
     for (new i=0; i<CT_PlayerCount; i++)
     {
          CT_PlayerState[i] = 1; 
    
          new String:mastername[MAX_NAME_LENGTH];
          GetClientName(CT_Master, mastername, MAX_NAME_LENGTH);
          PrintToChat(CT_Players[i], "\x04[CT] \x01%s charged an attack. Which one?", mastername);
     }
    
	//PrintToServer("Killing Client's Timer");
	Timer_Client = CreateTimer(CT_ClientTime, ClientAFK);
	
    return true;
}



Game_Over()
{
	
	if (CT_PlayerCount>1)
	{
		//sorting results for printing
		new r;
		for (new i;i<CT_PlayerCount-1;i++)
			for(new j=i+1;j<CT_PlayerCount;j++)
			{
				if (CT_PlayerPoints[i]>CT_PlayerPoints[j])
				{
					r= CT_PlayerPoints[i];
					CT_PlayerPoints[i] = CT_PlayerPoints[j];
					CT_PlayerPoints[j]=r;
					
					r = CT_Players[i];
					CT_Players[i] = CT_Players[j];
					CT_Players[j] = r;
				}
			}
	}
	
	PrintToChat(CT_Master, "\x04[CT] \x01Game Over!");
	SDKUnhook(CT_Master, SDKHook_PreThink, hookPreThink_Charges);
	if (CT_PlayerCount>0)
	{
		
		for(new i=0; i<CT_PlayerCount; i++)
		{
				SDKUnhook(CT_Players[i], SDKHook_PreThink, hookPreThink_Charges);
				//didn't test it at all 
				// before that used to hook empty hookPreThink_Tranquilty instead (didn't test it too)
				
				PrintToChat(CT_Players[i], "\x04[CT] \x01Game Over!");
					
		}
		
		for (new i;i<CT_PlayerCount;i++)
		{
			new String:plname[MAX_NAME_LENGTH];
			GetClientName(CT_Players[i] , plname, MAX_NAME_LENGTH);
			PrintToChat(CT_Master , "\x04[CT] \x01 %d Points: %s", CT_PlayerPoints[i],plname);
			
			for(new j=0; j<CT_PlayerCount; j++)
			{
				PrintToChat(CT_Players[j]  , "\x04[CT] \x01 %d Points: %s", CT_PlayerPoints[i],plname);
			}
		}
	}
	
	Game_State=0;
}



AddPlayer(client)
{
	CT_Players[CT_PlayerCount] = client
	CT_PlayerCount++;
}

RemovePlayer(client)
{
	// didn't use this yet => could be terribly wrong somewhere here
	
	new bool:found;
	new foundI;
	found = false;
	for (new i=0; i<CT_PlayerCount; i++)
	{
		//PrintToServer("CT_Players[%d] = %d, clieny = %d", i, CT_Players[i], client);
        if (CT_Players[i] == client)
        {
			
            found = true;
            foundI = i;
            break;
        }
    }
	//PrintToServer("found = %b", found);
    if (found)
	{
		SDKUnhook(CT_Players[foundI], SDKHook_PreThink, hookPreThink_Charges);
		if (foundI<CT_PlayerCount-1)
		{
			for (new i=foundI; i<CT_PlayerCount-1; i++)
			{
				CT_Players[i] = CT_Players[i+1];
				CT_PlayerState[i] = CT_PlayerState[i+1];
				CT_PlayerAttack[i] = CT_PlayerAttack[i+1];
				CT_PlayerPoints[i] =CT_PlayerPoints[i+1];

				   
			}
			
		}
			CT_PlayerCount--;
			RemainingPlayers--;
			
			if (CT_PlayerCount<1)
			{
				Game_Over();
			}
	}
    
	
}

public Action:ClientAFK(Handle:timer)
{
	
	KillTimer(Timer_Client);
	if (Game_State>0)
	{
		SetEntProp(CT_Master, Prop_Send, "m_ActionId", 255);
		SetEntProp(CT_Master, Prop_Send, "m_bCharging", false);
		
		//counting afk players here
		for (new i=0; i<CT_PlayerCount; i++)
		{
			if (CT_PlayerState[i]!=3)
			{
				SetEntProp(CT_Players[i], Prop_Send, "m_ActionId", 255);
				SetEntProp(CT_Players[i], Prop_Send, "m_bCharging", false);
				
		
				PrintToChat(CT_Players[i], "\x04[CT] \x01No answer = no points");
				CT_PlayerState[i] = 3;
			}
		}
		EndRound();
	}
}

//////////////////////////////////////////////////
////////////////////MENU START////////////////////
//////////////////////////////////////////////////
public MenuHandler_Invit(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		 case MenuAction_Start:
          {
              
          }

          case MenuAction_Display:
          {
				
          }
		 
		case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if (StrEqual(info, MENU_INV_1_NAME))
			{
				AddPlayer(param1);
				
				//new String:PName[MAX_NAME_LENGTH];
				//GetClientName(param1, PName, MAX_NAME_LENGTH);
			}	
			RemainingPlayersDec();
		}
 
		case MenuAction_Cancel:
		{
			RemainingPlayersDec();
		}
 
		case MenuAction_End:
        {
			CloseHandle(menu);
        }
 
	}
 
	return Plugin_Handled;
}

public MenuHandler_InvAll(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		 case MenuAction_Start:
          {
               //
          }

          case MenuAction_Display:
          {
				//
          }
		 
		 
		case MenuAction_Select:
		{
			//param1 - client (will be Master) 
			//param2 - choice
			
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if (StrEqual(info, MENU_INVALL_1_NAME))
			{
				SendInvitations(param1, false); // - range check
			}
			else if (StrEqual(info, MENU_INVALL_2_NAME))
			{
				SendInvitations(param1, true); // + range check
			}
			else
			{
				Game_State = 0;
			}
		}
		 
		case MenuAction_Cancel:
		{
			Game_State = 0;
		}
		
		case MenuAction_End:
        {
			CloseHandle(menu);
        }
		
	}
 
	return Plugin_Handled;
}

public Action:Menu_InvAll(client, args)
{
	Game_Init();
	
	
	if ((Game_State <= 0) && (GameEnabled)) 
	{
		CT_Master = client;
		Game_State = 1;
		new Handle:menu = CreateMenu(MenuHandler_InvAll);
		SetMenuTitle(menu, MENU_INVALL_TEXT);
		AddMenuItem(menu, MENU_INVALL_1_NAME, MENU_INVALL_1_TEXT);
		AddMenuItem(menu, MENU_INVALL_2_NAME, MENU_INVALL_2_TEXT);
		AddMenuItem(menu, MENU_INVALL_3_NAME, MENU_INVALL_3_TEXT);
		SetMenuExitButton(menu, false);
		
		DisplayMenu(menu, client, 20);
	 
		CT_Master = client;
	}
	else
	{
		PrintToChat(client, "\x04[CT] \x01<%s> is not available", TheName);
	}
	
	return Plugin_Handled;
}

Menu_Invit(client, MasterID)
{
	new Handle:menu = CreateMenu(MenuHandler_Invit);
			decl String:PName[MAX_NAME_LENGTH];
			GetClientName(MasterID, PName, MAX_NAME_LENGTH);
	SetMenuTitle(menu, "<%s> invitation from %s", TheName, PName);
	AddMenuItem(menu, MENU_INV_1_NAME, MENU_INV_1_TEXT);
	AddMenuItem(menu, MENU_INV_2_NAME, MENU_INV_2_TEXT);
	SetMenuExitButton(menu, false);
	DisplayMenu(menu, client, 20/*!!! was 20 !!!*/);
 
	return Plugin_Handled;
}

RemainingPlayersDec()
{
	//Every time someone responds 
	//Check if all players responded 
	
	
	RemainingPlayers--;
	if (RemainingPlayers == 0)
	{
		if (CT_PlayerCount>0)
		{
			PrintToServer("Player list (%d players):", CT_PlayerCount);
			for (new i;i<CT_PlayerCount;i++)
			{
				decl String:PName[64];
				GetClientName(CT_Players[i], PName, sizeof(PName));
				PrintToServer("CT_Players[%d] = %d (%s)",i,CT_Players[i],PName);
			}
			StartGame();
		}
		else
		{
			Game_State = 0;
		}
	}
}
		 

public SendInvitations(MasterID, bool:CheckRange)
{
	
				RemainingPlayers = 0;
				for(new i; i <= MaxClients; i++)
				{
					if(i > 0 && i <= MAXPLAYERS && IsClientInGame(i) )
					{	
						if (!IsInDuel(i))
						{
							
							if (CheckRange)
							{
								decl Float:OriginPlayer[3];
								decl Float:OriginMaster[3];
								GetClientAbsOrigin(MasterID, OriginPlayer);
								GetClientAbsOrigin(i, OriginMaster); 
								//PrintToServer("-DEBUG- SRoot = %f", SquareRoot((OriginPlayer[0]-OriginMaster[0])*(OriginPlayer[0]-OriginMaster[0])+(OriginPlayer[1]-OriginMaster[1])*(OriginPlayer[1]-OriginMaster[1])));
								if (INV_RANGE < SquareRoot((OriginPlayer[0]-OriginMaster[0])*(OriginPlayer[0]-OriginMaster[0])+(OriginPlayer[1]-OriginMaster[1])*(OriginPlayer[1]-OriginMaster[1])))
								{	continue; }
								
							}
							//PrintToServer("-DEBUG- MasterID %d, client %d", MasterID, i);
							if (i != MasterID)
							{
								Menu_Invit(i, MasterID);
								//PrintToServer("-DEBUG- RemainingPlayers = %d", RemainingPlayers);
								RemainingPlayers++;
								//PrintToServer("-DEBUG- RemainingPlayers = %d", RemainingPlayers);
							}
							else
							{
								//PrintToServer("i=%d =  param1=%d",i, param1);
							}
							//PrintToServer("-DEBUG- RemainingPlayers = %d", RemainingPlayers);	
						}
					}
				}
				if (RemainingPlayers>0)
				{
					CT_Master =  MasterID;
					//PrintToServer("Master = %d", CT_Master);
				}
				else
				{
					PrintToChat(MasterID, "\x04[CT] \x01No invites Sent:(");
					Game_State = 0;
				}
}

//////////////////////////////////////////////////
/////////////////////MENU END/////////////////////
//////////////////////////////////////////////////

stock bool:IsInDuel(client)
{
	//from Elmo's battlechess plugin
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

////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////ATTACK NAMES BEGIN/////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
GetAttackName(ActId, i)
{
	
    if ((ActId>13) && (ActId<255))
	{
		ActId -= CT_ATTACKID_BIAS;  //ActId changed after some patch (at least i think so)
		switch (ActId)
		{
			 
				   /* PURE BEGIN */
				  
			  case 117:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "F1 (Fast String 1)");
			  }
			  case 118:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F2 (Fast String 2)");
			  }
			  case 119:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F3 (Fast String 3)");
			  }
			  case 120:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FL (Fast Left)");
			  }
			  case 121:
			  {
				  Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FR (Fast Right)");
			  }
			  case 111:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "B1 (Balance String 1)");
			  }
			  case 112:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B2 (Balance String 2)");
			  }
			  case 113:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B3 (Balance String 3)");
			  }
			  case 114:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BL (Balance Left)");
			  }
			  case 115:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BR (Balance Right)");
			  }
			  case 123:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H1 (Heavy String 1)");
			  }
			  case 124:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H2 (Heavy String 2)");
			  }
			  case 125:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HL (Heavy Left)");
			  }
			  case 126:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HR (Heavy Right)");
			  }
			 
				   /* PURE =END */
				  
				   /* KNIGHT BEGIN */
			  case 66:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F1 (Fast String 1)");
			  }
			  case 67:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F2 (Fast String 2)");
			  }
			  case 68:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F3 (Fast String 3)");
			  }
			  case 69:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FL (Fast Left)");
			  }
			  case 70:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FR (Fast Right)");
			  }
			  case 72:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B1 (Balance String 1)");
			  }
			  case 73:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B2 (Balance String 2)");
			  }
			  case 74:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B3 (Balance String 3)");
			  }
			  case 75:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BL (Balance Left)");
			  }
			  case 76:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BR (Balance Right)");
			  }
			  case 78:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H1 (Heavy String 1)");
			  }
			  case 79:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H2 (Heavy String 2)");
			  }
			  case 80:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H3 (Heavy String 3)");
			  }
			  case 81:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HL (Heavy Left)");
			  }
			  case 82:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HR (Heavy Right)");
			  }
				   /* KNIGHT END */
				  
				   /* RYOKU BEGIN */
				  
			  case 88:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F1 (Fast String 1)");
			  }
			  case 89:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F2 (Fast String 2)");
			  }
			  case 90:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F3 (Fast String 3)");
			  }
			  case 91:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F4 (Fast String 4)");
			  }
			  case 92:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F5 (Fast String 5)");
			  }
			  case 93:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F6 (Fast String 6)");
			  }
			  case 94:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FL (Fast Left)");
			  }
			  case 95:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FR (Fast Right)");
			  }
			  case 97:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F1 (Balance String 1)");
			  }
			  case 98:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B2 (Balance String 2)");
			  }
			  case 100:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BL (Balance Left)");
			  }
			  case 101:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BR (Balance Right)");
			  }
			  case 103:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H1 (Heavy String 1)");
			  }
			  case 105:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HL (Heavy Left)");
			  }
			  case 104:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HR (Heavy Right)");
			  }
			 
				   /* RYOKU END */
				  
				   /* PHALANX BEGIN */
				  
			  case 49:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F1 (Fast String 1)");
			  }
			  case 50:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F2 (Fast String 2)");
			  }
			  case 51:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F3 (Fast String 3)");
			  }
			  case 52:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F4 (Fast String 4)");
			  }
			  case 53:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FL (Fast Left)");
			  }
			  case 54:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FR (Fast Right)");
			  }
			  case 42:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B1(Balance String 1)");
			  }
			  case 43:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B2 (Balance String 2)");
			  }
			  case 44:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B3 (Balance String 3)");
			  }
			  case 46:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BL (Balance Left)");
			  }
			  case 47:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "BR (Balance Right)");
			  }
			  case 56:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "H1 (Heavy String 1)");
			  }
			  case 58:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HL (Heavy Left)");
			  }
			  case 59:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "HR (Heavy Right)");
			  }
			 
				   /* PHALANX END */
				   
				   /* VANGUARD BEGIN */
			  case 139:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F1 (Fast String 1)");
			  }
			  case 140:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F2 (Fast String 2)");
			  }
			  case 141:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "F3 (Fast String 3)");
			  }
			  case 142:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FL (Fast Left)");
			  }
			  case 143:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "FR (Fast Right)");
			  }
			  case 132:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B1 (Balance String 1)");
			  }
			  case 133:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),   "B2 (Balance String 2)");
			  }
			  case 134:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "B3 (Balance String 3)");
			  }
			  case 135:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "B4 (Balance String 4)");
			  }
			  case 136:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),  "BL (Balance Left)");
			  }
			  case 137:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),  "BR (Balance Right)");
			  }
			  case 145:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]),  "H1 (Heavy String 1)");
			  }
			  case 146:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "HL (Heavy Left)");
			  }
			  case 147:
			  {
				   Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "HR (Heavy Right)");
			  }
				   /* VANGUARD END */
		}
    
    }
	else
	{
		Format(CT_PlayerAttackNames[i], sizeof(CT_PlayerAttackNames[]), "???");
		
	}
	
}
////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////ATTACK NAMES END///////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////


public Action:test(client, args)
{
	if (args>0)
	{
		decl String:arg1[123];
		GetCmdArg(1, arg1, 123);
		
		
		GetAttackName(StringToInt(arg1), 32);
		PrintToChat(client, "Attack name: %s", CT_PlayerAttackNames[32]);
	}
}
