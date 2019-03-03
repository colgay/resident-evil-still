#include <amxmodx>
#include <fun>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <orpheu>
#include <orpheu_memory>
#include <orpheu_stocks>
#include <ammo>

#define VERSION "0.1"

new const MODEL_ZOMBIE[] = "zombie_fear";
new const MODEL_ZOMBIE_KNIFE[] = "models/resident_evil_test/v_knife_zombie.mdl";
new const MODEL_SURVIVORS[][] = { "arctic", "guerilla", "leet", "terror" };
new const MODEL_POLICE[][] = { "gign", "gsg9", "sas", "urban" };

new const DEFAULT_ITEMS[][] = { "usp", "glock18", "p228" };

new const DEFAULT_NAME_PRI[][] = { "Scout", "TMP", "MAC-10", "MP5", "UMP45" };
new const DEFAULT_ITEMS2_PRI[][] = { "scout", "tmp", "mac10", "mp5navy", "ump45" };

new const DEFAULT_NAME_SEC[][] = { "USP", "Glock 18", "P228", "Fiveseven" };
new const DEFAULT_ITEMS2_SEC[][] = { "usp", "glock18", "p228", "fiveseven" };

#define WINNER_NONE 0

enum
{
	WINSTATUS_CTS = 1,
	WINSTATUS_TERRORISTS,
	WINSTATUS_DRAW,
};

enum (+=100)
{
    TASK_ROUNDSTART = 0,
    TASK_COUNTDOWN,
    TASK_COMMENCING,
    TASK_RESPAWN,
};

enum
{
    TEAM_UNASSIGNED = 0,
    TEAM_TERRORIST,
    TEAM_CT,
    TEAM_SPECTATOR,
};

enum
{
    CLASS_SURVIVOR = 0,
    CLASS_POLICE,
};

enum _:ForwardData
{
    FWD_MAKE_ZOMBIE = 0,
    FWD_MAKE_HUMAN,
};

new const OBJECTIVES[][] = 
{
    "func_bomb_target",
    "info_bomb_target",
    "info_vip_start",
    "func_vip_safetyzone",
    "func_escapezone",
    "hostage_entity",
    "monster_scientist",
    "func_hostage_rescue",
    "info_hostage_rescue",
    "func_buyzone"
};

new g_Forward[ForwardData];

new g_MapInfoEnt;
new bool:g_IsGameStarted;
new bool:g_AllowRespawn;
new bool:g_IsZombie[MAX_PLAYERS + 1];
new g_PlayerClass[MAX_PLAYERS + 1];

new Float:g_DeadOrigin[MAX_PLAYERS + 1][3];

new g_fwEntSpawn;

new g_pGameRules;
new g_pAutoTeamBalance;
new g_pMinPlayers;

new g_msgClCorpse;

public plugin_precache()
{
    PrecacheResources();

    g_fwEntSpawn = register_forward(FM_Spawn, "OnEntSpawn");

    g_MapInfoEnt = create_entity("info_map_parameters");
    DispatchKeyValue(g_MapInfoEnt, "buying", "3");
    DispatchSpawn(g_MapInfoEnt);

    OrpheuRegisterHook(OrpheuGetFunction("InstallGameRules"), "OnInstallGameRules_Post", OrpheuHookPost);
}

PrecacheResources()
{
    new string[128];
    formatex(string, charsmax(string), "models/player/%s/%s.mdl", MODEL_ZOMBIE, MODEL_ZOMBIE);
    precache_model(string);

    precache_model(MODEL_ZOMBIE_KNIFE);
}

public plugin_init()
{
    register_plugin("Resident Evil", VERSION, "Holla");

    register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0");
    register_logevent("Event_RoundStart", 2, "1=Round_Start");

    register_think("corpse_entity", "OnCorpseThink");

    register_forward(FM_CmdStart, "OnCmdStart");
    unregister_forward(FM_Spawn, g_fwEntSpawn);

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn");
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);
    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");
    RegisterHam(Ham_TraceAttack, "player", "OnPlayerTraceAttack");
    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxSpeed_Post", 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled");

    RegisterHam(Ham_Item_Deploy, "weapon_knife", "OnKnifeDeploy_Post", 1);

    RegisterHam(Ham_Touch, "weaponbox", "OnWeaponTouch");
    RegisterHam(Ham_Touch, "weapon_shield", "OnWeaponTouch");
    RegisterHam(Ham_Touch, "armoury_entity", "OnWeaponTouch");

    OrpheuRegisterHookFromObject(g_pGameRules, "CheckWinConditions", "CGameRules", "OnCheckWinConditions");
    OrpheuRegisterHookFromObject(g_pGameRules, "FPlayerCanRespawn", "CGameRules", "OnPlayerCanRespawn");
    OrpheuRegisterHook(OrpheuGetFunction("GiveDefaultItems", "CBasePlayer"), "OnGiveDefaultItems");

    g_msgClCorpse = get_user_msgid("ClCorpse");
    register_message(g_msgClCorpse, "Message_Corpse");

    new pcvar = register_cvar("re_min_players", "2");
    bind_pcvar_num(pcvar, g_pMinPlayers);

    g_pAutoTeamBalance = get_cvar_pointer("mp_autoteambalance");

    g_Forward[FWD_MAKE_ZOMBIE] = CreateMultiForward("re_on_make_zombie", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_MAKE_HUMAN] = CreateMultiForward("re_on_make_human", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
    register_library("resident_evil");

    register_native("re_is_user_zombie", "native_is_user_zombie");
}

public OnEntSpawn(ent)
{
	if (pev_valid(ent))
	{
		new classname[32];
		pev(ent, pev_classname, classname, charsmax(classname));
		
		for (new i = 0; i < sizeof OBJECTIVES; i++)
		{
			if (equal(classname, OBJECTIVES[i]))
			{
				remove_entity(ent);
				return FMRES_SUPERCEDE;
			}
		}
	}
	
	return FMRES_IGNORED;
}

public OnInstallGameRules_Post()
{
    g_pGameRules = OrpheuGetReturn();
}

public OrpheuHookReturn:OnCheckWinConditions()
{
    CountTeamPlayers();

    if (get_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus") != WINNER_NONE)
		return OrpheuSupercede;
    
    new numTerrorists = get_gamerules_int("CHalfLifeMultiplay", "m_iNumSpawnableTerrorist");
    new numCts = get_gamerules_int("CHalfLifeMultiplay", "m_iNumSpawnableCT");

    if (numTerrorists + numCts < g_pMinPlayers)
    {
        set_gamerules_int("CHalfLifeMultiplay", "m_bFirstConnected", false);
    }

    if (!get_gamerules_int("CHalfLifeMultiplay", "m_bFirstConnected") && numTerrorists + numCts >= g_pMinPlayers)
    {
        set_gamerules_int("CGameRules", "m_bFreezePeriod", false);
        set_gamerules_int("CHalfLifeMultiplay", "m_bCompleteReset", true);

        remove_task(TASK_COUNTDOWN);
        remove_task(TASK_COMMENCING);
        GameCommencing(0);
        set_task(1.0, "GameCommencing", TASK_COMMENCING, _, _, "b");

        TerminateRound(5.0, WINSTATUS_DRAW);

        set_gamerules_int("CHalfLifeMultiplay", "m_bFirstConnected", true);

        return OrpheuSupercede;
    }

    if (g_IsGameStarted)
    {
		if (CountAliveHumans() <= 0)
		{
			TerminateRound(5.0, WINSTATUS_TERRORISTS);
            
            set_dhudmessage(255, 0, 0, -1.0, 0.2, 0, 0.0, 3.0, 1.0, 1.0);
            show_dhudmessage(0, "Zombies Win!");
		}
        else if (!g_AllowRespawn && CountAliveZombies() <= 0)
        {
			TerminateRound(5.0, WINSTATUS_CTS);
            
            set_dhudmessage(0, 255, 0, -1.0, 0.2, 0, 0.0, 3.0, 1.0, 1.0);
            show_dhudmessage(0, "Survivors Win!");
        }
    }

    return OrpheuSupercede;
}

public OrpheuHookReturn:OnPlayerCanRespawn(this, id)
{
	if (get_ent_data(id, "CBasePlayer", "m_iNumSpawns") > 0)
		return OrpheuIgnored;
    
    if (!g_IsGameStarted && (1 <= get_ent_data(id, "CBasePlayer", "m_iTeam") <= 2) && get_ent_data(id, "CBasePlayer", "m_iMenu") == 3)
		OrpheuSetReturn(true);
	else
		OrpheuSetReturn(false);
    
    return OrpheuOverride;
}

public OrpheuHookReturn:OnGiveDefaultItems(id)
{
    if (!pev_valid(id))
        return OrpheuIgnored;
    
    if (g_IsZombie[id])
        return OrpheuSupercede;

    strip_user_weapons(id);
    give_item(id, "weapon_knife");

    if (g_PlayerClass[id] == CLASS_SURVIVOR)
    {
        new weaponName[32] = "weapon_";
        add(weaponName, charsmax(weaponName), DEFAULT_ITEMS[random(sizeof DEFAULT_ITEMS)]);

        new weaponEnt = give_item(id, weaponName);
        new type = GetEntAmmoType(weaponEnt);

        new minAmmo = GetAmmoAmount(type);
        GiveAmmo(id, type, random_num(minAmmo, 200), 200);
    }

    return OrpheuSupercede;
}

public Event_NewRound()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (is_user_connected(i))
        {
            if (g_IsZombie[i])
            {
                g_IsZombie[i] = false;
                set_ent_data(i, "CBasePlayer", "m_bNotKilled", false);
            }

            g_PlayerClass[i] = CLASS_SURVIVOR;
        }
    }

    RandomPickPolices(false);

    g_IsGameStarted = false;
    g_AllowRespawn = false;

    set_pcvar_num(g_pAutoTeamBalance, 0);
    set_gamerules_int("CHalfLifeMultiplay", "m_iUnBalancedRounds", 1);

    remove_task(TASK_ROUNDSTART);
    remove_task(TASK_COMMENCING);
    remove_task(TASK_COUNTDOWN);
}

public Event_RoundStart()
{
    GameCountDown(0);
    set_task(1.0, "GameCountDown", TASK_COUNTDOWN, _, _, "b");
    set_task(20.0, "ExecuteGameStart", TASK_ROUNDSTART);
}

public Message_Corpse(msgid, msgdest, id)
{
    new model[128];
    get_msg_arg_string(1, model, charsmax(model));
    
    new Float:origin[3];
    origin[0] = float(get_msg_arg_int(2) / 128);
    origin[1] = float(get_msg_arg_int(3) / 128);
    origin[2] = float(get_msg_arg_int(4) / 128);

    new Float:angles[3];
    //angles[0] = get_msg_arg_float(5);
    angles[1] = get_msg_arg_float(6);
    angles[2] = get_msg_arg_float(7);

    new sequence = get_msg_arg_int(9);
    new team = get_msg_arg_int(11);
    new player = get_msg_arg_int(12);

    client_print(0, print_chat, "player id is %d", player);

    if (is_user_connected(player) && (1 <= get_ent_data(player, "CBasePlayer", "m_iTeam") <= 2) && !g_IsZombie[player])
    {
        new ent = create_entity("info_target");

        entity_set_origin(ent, origin);

        set_pev(ent, pev_classname, "corpse_entity");

        format(model, charsmax(model), "models/player/%s/%s.mdl", model, model);
        entity_set_model(ent, model);
        set_pev(ent, pev_solid, SOLID_TRIGGER);
        set_pev(ent, pev_movetype, MOVETYPE_TOSS);

        if (sequence == 110)
            entity_set_size(ent, Float:{-16.0, -16.0, -18.0}, Float:{16.0, 16.0, 32.0});
        else
            entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 18.0});

        set_pev(ent, pev_owner, player);
        set_pev(ent, pev_angles, angles);
        set_pev(ent, pev_animtime, get_gametime());
        set_pev(ent, pev_framerate, 0.0);
        set_pev(ent, pev_frame, 255.0);
        set_pev(ent, pev_health, 750.0);

        set_pev(ent, pev_sequence, sequence);

        set_pev(ent, pev_nextthink, get_gametime() + 60.0);
    }

    return PLUGIN_HANDLED;
}

public client_disconnected(id)
{
    g_IsZombie[id] = false;
    g_PlayerClass[id] = 0;

    remove_task(id + TASK_RESPAWN);
}

public OnCorpseThink(ent)
{
    if (!pev(ent, pev_iuser1))
    {
        set_pev(ent, pev_fuser1, get_gametime());
        set_pev(ent, pev_iuser1, true)
    }

    new Float:removeTime;
    pev(ent, pev_fuser1, removeTime);

    new Float:amt = 255.0 - (get_gametime() - removeTime) / 3.0 * 255.0;
    if (amt < 0.0)
    {
        remove_entity(ent);
        return;
    }

    set_pev(ent, pev_rendermode, kRenderTransAlpha);
    set_pev(ent, pev_renderamt, amt);

    set_pev(ent, pev_nextthink, get_gametime() + 0.01)
}

public OnCmdStart(id, uc)
{
    if (is_user_alive(id) && g_IsZombie[id])
    {
        new button = get_uc(uc, UC_Buttons);
        if (button & IN_USE)
        {
            new Float:origin[3];
            pev(id, pev_origin, origin);

            new classname[32];
            new ent = FM_NULLENT;

            while ((ent = find_ent_in_sphere(ent, origin, 30.0)))
            {
                if (!pev_valid(ent))
                    continue;
                
                pev(ent, pev_classname, classname, charsmax(classname))
                if (equal(classname, "corpse_entity") && !pev(ent, pev_iuser1))
                {
                    new Float:health;
                    pev(ent, pev_health, health);

                    set_user_health(id, get_user_health(id) + 1);
                    set_pev(ent, pev_health, health - 1);

                    if (health <= 0)
                    {
                        set_pev(ent, pev_nextthink, get_gametime());
                    }
                }
            }
        }
    }
}

public OnPlayerSpawn(id)
{
    if (!pev_valid(id))
        return;
    
    if (1 <= get_ent_data(id, "CBasePlayer", "m_iTeam") <= 2)
    {
        if (g_IsZombie[id])
        {
            set_ent_data(id, "CBasePlayer", "m_iTeam", TEAM_TERRORIST);
        }
        else
        {
            set_ent_data(id, "CBasePlayer", "m_iTeam", TEAM_CT);
        }
    }
}

public OnPlayerSpawn_Post(id)
{
    if (!is_user_alive(id))
        return;
    
    if (g_IsZombie[id])
        MakeZombie(id);
    else
        MakeHuman(id);
}

public OnPlayerKilled(id, attacker, shouldGibs)
{
    if (CanPlayerRespawn(id))
    {
        remove_task(id + TASK_RESPAWN);
		set_task(5.0, "RespawnPlayer", id + TASK_RESPAWN);
    }
}

public OnPlayerResetMaxSpeed_Post(id)
{
    if (is_user_alive(id) && g_IsZombie[id])
    {
        set_user_maxspeed(id, get_user_maxspeed(id) * 0.85);
    }
}

public OnPlayerTakeDamage(id, inflictor, attacker, Float:damage, damageBits)
{
	if (!pev_valid(id))
		return;
	
	if (GetHamReturnStatus() == HAM_SUPERCEDE)
		return;

	if (is_user_connected(attacker) && g_IsZombie[attacker] && !g_IsZombie[id] && inflictor == attacker)
	{
        damage *= 0.7;

        new lastHitGroup = get_ent_data(id, "CBaseMonster", "m_LastHitGroup");

        new Float:armor;
        pev(id, pev_armorvalue, armor);
		
		if (armor > 0.0 && (lastHitGroup == HIT_HEAD || lastHitGroup == HIT_CHEST || lastHitGroup == HIT_STOMACH))
		{
			new Float:armorRatio = 0.0;
			new Float:armorBonus = 0.5;

			new Float:newDamage = armorRatio * damage;
			new Float:armorDamage = (damage - newDamage) * armorBonus;
			
			if (armorDamage > armor)
			{
				armorDamage -= armor;
				armorDamage *= (1 / armorBonus);
				newDamage += armorDamage;
				
				set_pev(id, pev_armorvalue, 0.0);
			}
			else
			{
				set_pev(id, pev_armorvalue, armor - armorDamage);
			}
			
			if (newDamage < 1)
			{
				new Float:origin[3];
				ExecuteHam(Ham_EyePosition, attacker, origin);
				SendDamage(id, 0, 1, damageBits, origin);
			}
			
			damage = newDamage;			
			SetHamParamFloat(4, damage);
		}
	}
}

public OnPlayerTraceAttack(id, attacker, Float:damage, Float:dir[3], tr, damageType)
{
    if (g_IsZombie[attacker] && is_user_alive(attacker) && get_user_weapon(attacker) == CSW_KNIFE)
    {
        new hitGroup = get_tr2(0, TR_iHitgroup);
        if (hitGroup == HIT_LEFTARM || hitGroup == HIT_RIGHTARM)
        {
            SetHamParamFloat(3, damage * 0.5);
        }
    }
}

public OnKnifeDeploy_Post(ent)
{
	if (!pev_valid(ent))
		return;
	
	new player = get_ent_data_entity(ent, "CBasePlayerItem", "m_pPlayer");
	if (is_user_alive(player) && g_IsZombie[player])
	{
		set_pev(player, pev_viewmodel2, MODEL_ZOMBIE_KNIFE);
        set_pev(player, pev_weaponmodel2, "");
	}
}

public OnWeaponTouch(weapon, touched)
{
    if (is_user_alive(touched) && g_IsZombie[touched])
        return HAM_SUPERCEDE;

    return HAM_IGNORED;
}

public GameCommencing(taskid)
{
    static count;
    count = (taskid == 0) ? 5 : count;

    if (count <= 0)
    {
        remove_task(TASK_COMMENCING);
    }
    else
    {
        set_dhudmessage(0, 255, 0, -1.0, 0.3, 0, 0.0, 1.0, 0.0, 0.0);
        show_dhudmessage(0, "%d 秒後重新回合...", count);

        count--;
    }
}

public GameCountDown(taskid)
{
    static count;
    count = (taskid == 0) ? 20 : count;

    if (count <= 0)
    {
        remove_task(TASK_COUNTDOWN);
    }
    else
    {
        if (count <= 10)
        {
            new word[16];
            num_to_word(count, word, charsmax(word));

            client_cmd(0, "spk fvox/%s", word);
        }

        set_dhudmessage(0, 255, 0, -1.0, 0.25, 0, 0.0, 1.0, 0.0, 0.0);
        show_dhudmessage(0, "%d 秒後開始遊戲...", count);

        count--;
    }
}

public ExecuteGameStart()
{
    new playerList[32], playerCount;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!is_user_connected(i))
            continue;
        
        if (1 <= get_ent_data(i, "CBasePlayer", "m_iTeam") <= 2)
        {
            if (!is_user_alive(i))
                ExecuteHam(Ham_CS_RoundRespawn, i);
            
            playerList[playerCount++] = i;
        }
    }

    new count = 0;
    new maxZombies = floatround(playerCount * 0.225, floatround_ceil);
    new player;

    while (count < maxZombies)
    {
        player = GetRandomPlayer(playerList, playerCount, true);
        MakeZombie(player);
        count++;
    }

    RandomPickPolices(true);

    for (new i = 0; i < playerCount; i++)
    {
        player = playerList[i];
        cs_set_user_team(player, CS_TEAM_CT, CS_NORESET, true);
    }

    g_IsGameStarted = true;
    g_AllowRespawn = true;

    set_dhudmessage(0, 255, 0, -1.0, 0.25, 0, 0.0, 3.0, 1.0, 1.0);
    show_dhudmessage(0, "這地圖發生了一宗病毒感染事件!", count);
}

public RespawnPlayer(taskid)
{
    new id = taskid - TASK_RESPAWN;

	if (CanPlayerRespawn(id))
	{
        g_IsZombie[id] = true;
        ExecuteHam(Ham_CS_RoundRespawn, id);
	}
}

public SelectPrimaryWeapon(id)
{
    new menu = menu_create("Select your primary weapon:", "HandleMenuPrimrayWeapon");

    for (new i = 0; i < sizeof DEFAULT_ITEMS2_PRI; i++)
    {
        menu_additem(menu, DEFAULT_NAME_PRI[i], DEFAULT_ITEMS2_PRI[i]);
    }

    menu_display(id, menu);
}

public HandleMenuPrimrayWeapon(id, menu, item)
{
    if (item == MENU_EXIT || !is_user_alive(id) || g_IsZombie[id] || g_PlayerClass[id] != CLASS_POLICE)
    {
        menu_destroy(menu);
        return;
    }

    new info[32], dummy;
    menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, dummy);
    menu_destroy(menu);

    DropWeapons(id, 1);

    new weapon[32] = "weapon_";
    add(weapon, charsmax(weapon), info);

    new ent = give_item(id, weapon);
    new type = GetEntAmmoType(ent);
    GiveFullAmmo(id, type);

    SelectSecondaryWeapon(id);
}

public SelectSecondaryWeapon(id)
{
    new menu = menu_create("Select your secondary weapon:", "HandleMenuSecondrayWeapon");

    for (new i = 0; i < sizeof DEFAULT_ITEMS2_SEC; i++)
    {
        menu_additem(menu, DEFAULT_NAME_SEC[i], DEFAULT_ITEMS2_SEC[i]);
    }

    menu_display(id, menu);
}

public HandleMenuSecondrayWeapon(id, menu, item)
{
    if (item == MENU_EXIT || !is_user_alive(id) || g_IsZombie[id] || g_PlayerClass[id] != CLASS_POLICE)
    {
        menu_destroy(menu);
        return;
    }

    new info[32], dummy;
    menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, dummy);
    menu_destroy(menu);

    DropWeapons(id, 2);

    new weapon[32] = "weapon_";
    add(weapon, charsmax(weapon), info);

    new ent = give_item(id, weapon);
    new type = GetEntAmmoType(ent);
    GiveFullAmmo(id, type);
}

public native_is_user_zombie()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return false;

    return g_IsZombie[id];
}

stock RandomPickPolices(bool:make=true)
{
    new count = 0, zombieCount = 0;
    new playerList[32], playerCount = 0;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!is_user_connected(i))
            continue;
        
        if (1 <= get_ent_data(i, "CBasePlayer", "m_iTeam") <= 2)
        {
            if (g_IsZombie[i])
                zombieCount++
            else if (g_PlayerClass[i] == CLASS_POLICE)
                count++;
            else
                playerList[playerCount++] = i;
        }
    }

    new maxPolices = floatround((playerCount + zombieCount + count) * 0.3, floatround_ceil);
    new player;

    while (count < maxPolices)
    {
        player = GetRandomPlayer(playerList, playerCount, true);
        g_PlayerClass[player] = CLASS_POLICE;

        if (make)
            MakeHuman(player);
        
        count++;
    }
}

stock TerminateRound(Float:delay, status)
{
    set_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus", status);
    set_gamerules_float("CHalfLifeMultiplay", "m_fTeamCount", get_gametime() + delay);
    set_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating", true);
}

stock bool:CanPlayerRespawn(id, bool:checkAlive=true)
{
	if (!g_AllowRespawn || !g_IsGameStarted)
		return false;
	
	if (get_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus"))
		return false;
	
	if (!(1 <= get_ent_data(id, "CBasePlayer", "m_iTeam") <= 2) || get_ent_data(id, "CBasePlayer", "m_iMenu") == 3)
		return false;
	
	if (checkAlive && is_user_alive(id))
		return false;
	
	return true;
}

stock CountAliveHumans()
{
    new count = 0;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!is_user_alive(i))
			continue;
        
        if (!g_IsZombie[i])
            count++;
    }

    return count;
}

stock CountAliveZombies()
{
    new count = 0;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!is_user_alive(i))
			continue;
        
        if (g_IsZombie[i])
            count++;
    }

    return count;
}

stock CountTeamPlayers()
{
	new numCT = 0;
	new numTerrorist = 0;
	new numSpawnableCT = 0;
	new numSpawnableTerrorist = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		switch (get_ent_data(i, "CBasePlayer", "m_iTeam"))
		{
			case 1:
			{
				if (get_ent_data(i, "CBasePlayer", "m_iMenu") != 3)
					numSpawnableTerrorist++;
				
				numTerrorist++;
			}
			case 2:
			{
				if (get_ent_data(i, "CBasePlayer", "m_iMenu") != 3)
					numSpawnableCT++;
				
				numCT++
			}
		}
	}

	set_gamerules_int("CHalfLifeMultiplay", "m_iNumCT", numCT);
	set_gamerules_int("CHalfLifeMultiplay", "m_iNumTerrorist", numTerrorist);
	set_gamerules_int("CHalfLifeMultiplay", "m_iNumSpawnableCT", numSpawnableCT);
	set_gamerules_int("CHalfLifeMultiplay", "m_iNumSpawnableTerrorist", numSpawnableTerrorist);
}

stock GetRandomPlayer(playerList[32], &playerCount, bool:remove)
{
    new i = random(playerCount);
    new player = playerList[i];

    if (remove)
        playerList[i] = playerList[--playerCount];
    
    return player;
}

stock MakeHuman(id)
{
    g_IsZombie[id] = false;

    cs_set_user_team(id, CS_TEAM_CT, CS_NORESET, true);

    if (g_PlayerClass[id] == CLASS_SURVIVOR)
    {
        cs_set_user_model(id, MODEL_SURVIVORS[random(sizeof MODEL_SURVIVORS)]);

        set_pev(id, pev_health, 100.0);
        set_pev(id, pev_max_health, 100.0);
        set_user_gravity(id, 1.0);

        if (random_num(0, 1))
            cs_set_user_armor(id, 0, CS_ARMOR_NONE);
        else
            cs_set_user_armor(id, random_num(1, 60), CS_ARMOR_NONE);
        
        if (!random_num(0, 3))
            give_item(id, "weapon_flashbang");
    }
    else if (g_PlayerClass[id] == CLASS_POLICE)
    {
        cs_set_user_model(id, MODEL_POLICE[random(sizeof MODEL_POLICE)]);

        set_pev(id, pev_health, 150.0);
        set_pev(id, pev_max_health, 150.0);
        set_user_gravity(id, 0.95);

        if (random_num(0, 1))
            cs_set_user_armor(id, random_num(70, 100), CS_ARMOR_NONE);
        else
            cs_set_user_armor(id, random_num(60, 100), CS_ARMOR_NONE);
        
        if (random_num(0, 1))
            give_item(id, "weapon_flashbang");
        if (!random_num(0, 2))
            give_item(id, "weapon_hegrenade");
        if (!random_num(0, 3))
            give_item(id, "weapon_smokegrenade");

        SelectPrimaryWeapon(id);
    }

    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

    new ret;
    ExecuteForward(g_Forward[FWD_MAKE_HUMAN], ret, id);
}

stock MakeZombie(id, attacker=0)
{
    g_IsZombie[id] = true;

    cs_set_user_team(id, CS_TEAM_T, CS_NORESET, true);
    cs_set_user_model(id, MODEL_ZOMBIE);

    set_pev(id, pev_health, 1000.0);
    set_pev(id, pev_max_health, 1000.0);
    set_user_gravity(id, 1.0);
    cs_set_user_armor(id, 0, CS_ARMOR_NONE);

    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);

    DropWeapons(id, 0);

    strip_user_weapons(id);
    give_item(id, "weapon_knife");

    new ret;
    ExecuteForward(g_Forward[FWD_MAKE_ZOMBIE], ret, id, attacker);
}

stock DropWeapons(id, slot=0)
{
    new class[32];

	for (new i = 1; i <= 5; i++)
	{
		if (slot && slot != i)
			continue;
		
		new weapon = get_ent_data_entity(id, "CBasePlayer", "m_rgpPlayerItems", i);
		
		while (pev_valid(weapon))
		{
			if (ExecuteHamB(Ham_CS_Item_CanDrop, weapon))
			{
				pev(weapon, pev_classname, class, charsmax(class));
				engclient_cmd(id, "drop", class);
			}
			
			weapon = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pNext");
		}
	}
}

stock SendDamage(id, dmgSave, dmgTake, damageBits, Float:origin[3])
{
	static msgDamage;
	msgDamage || (msgDamage = get_user_msgid("Damage"));
	
	message_begin(MSG_ONE_UNRELIABLE, msgDamage, _, id);
	write_byte(dmgSave); // damage save
	write_byte(dmgTake); // damage take
	write_long(damageBits); // damage type
	write_coord_f(origin[0]); // x
	write_coord_f(origin[1]); // y
	write_coord_f(origin[2]); // z
	message_end();
}