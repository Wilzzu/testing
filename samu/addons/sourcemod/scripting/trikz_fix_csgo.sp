#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <clientprefs>
#include <trikznobug>

#define PLUGIN_VERSION "2.02 GO"

// SkyBoost
new bool:g_bSkyEnable[MAXPLAYERS+1] = {true, ...};
new Float:g_fBoosterAbsVelocityZ[MAXPLAYERS+1];
new g_SkyTouch[MAXPLAYERS+1];
new g_SkyReq[MAXPLAYERS+1];
new Float:g_vSkyBoostVel[MAXPLAYERS+1][3];

public Plugin:myinfo = 
{
	name = "[Trikz] Flash/Sky Fix",
	author = "ici & george",
	version = PLUGIN_VERSION
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {

	CreateNative("Trikz_SkyFix", Native_Trikz_SkyFix);
	return APLRes_Success;
}

public Native_Trikz_SkyFix(Handle:plugin, numParams) {

	g_bSkyEnable[GetNativeCell(1)] = bool:GetNativeCell(2);
}

public OnClientPutInServer(client) {
	
	// SkyBoost
	SDKHook(client, SDKHook_Touch, Hook_Touch);
	
	g_SkyTouch[client] = 0;
	g_SkyReq[client] = 0;
}

public Action:Hook_Touch(victim, other) {

	if (!g_bSkyEnable[victim]
	|| !IsValidClient(other)
	|| GetEntityMoveType(victim) == MOVETYPE_LADDER
	|| GetEntityMoveType(other) == MOVETYPE_LADDER) return Plugin_Continue;
	
	new col = GetEntProp(other, Prop_Data, "m_CollisionGroup");
	if (col != 5) return Plugin_Continue;
	
	decl Float:vVictimOrigin[3];
	decl Float:vBoosterOrigin[3];
	
	GetEntPropVector(victim, Prop_Data, "m_vecOrigin", vVictimOrigin);
	GetEntPropVector(other, Prop_Data, "m_vecOrigin", vBoosterOrigin);
	
	if ((Math_Abs(vVictimOrigin[0] - vBoosterOrigin[0]) > 32.0)
	|| (Math_Abs(vVictimOrigin[1] - vBoosterOrigin[1]) > 32.0)
	|| (vVictimOrigin[2] - vBoosterOrigin[2]) < 45.0)
		return Plugin_Continue;
	
	decl Float:vBoosterAbsVelocity[3];
	GetEntPropVector(other, Prop_Data, "m_vecAbsVelocity", vBoosterAbsVelocity);
	if (vBoosterAbsVelocity[2] <= 0.0) return Plugin_Continue;
	
	g_fBoosterAbsVelocityZ[victim] += vBoosterAbsVelocity[2];
	++g_SkyTouch[victim];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", g_vSkyBoostVel[victim]);
	
	RequestFrame(SkyFrame_Callback, victim);
	return Plugin_Continue;
}

public SkyFrame_Callback(any:victim) {

	if (g_SkyTouch[victim] == 0)
		return;
	
	++g_SkyReq[victim];
	decl Float:vVictimAbsVelocity[3];
	GetEntPropVector(victim, Prop_Data, "m_vecAbsVelocity", vVictimAbsVelocity);
	
	if (vVictimAbsVelocity[2] > 0.0) {
		g_vSkyBoostVel[victim][2] = vVictimAbsVelocity[2] + g_fBoosterAbsVelocityZ[victim] * 0.5;
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, g_vSkyBoostVel[victim]);
		g_fBoosterAbsVelocityZ[victim] = 0.0;
		g_SkyTouch[victim] = 0;
		g_SkyReq[victim] = 0;
	} else {
		if (g_SkyReq[victim] > 150) {
			g_fBoosterAbsVelocityZ[victim] = 0.0;
			g_SkyTouch[victim] = 0;
			g_SkyReq[victim] = 0;
			return;
		}
		// Recurse for a few more frames
		RequestFrame(SkyFrame_Callback, victim);
	}
}

bool:IsValidClient(client) {

	return (0 < client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

Float:Math_Abs(Float:value) {

	return (value >= 0.0 ? value : -value);
}