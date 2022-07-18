#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <flashtools>
#include <trikz>

#undef REQUIRE_EXTENSIONS
#include <steamtools>
#include <collisionhook>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

#define TRIKZ_VERSION "1.8.0"

ConVar sv_enablebunnyhopping = null;
ConVar sv_enableboost = null;

ConVar gCV_Enabled = null;
ConVar gCV_Overwrite = null;
ConVar gCV_PartnerBlock = null;
ConVar gCV_KillFlashbang = null;

bool gB_Enabled;
char gS_Overwrite[32];
bool gB_PartnerBlock;
bool gB_KillFlashbang;

bool gB_AutoFlash[MAXPLAYERS+1];
bool gB_AutoSwitch[MAXPLAYERS+1];

int gI_Partner[MAXPLAYERS+1];
int gI_LastUsed[MAXPLAYERS+1];

bool gB_SteamTools = false;
bool gB_Shavit = false;

int gI_AmmoOffset = -1;
int gI_OffsetMyWeapons = -1;

float gF_Save1[MAXPLAYERS+1][3];
float gF_Save2[MAXPLAYERS+1][3];

bool gB_OnGround[MAXPLAYERS+1];

char gS_CMD_Trikz[][] = {"sm_t", "sm_trikz", "sm_menu"};
char gS_CMD_Flash[][] = {"sm_f", "sm_flash", "sm_giveflash", "sm_flashbang"};
char gS_CMD_AutoFlash[][] = {"sm_af", "sm_autoflash"};
char gS_CMD_AutoSwitch[][] = {"sm_as", "sm_autoswitch"};
char gS_CMD_Block[][] = {"sm_bl", "sm_block", "sm_ghost", "sm_switch"};
char gS_CMD_Partner[][] = {"sm_p", "sm_partner", "sm_mate"};
char gS_CMD_UnPartner[][] = {"sm_unp", "sm_unpartner", "sm_nomate"};

// timer settings
char gS_StyleStrings[STYLE_LIMIT][STYLESTRINGS_SIZE][128];
bool gB_Late = false;

public Plugin myinfo = 
{
	name = "Trikz (Redux)",
	author = "shavit",
	description = "Redux of the original Trikz plugin by johan123jo that is more functional.",
	version = TRIKZ_VERSION,
	url = "http://forums.alliedmods.net/member.php?u=163134"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Trikz_HasPartner", Native_HasPartner);
	CreateNative("Trikz_FindPartner", Native_FindPartner);
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	
	RegPluginLibrary("trikz");

	gB_Late = late;
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	for(int i = 0; i < sizeof(gS_CMD_Trikz); i++)
	{
		RegConsoleCmd(gS_CMD_Trikz[i], Command_Trikz, "Trikz menu");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_Flash); i++)
	{
		RegConsoleCmd(gS_CMD_Flash[i], Command_Flash, "Obtain a Flashbang");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_AutoFlash); i++)
	{
		RegConsoleCmd(gS_CMD_AutoFlash[i], Command_AutoFlash, "Toggle auto flash");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_AutoSwitch); i++)
	{
		RegConsoleCmd(gS_CMD_AutoSwitch[i], Command_AutoSwitch, "Toggle auto switch");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_Block); i++)
	{
		RegConsoleCmd(gS_CMD_Block[i], Command_Block, "Toggle blocking");
	}
	
	RegConsoleCmd("sm_respawn", Command_Respawn, "Respawn yourself");
	
	for(int i = 0; i < sizeof(gS_CMD_Partner); i++)
	{
		RegConsoleCmd(gS_CMD_Partner[i], Command_Partner, "Select your Trikz partner.");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_UnPartner); i++)
	{
		RegConsoleCmd(gS_CMD_UnPartner[i], Command_UnPartner, "Disable your partnership.");
	}
	
	gI_AmmoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	gI_OffsetMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	
	LoadTranslations("common.phrases");
	LoadTranslations("trikz_redux.phrases");
	
	HookEvent("weapon_fire", Weapon_Fire);
	HookEvent("player_spawn", Player_Spawn);
	
	sv_enableboost = FindConVar("sv_enableboost");
	
	if(sv_enableboost != null)
	{
		PrintToServer("Convar \"sv_enableboost\" locked to 1.");
		
		sv_enableboost.BoolValue = true;
	}
	
	sv_enablebunnyhopping = FindConVar("sv_enablebunnyhopping");
	
	if(sv_enablebunnyhopping != null)
	{
		PrintToServer("Convar \"sv_enablebunnyhopping\" locked to 1.");
		
		sv_enablebunnyhopping.BoolValue = true;
		sv_enablebunnyhopping.AddChangeHook(OnConVarChanged);
	}
	
	CreateConVar("sm_trikzredux_version", TRIKZ_VERSION, "Trikz (Redux) version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	gCV_Enabled = CreateConVar("sm_trikzredux_enabled", "1", "Trikz (Redux) is enabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gB_Enabled = GetConVarBool(gCV_Enabled);
	
	gCV_Overwrite = CreateConVar("sm_trikzredux_overwrite", "CS:S Trikz", "If SteamTools' installed, what should be the new game description?\nThe original is Counter-Strike: Source.\nHint: Change to 0 or \"none\" if you want it to remain the same.");
	GetConVarString(gCV_Overwrite, gS_Overwrite, 32);
	
	gCV_PartnerBlock = CreateConVar("sm_trikzredux_partnerblock", "1", "Require players to have a partner in order to set their solidity to blocking?", 0, true, 0.0, true, 1.0);
	gB_PartnerBlock = GetConVarBool(gCV_PartnerBlock);
	
	gCV_KillFlashbang = CreateConVar("sm_trikzredux_killflash", "1", "Kill a flashbang once it hits someone?", 0, true, 0.0, true, 1.0);
	gB_KillFlashbang = GetConVarBool(gCV_KillFlashbang);
	
	gCV_Enabled.AddChangeHook(OnConVarChanged);
	gCV_Overwrite.AddChangeHook(OnConVarChanged);
	gCV_PartnerBlock.AddChangeHook(OnConVarChanged);
	gCV_KillFlashbang.AddChangeHook(OnConVarChanged);
	
	AutoExecConfig(true, "trikz_redux");
	
	OnConfigsExecuted();

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}

		Shavit_OnStyleConfigLoaded(-1);
	}
}

public void OnConVarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	if(cvar == gCV_Enabled)
	{
		gB_Enabled = view_as<bool>(StringToInt(newVal));
	}
	
	else if(cvar == gCV_Overwrite)
	{
		FormatEx(gS_Overwrite, 32, newVal);
		Steam_SetGameDescription(gS_Overwrite);
	}
	
	else if(StringToInt(newVal) != 1 && (cvar == sv_enableboost || cvar == sv_enablebunnyhopping))
	{
		cvar.BoolValue = true;
	}
	
	else if(cvar == gCV_PartnerBlock)
	{
		gB_PartnerBlock = view_as<bool>(StringToInt(newVal));
	}
	
	else if(cvar == gCV_KillFlashbang)
	{
		gB_KillFlashbang = view_as<bool>(StringToInt(newVal));
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(!gB_Shavit)
	{
		return;
	}

	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i][sStyleName], 128);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "SteamTools"))
	{
		gB_SteamTools = true;
	}
	
	else if(StrEqual(name, "shavit"))
	{
		gB_Shavit = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "SteamTools"))
	{
		gB_SteamTools = false;
	}
	
	else if(StrEqual(name, "shavit"))
	{
		gB_Shavit = false;
	}
}

public void OnConfigsExecuted()
{
	if(!gB_Enabled)
	{
		return;
	}
	
	gB_SteamTools = LibraryExists("SteamTools");
	gB_Shavit = LibraryExists("shavit");
	
	ConVar sv_ignoregrenaderadio = FindConVar("sv_ignoregrenaderadio");
	
	if(sv_ignoregrenaderadio == null)
	{
		SetFailState("sv_ignoregrenaderadio is missing (why? -_-), plugin unloaded.");
	}
	
	else
	{
		sv_ignoregrenaderadio.BoolValue = true;
	}
	
	if(gB_SteamTools && !StrEqual(gS_Overwrite, "0") && !StrEqual(gS_Overwrite, "none") && !StrEqual(gS_Overwrite, ""))
	{
		Steam_SetGameDescription(gS_Overwrite);
	}
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		resetCoordinates(i);
	}
}

public void OnClientDisconnect(int client)
{
	if(gI_Partner[client] != -1)
	{
		gI_Partner[gI_Partner[client]] = -1;
	}
	
	gI_Partner[client] = -1;
	
	reset(client);
}

public void OnClientPutInServer(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}
	
	reset(client);
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	
	CreateTimer(3.0, WelcomeMessage, GetClientSerial(client));
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(!gB_Enabled || !gB_KillFlashbang || !IsValidClient(victim, true) || !IsValidClient(victim, true))
	{
		return Plugin_Continue;
	}
	
	char[] Weapon = new char[32];
	GetEdictClassname(inflictor, Weapon, 32);
	
	if(StrContains(Weapon, "flashbang", false) == -1)
	{
		return Plugin_Continue;
	}
	
	CreateTimer(0.1, Timer_KillFlashbang, inflictor);
	
	return Plugin_Continue;
}

public Action Timer_KillFlashbang(Handle Timer, any data)
{
	if(data != INVALID_ENT_REFERENCE && IsValidEntity(data))
	{
		AcceptEntityInput(data, "Kill");
	}
}

public Action OnFlashDetonate(int entity)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(IsValidEdict(entity))
	{
		RemoveEdict(entity);
	}
	
	return Plugin_Handled;
}

public Action WelcomeMessage(Handle Timer, any serial)
{
	if(!gB_Enabled)
	{
		return Plugin_Stop;
	}
	
	int client = GetClientFromSerial(serial);
	
	if(client != 0)
	{
		Shavit_PrintToChat(client, "%T", "sm_welcome", client);
	}
	
	return Plugin_Stop;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if((damagetype & DMG_FALL) > 0)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(StrEqual(sArgs, "trikz") || StrEqual(sArgs, "t"))
	{
		Command_Trikz(client, 0);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Command_Block(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "sm_youmustbealive", client);
		
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] == -1 && gB_PartnerBlock)
	{
		Shavit_PrintToChat(client, "%T", "sm_youneedapartnerforthiscommand", client);
		
		return Plugin_Handled;
	}
	
	int CollisionGroup = GetEntProp(client, Prop_Data, "m_CollisionGroup");
	
	if(CollisionGroup == 5)
	{
		Shavit_PrintToChat(client, "%T", "sm_ghost", client);
		
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		SetEntityRenderColor(client, 255, 255, 255, 100);
	}
	
	else if(CollisionGroup == 2)
	{
		Shavit_PrintToChat(client, "%T", "sm_blocking", client);
		
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
	
	return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	if(args == 0)
	{
		if(GetClientTeam(client) < 2)
		{
			Shavit_PrintToChat(client, "%T", "sm_respawnfailed", client);
			
			return Plugin_Handled;
		}
		
		CS_RespawnPlayer(client);
		Shavit_RestartTimer(client, Shavit_GetClientTrack(client));
		
		Shavit_PrintToChat(client, "%T", "sm_respawnnotify", client);
		
		return Plugin_Handled;
		
	}
	
	return Plugin_Handled;
}

public Action Command_Trikz(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	TrikzMenu(client);
	
	return Plugin_Handled;
}

public Action Command_AutoFlash(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	gB_AutoFlash[client] = !gB_AutoFlash[client];
	
	if(IsPlayerAlive(client))
	{
		while(gB_AutoFlash[client])
		{
			if(GetClientFlashBangs(client) >= 2)
			{
				break;
			}
			
			GivePlayerItem(client, "weapon_flashbang");
		}
	}
	
	if(!gB_AutoFlash[client] && gB_AutoSwitch[client])
	{
		gB_AutoSwitch[client] = false;
		Shavit_PrintToChat(client, "%T", "sm_autoswitchdisabled", client);
	}
	
	Shavit_PrintToChat(client, "%T", gB_AutoFlash[client]? "sm_autoflashenabled":"sm_autoflashdisabled", client);
	
	return Plugin_Handled;
}

public Action Command_AutoSwitch(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	gB_AutoSwitch[client] = !gB_AutoSwitch[client];
	
	if(gB_AutoSwitch[client])
	{
		if(!gB_AutoFlash[client])
		{
			Command_AutoFlash(client, 0);
		}
		
		FakeClientCommand(client, "use weapon_flashbang");
	}
	
	Shavit_PrintToChat(client, "%T", gB_AutoSwitch[client]? "sm_autoswitchenabled":"sm_autoswitchdisabled", client);
	
	return Plugin_Handled;
}

void TrikzMenu(int client)
{
	if(!gB_Enabled)
	{
		return;
	}
	
	Menu menu = new Menu(Trikz_MenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "sm_trikz", client, TRIKZ_VERSION);
	
	menu.AddItem("sm_flash", "Give Flashbang");
	menu.AddItem("sm_autoflash", "Auto Flash");
	menu.AddItem("sm_autoswitch", "Auto Switch");
	
	char[] Display = new char[32];
	FormatEx(Display, 32, "%T", "sm_block", client);
	
	menu.AddItem("sm_block", Display, (gI_Partner[client] != -1)? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("sm_respawn", "Respawn");
	
	char[] Info = new char[32];
	FormatEx(Display, 32, "%s", (gI_Partner[client] != -1)? "Cancel Trikz Partnership":"Select Trikz Partner");
	FormatEx(Info, 32, "%s", (gI_Partner[client] != -1)? "sm_cancelpartner":"sm_trikzpartner");
	
	menu.AddItem(Info, Display);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Trikz_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(!gB_Enabled)
	{
		return 0;
	}
	
	switch(action)
	{
		case MenuAction_Select:
		{
			char[] item = new char[64];
			menu.GetItem(param2, item, 64);
			
			if(StrEqual(item, "sm_flash"))
			{
				Command_Flash(param1, 0);
			}
			
			else if(StrEqual(item, "sm_autoflash"))
			{
				Command_AutoFlash(param1, 0);
			}
			
			else if(StrEqual(item, "sm_autoswitch"))
			{
				Command_AutoSwitch(param1, 0);
			}
			
			else if(StrEqual(item, "sm_block"))
			{
				Command_Block(param1, 0);
			}
			
			else if(StrEqual(item, "sm_respawn"))
			{
				Command_Respawn(param1, 0);
			}
			
			else if(StrEqual(item, "sm_cancelpartner"))
			{
				Command_UnPartner(param1, -1);
				
				return 0;
			}
			
			else if(StrEqual(item, "sm_trikzpartner"))
			{
				Command_Partner(param1, -1);
				
				return 0;
			}
			
			TrikzMenu(param1);
		}
		
		case MenuAction_DisplayItem:
		{
			char[] info = new char[32];
			menu.GetItem(param2, info, 32);
			
			char[] display = new char[64];
			
			if(StrEqual(info, "sm_flash"))
			{
				Format(display, 64, "%T", "sm_flash", param1);
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_autoflash"))
			{
				Format(display, 64, "%T", "sm_autoflash", param1, gB_AutoFlash[param1]? "V":"X");
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_autoswitch"))
			{
				Format(display, 64, "%T", "sm_autoswitch", param1, gB_AutoSwitch[param1]? "V":"X");
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_cpmenu"))
			{
				Format(display, 64, "%T", "sm_cpmenu", param1);
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_tpto"))
			{
				Format(display, 64, "%T", "sm_tpto", param1);
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_respawn"))
			{
				Format(display, 64, "%T", "sm_respawn", param1);
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_cancelpartner"))
			{
				Format(display, 64, "%T", "sm_cancelpartner", param1, gI_Partner[param1]);
				
				return RedrawMenuItem(display);
			}
			
			else if(StrEqual(info, "sm_trikzpartner"))
			{
				Format(display, 64, "%T", "sm_trikzpartner", param1);
				
				return RedrawMenuItem(display);
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

public Action Command_Flash(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "sm_youmustbealive", client);
		
		return Plugin_Handled;
	}
	
	if(GetClientFlashBangs(client) >= 2)
	{
		Shavit_PrintToChat(client, "%T", "sm_toomuchflashbangs", client);
		
		return Plugin_Handled;
	}
	
	Shavit_PrintToChat(client, "%T", "sm_obtainedflashbang", client);
	GivePlayerItem(client, "weapon_flashbang");
	
	return Plugin_Handled;
}

public Action Weapon_Fire(Event event, const char[] name, bool dontBroadcast)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	if(!IsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	char[] weapon = new char[64];
	GetEventString(event, "weapon", weapon, 64);
	
	if(StrEqual(weapon, "flashbang"))
	{
		gB_OnGround[client] = ((GetEntityFlags(client) & FL_ONGROUND) > 0);
		
		if(gB_AutoFlash[client])
		{
			GivePlayerItem(client, "weapon_flashbang");
			
			if(gB_AutoSwitch[client])
			{
				CreateTimer(0.15, AutoSwitchTimer, GetClientSerial(client));
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	if(!IsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	if(gB_AutoFlash[client])
	{
		GivePlayerItem(client, "weapon_flashbang");
		GivePlayerItem(client, "weapon_flashbang");
		
		if(gB_AutoSwitch[client])
		{
			FakeClientCommand(client, "use weapon_flashbang");
		}
	}
	
	TrikzMenu(client);

	return Plugin_Continue;
}

public Action AutoSwitchTimer(Handle Timer, any serial)
{
	if(!gB_Enabled)
	{
		return Plugin_Handled;
	}
	
	int client = GetClientFromSerial(serial);
	
	if(!IsValidClient(client, true) || !gB_AutoSwitch[client])
	{
		return Plugin_Handled;
	}
	
	FakeClientCommand(client, "use weapon_knife");
	FakeClientCommand(client, "use weapon_flashbang");
	
	return Plugin_Handled;
}

public Action Command_Partner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		Shavit_PrintToChat(client, "%T", "sm_youmustbealive", client);
		
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] != -1)
	{
		Shavit_PrintToChat(client, "%T", "sm_alreadyhavepartner", client);
		
		return Plugin_Handled;
	}
	
	PartnerMenu(client, args == -1? true:false);
	
	return Plugin_Handled;
}

void PartnerMenu(int client, bool submenu)
{
	if(!gB_Enabled)
	{
		return;
	}
	
	Menu menu = new Menu(PartnerAsk_MenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "sm_selectapartner", client);
	
	char[] Display = new char[MAX_NAME_LENGTH];
	char[] ClientID = new char[8];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
		{
			continue;
		}
		
		if(IsValidClient(i, true) && !IsFakeClient(i) && !IsClientSourceTV(i) && gI_Partner[i] == -1)
		{
			GetClientName(i, Display, MAX_NAME_LENGTH);
			ReplaceString(Display, MAX_NAME_LENGTH, "#", "?");
			IntToString(i, ClientID, 8);
			menu.AddItem(ClientID, Display);
		}
	}
	
	if(submenu)
	{
		menu.ExitBackButton = true;
	}
	
	else
	{
		menu.ExitButton = true;
	}
	
	if(menu.ItemCount > 0)
	{
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	
	else
	{
		Shavit_PrintToChat(client, "%T", "sm_nopartners", client);
		
		delete menu;
	}
}

public int PartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(!gB_Enabled)
			{
				return 0;
			}

			int Time = GetTime();
			
			if(Time - gI_LastUsed[param1] <= 15)
			{
				Shavit_PrintToChat(param1, "%T", "sm_partnercooldown", param1, Time - gI_LastUsed[param1]);
				
				return 0;
			}
			
			gI_LastUsed[param1] = Time;
			
			char[] info = new char[32];
			menu.GetItem(param2, info, 32);
			
			int client = StringToInt(info);
			
			if(IsValidClient(client, true) && IsValidClient(param1, true) && gI_Partner[client] == -1)
			{
				Menu menuask = new Menu(Partner_MenuHandler, MENU_ACTIONS_ALL);
				menuask.SetTitle("%T", "sm_partnerask", param1, param1);
				
				char[] Display = new char[32];
				char[] menuinfo = new char[32];
				
				IntToString(param1, menuinfo, 32);
				
				FormatEx(Display, MAX_NAME_LENGTH, "%T", "sm_accept", param1);
				menuask.AddItem(menuinfo, "Accept");
				
				FormatEx(Display, MAX_NAME_LENGTH, "%T", "sm_deny", param1);
				menuask.AddItem(menuinfo, "Deny");
				
				menu.ExitButton = false;
				menuask.Display(client, 20);
			}
			
			else if(gI_Partner[client] != -1)
			{
				Shavit_PrintToChat(client, "%T %s", "sm_partnerask", param1, param1);
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Command_Trikz(param1, 0);
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

public int Partner_MenuHandler(Menu menuask, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(!gB_Enabled)
			{
				return 0;
			}

			char[] info = new char[32];
			menuask.GetItem(param2, info, 32);
			
			int client = StringToInt(info);
			
			switch(param2)
			{
				case 0:
				{
					gI_Partner[client] = param1;
					gI_Partner[param1] = client;
					
					CS_RespawnPlayer(client);
					CS_RespawnPlayer(param1);
					
					SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
					SetEntProp(param1, Prop_Data, "m_CollisionGroup", 5);
					
					SetEntityRenderMode(client, RENDER_NORMAL);
					SetEntityRenderMode(param1, RENDER_NORMAL);
					
					Shavit_PrintToChat(client, "%T", "sm_accepted", client, param1);
				}
				
				case 1:
				{
					Shavit_PrintToChat(client, "%T", "sm_denied", client, param1);
				}
			}
		}
		
		case MenuAction_End:
		{
			delete menuask;
		}
	}
	
	return 0;
}

public Action Command_UnPartner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!gB_Enabled)
	{
		Shavit_PrintToChat(client, "%T", "sm_plugindisabled", client);
		
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] == -1)
	{
		Shavit_PrintToChat(client, "%T", "sm_needpartnerforthis", client);
		
		return Plugin_Handled;
	}
	
	UnPartnerMenu(client, args == -1? true:false);
	
	return Plugin_Handled;
}

void UnPartnerMenu(int client, bool submenu)
{
	if(!gB_Enabled)
	{
		return;
	}
	
	Menu menu = new Menu(UnPartnerAsk_MenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "sm_cancelpartnership", client, gI_Partner[client]);

	char[] Display = new char[32];
	
	FormatEx(Display, 32, "%T", "sm_accept", client);
	menu.AddItem("sm_accept", Display);
	
	FormatEx(Display, 32, "%T", "sm_deny", client);
	menu.AddItem("sm_deny", Display);
	
	if(submenu)
	{
		menu.ExitBackButton = true;
	}
	
	else
	{
		menu.ExitButton = true;
	}
	
	menu.Display(client, 20);
}

public int UnPartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(!gB_Enabled)
			{
				return 0;
			}

			char[] info = new char[32];
			menu.GetItem(param2, info, 32);
			
			if(StrEqual(info, "sm_accept"))
			{
				int CurrentPartner = gI_Partner[param1];
				
				gI_Partner[CurrentPartner] = -1;
				gI_Partner[param1] = -1;
				
				Shavit_StopTimer(param1);
				Shavit_StopTimer(CurrentPartner);
				
				Shavit_PrintToChat(param1, "%T", "sm_isnotyourpartneranymore", param1, CurrentPartner);
				Shavit_PrintToChat(CurrentPartner, "%T", "sm_disabledhispartnership", CurrentPartner, param1);
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Command_Trikz(param1, 0);
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

public Action Shavit_OnStart(int client, int track)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(gI_Partner[client] == -1)
	{
		PrintCenterText(client, "%T", "sm_needpartner", client);
		
		return Plugin_Stop;
	}
	
	if(!IsPlayerAlive(client) || !IsValidClient(gI_Partner[client], true))
	{
		PrintCenterText(client, "%T", "sm_partnerisdead", client);
		
		return Plugin_Stop;
	}
	
	int style1 = Shavit_GetBhopStyle(client);
	int style2 = Shavit_GetBhopStyle(gI_Partner[client]);
	
	if(style2 != style1)
	{
		PrintCenterText(client, "%T", "sm_difficultiesnotsame", client, gI_Partner[client], gS_StyleStrings[style1][sStyleName], gS_StyleStrings[style2][sStyleName]);
		
		return Plugin_Stop;
	}

	if(Shavit_InsideZone(gI_Partner[client], Zone_Start, track))
	{
		return Plugin_Stop;
	}
	
	PrintCenterText(client, "");

	return Plugin_Continue;
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	if(!gB_Enabled)
	{
		return;
	}
	
	if(gI_Partner[client] != -1 && Shavit_GetTimerStatus(gI_Partner[client]) != Timer_Stopped)
	{
		Shavit_FinishMap(gI_Partner[client], track);
	}
}

public void Shavit_OnPause(int client, int track)
{
	if(gI_Partner[client] != -1 && Shavit_GetTimerStatus(gI_Partner[client]) == Timer_Running)
	{
		Shavit_PauseTimer(gI_Partner[client]);
	}
}

public void Shavit_OnResume(int client, int track)
{
	if(gI_Partner[client] != -1 && Shavit_GetTimerStatus(gI_Partner[client]) == Timer_Paused)
	{
		Shavit_ResumeTimer(gI_Partner[client]);
	}
}

public Action CH_PassFilter(int ent1, int ent2, bool &result)
{
	if(!gB_Enabled || !gB_PartnerBlock || !IsValidClient(ent1, true))
	{
		return Plugin_Continue;
	}
	
	if(IsValidClient(ent2, true) && gI_Partner[ent1] != -1 && gI_Partner[ent1] == gI_Partner[ent2])
	{
		result = true;

		return Plugin_Changed;
	}
	
	if(IsValidEntity(ent2))
	{
		char[] classname = new char[32];
		GetEntityClassname(ent2, classname, 32);
		
		if(StrEqual(classname, "flashbang_projectile", false))
		{
			int FlashOwner = GetEntPropEnt(ent2, Prop_Send, "m_hOwnerEntity");
			
			if(IsValidClient(FlashOwner, true))
			{
				if(ent1 == gI_Partner[FlashOwner] && FlashOwner == gI_Partner[ent1])
				{
					result = true;
					
					return Plugin_Changed;
				}
				
				else
				{
					result = false;
					
					return Plugin_Changed;
				}
			}
		}
	}
	
	result = true;
	
	return Plugin_Continue;
}

public Action OnTrigger(int entity, int other)
{
	if(!gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(IsValidClient(other) && gI_Partner[other] == -1)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "func_button"))
	{
		SDKHook(entity, SDKHook_Use, OnUseHook);
	}
	
	else if(StrContains(classname, "trigger_") != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, OnTrigger);
	}
}

public Action OnUseHook(int entity, int activator, int caller, UseType type, float value)
{
	if(type != Use_Toggle || !gB_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(gI_Partner[caller] == -1)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client)
{
	if(!gB_Enabled || !IsValidClient(client, true))
	{
		return Plugin_Continue;
	}
	
	if(gI_Partner[client] == -1 && gB_PartnerBlock)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		SetEntityRenderColor(client, 255, 255, 255, 100);
	}
	
	return Plugin_Continue;
}

// Natives
public int Native_HasPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsValidClient(client))
	{
		ThrowError("Player index %d is invalid.", client);

		return -1;
	}
	
	return view_as<int>(gI_Partner[client] != -1);
}

public int Native_FindPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsValidClient(client))
	{
		ThrowError("Player index %d is invalid.", client);

		return -1;
	}

	if(gI_Partner[client] != -1 && client == gI_Partner[gI_Partner[client]])
	{
		return gI_Partner[client];
	}
	
	return -1;
}

void resetCoordinates(int client)
{
	for(int i = 0; i <= 2; i++)
	{
		gF_Save1[client][i] = 0.0;
		gF_Save2[client][i] = 0.0;
	}
}

void reset(int client)
{
	gB_AutoSwitch[client] = false;
	gB_AutoFlash[client] = false;
	gB_OnGround[client] = true;
	
	gI_Partner[client] = -1;
	
	resetCoordinates(client);
}

// From original Trikz plugin
// by johan123jo
int GetClientFlashBangs(int client)
{
	char[] sWeapon = new char[32];
	
	for(int i = 0; i < 128; i += 4)
	{
		int weapon = GetEntDataEnt2(client, gI_OffsetMyWeapons + i);
		
		if(weapon != -1)
		{
			GetEdictClassname(weapon, sWeapon, 32);
			
			if(StrEqual(sWeapon, "weapon_flashbang"))
			{
				int iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 4);
				int ammo = GetEntData(client, gI_AmmoOffset + (iPrimaryAmmoType * 4));
				
				return ammo;
			}
		}
	}
	
	return 0;
}
