#include <amxmodx>
#include <cstrike>
#include <re_inventory>
#include <ammo>

enum _:AMMODATA
{
    AMMO_HANDGUN = 0,
    AMMO_50AE,
    AMMO_SHOTGUN,
    AMMO_SMG,
    AMMO_RIFLE,
    AMMO_SNIPER,
    AMMO_AWP,
    AMMO_MACHINE
};

new const g_WeaponAmmoTypes[] = 
{
	-1,
	0, //p228
	-1,
	5, //scout
	-1, //hegrenade
	2, //xm1014
	-1, //c4
	3, //mac10
	4, //aug
	-1, //smoke
	0, //elite
	0, //fiveseven
	3, //ump45
	5, //sg550
	4, //galil
	4, //famas
	0, //usp
	0, //glock
	6, //awp
	3, //mp5
	7, //m249
	2, //m3
	4, //m4a1
	3, //tmp
	5, //g3sg1
	-1, //flash
	1, //deagle
	4, //sg552
	4, //ak47
	-1,
	3 //p90
};

new g_items[AMMODATA];
new bool:g_Reloaded;
new gmsgAmmoPickup;

public plugin_init()
{
    register_plugin("RE Item: Ammo", "0.1", "Holla");

    new const NO_RELOAD = (1 << 2) | (1 << CSW_KNIFE) | (1 << CSW_C4) | (1 << CSW_M3) |
        (1 << CSW_XM1014) | (1 << CSW_HEGRENADE) | (1 << CSW_FLASHBANG) | (1 << CSW_SMOKEGRENADE);
    
    new weaponname[20];

    for(new i = CSW_P228; i <= CSW_P90; i++)
    {
        if (NO_RELOAD & (1 << i))
            continue;
        
        get_weaponname(i, weaponname, 19);
        
        RegisterHam(Ham_Item_Deploy, weaponname, "OnItemDeploy_Post", 1);
        RegisterHam(Ham_Item_PostFrame, weaponname, "OnItemPostFrame");
        RegisterHam(Ham_Item_PostFrame, weaponname, "OnItemPostFrame_Post", 1);
    }

    RegisterHam(Ham_GiveAmmo, "player", "OnGiveAmmo");

    g_items[AMMO_HANDGUN] = re_create_item("手槍彈藥", "ammo_handgun", "手槍的彈藥", 100);
    g_items[AMMO_50AE] = re_create_item(".50AE 彈藥", "ammo_50ae", "重型手槍的彈藥", 14);
    g_items[AMMO_SHOTGUN] = re_create_item("散彈槍彈藥", "ammo_shotgun", "散彈槍的彈藥", 32);
    g_items[AMMO_SMG] = re_create_item("衝鋒槍彈藥", "ammo_smg", "衝鋒槍的彈藥", 90);
    g_items[AMMO_RIFLE] = re_create_item("步槍彈藥", "ammo_rifle", "步槍的彈藥", 60);
    g_items[AMMO_SNIPER] = re_create_item("狙擊槍彈藥", "ammo_sniper", "狙擊槍的彈藥", 40);
    g_items[AMMO_AWP] = re_create_item("重型狙擊槍彈藥", "ammo_awp", "重型狙擊槍的彈藥", 10);
    g_items[AMMO_MACHINE] = re_create_item("重型機槍彈藥", "ammo_machine", "重型機槍的彈藥", 50);

    gmsgAmmoPickup = get_user_msgid("AmmoPickup");
}

public OnItemDeploy_Post(weapon)
{
    new player = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pPlayer");
    if (!pev_valid(player))
        return;
    
    new weaponid = get_ent_data(weapon, "CBasePlayerItem", "m_iId");
    new type = g_WeaponAmmoTypes[weaponid];
    if (type == -1)
        return;
    
    new item = g_items[type];
    new count = re_count_user_items(player, item);
    
    new ammotype = get_ent_data(weapon, "CBasePlayerWeapon", "m_iPrimaryAmmoType");
    set_ent_data(player, "CBasePlayer", "m_rgAmmo", count, ammotype);
}

public OnItemPostFrame(weapon)
{
    g_Reloaded = false;

    if (get_ent_data(weapon, "CBasePlayerWeapon", "m_fInReload"))
	{
        new player = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pPlayer");
        if (!pev_valid(player))
            return;
        
        if (get_ent_data_float(player, "CBaseMonster", "m_flNextAttack") <= get_gametime())
            g_Reloaded = true;
	}
}

public OnItemPostFrame_Post(weapon)
{
    if (g_Reloaded)
    {
        g_Reloaded = false;

        new player = get_ent_data_entity(weapon, "CBasePlayerItem", "m_pPlayer");
        if (!pev_valid(player))
            return;

        new weaponid = get_ent_data(weapon, "CBasePlayerItem", "m_iId");
        new type = g_WeaponAmmoTypes[weaponid];
        if (type == -1)
            return;
        
        new item = g_items[type];
        new count = re_count_user_items(player, item);
        new ammotype = get_ent_data(weapon, "CBasePlayerWeapon", "m_iPrimaryAmmoType");
        new ammo = get_ent_data(player, "CBasePlayer", "m_rgAmmo", ammotype);
        if (count > 0)
            re_remove_user_item(player, item, count - ammo);
    }
}

public OnGiveAmmo(player, amount, const ammoName[], max)
{
    if (equal(ammoName, "Flashbang") || equal(ammoName, "HEGrenade") || equal(ammoName, "SmokeGrenade"))
        return HAM_IGNORED;
    
    return HAM_SUPERCEDE;
}

public re_on_give_item(id, item)
{
    UpdateAmmo(id, item);
}

public re_on_remove_item(id, item)
{
    UpdateAmmo(id, item);
}

stock UpdateAmmo(id, item)
{
    new weapon = get_user_weapon(id);
    new type = g_WeaponAmmoTypes[weapon];
    if (type == -1)
        return;
    
    new item2 = g_items[type];
    if (item2 != item || item == -1)
        return;
    
    new count = re_count_user_items(id, item2);
    cs_set_user_bpammo(id, weapon, count);
}