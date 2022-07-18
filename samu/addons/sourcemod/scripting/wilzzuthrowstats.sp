#include <morecolors>
#include <sdkhooks>
#include <ents>
#include <trikz>

#pragma semicolon 1
#pragma newdecls required

bool gB_boostStats[MAXPLAYERS + 1]; 
float gF_boostTime[MAXPLAYERS + 1];
int gI_SpectatorTarget[MAXPLAYERS + 1]; 

public Plugin myinfo = 
{
	name = "Wilzzu's Throw Stats",
	author = "Wilzzu"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_wts", Command_BoostStats);
	RegConsoleCmd("sm_ts", Command_BoostStats);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	gB_boostStats[client] = true;
	gI_SpectatorTarget[client] = -1;
}

Action Command_BoostStats(int client, int args)
{
	gB_boostStats[client] = !gB_boostStats[client];
	
	CPrintToChat(client, "{white}Wilzzu's Throw Stats is %s.", gB_boostStats[client] ? "on" : "off");
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	char sWeapon[32];
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(IsValidEntity(iWeapon))
	{
		GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
	}
	
	if(!(IsPlayerAlive(client) && StrEqual(sWeapon, "weapon_flashbang")))
	{
		return;
	}
	
	if(GetEntProp(client, Prop_Data, "m_afButtonReleased") & IN_ATTACK)
	{
		gF_boostTime[client] = GetEngineTime();
	}
	
	if(!(GetEntityFlags(client) & FL_ONGROUND && buttons & IN_JUMP))
	{
		return;
	}
	
	float flSpeed = GetEntitySpeed(client);
	
	float fProfTime = (GetEngineTime() - gF_boostTime[client]) * 1000;
	float fProfTimeLate = (GetEngineTime() - gF_boostTime[client]) * 1000;
	char sStatus[32];
	int iPartner = Trikz_FindPartner(client);
	
	if(101.562500 < fProfTimeLate < 500) 
	{
		fProfTimeLate = fProfTimeLate - 101.562500;
		
		if(359 < fProfTime < 500)
		{
			sStatus = "{red}Mitä vittua?";
		}
		
		if(149 < fProfTime <= 360)
		{
			sStatus = "{red}>+0.050";
		}
		
		if(139 < fProfTime <= 150)
		{
			sStatus = "{red}+0.040";
		}
	
		if(129 < fProfTime <= 140)
		{
			sStatus = "{red}+0.030";
		}
	
		if(119 < fProfTime <= 130)
		{
			sStatus = "{red}+0.020";
		}
	
		if(101.562500 < fProfTime <= 120)
		{
			sStatus = "{red}+0.010";
		}
		
		if(gB_boostStats[client])
		{
			CPrintToChat(client, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s", flSpeed, sStatus);
			
			if(iPartner != -1)
			{
				if(gB_boostStats[iPartner])
				{
					CPrintToChat(iPartner, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s {dimgray} | {orange}%N", flSpeed, sStatus, client);
				}
			}
		}
		
		if(iPartner == -1)
		{
			SpectatorCheck(client);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i) && !IsPlayerAlive(i) && gB_boostStats[i])
				{
					if(gI_SpectatorTarget[i] == client)
					{
						CPrintToChat(i, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s", flSpeed, sStatus);
					}
				}
			}
		}
		
		else
		{
			SpectatorCheck(iPartner);
		
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i) && !IsPlayerAlive(i) && gB_boostStats[i])
				{
					if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == iPartner)
					{
						CPrintToChat(i, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s {dimgray} | {orange}%N", flSpeed, sStatus, client);
					}
				}
			}
		}
	}
	
		
	if(89 < fProfTime <= 101.562500)
	{
		sStatus = "{lime}0.000";
	}
	
	if(79 < fProfTime < 90)
	{
		sStatus = "{green}-0.010";
	}
	
	if(69 < fProfTime < 80)
	{
		sStatus = "{green}-0.020";
	}
	
	if(59 < fProfTime < 70)
	{
		sStatus = "{greenyellow}-0.030";
	}
	if(49 < fProfTime < 60)
	{
		sStatus = "{greenyellow}-0.040";
	}
	if(39 < fProfTime < 50)
	{
		sStatus = "{orange}-0.050";
	}
	if(29 < fProfTime < 40)
	{
		sStatus = "{orange}-0.060";
	}
	if(19 < fProfTime < 30)
	{
		sStatus = "{red}-0.070";
	}
	if(0 <= fProfTime < 20)
	{
		sStatus = "{red}-0.080";
	}
	
	fProfTime = (fProfTime - 101.562499) * -1;
	
	if(0 <= fProfTime <= 101.562500)
	{
		if(gB_boostStats[client])
		{
			CPrintToChat(client, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s", flSpeed, sStatus);
			
			if(iPartner != -1)
			{
				if(gB_boostStats[iPartner])
				{
					CPrintToChat(iPartner, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s {dimgray}| {orange}%N", flSpeed, sStatus, client);
				}
			}
		}
		
		if(iPartner == -1)
		{
			SpectatorCheck(client);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i) && !IsPlayerAlive(i) && gB_boostStats[i])
				{
					if(gI_SpectatorTarget[i] == client)
					{
						CPrintToChat(i, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s", flSpeed, sStatus);
					}
				}
			}
		}
		
		else
		{
			SpectatorCheck(iPartner);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i) && !IsFakeClient(i) && !IsPlayerAlive(i) && gB_boostStats[i])
				{
					if(gI_SpectatorTarget[i] == client || gI_SpectatorTarget[i] == iPartner)
					{
						CPrintToChat(i, "{dimgray}[{orange}wTS{dimgray}] {white}Speed: {orange}%.1f{dimgray} | {white}Timing: %s {dimgray}| {orange}%N", flSpeed, sStatus, client);
					}
				}
			}
		}
	}
}

void SpectatorCheck(int client)
{
	//Manage spectators
	if(!IsClientObserver(client) && !gB_boostStats[client])
	{
		return;
	}
	
	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	
	if(3 < iObserverMode < 7)
	{
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		if(gI_SpectatorTarget[client] != iTarget)
		{
			gI_SpectatorTarget[client] = iTarget;
		}
	}
	
	else
	{
		if(gI_SpectatorTarget[client] != -1)
		{
			gI_SpectatorTarget[client] = -1;
		}
	}
}
