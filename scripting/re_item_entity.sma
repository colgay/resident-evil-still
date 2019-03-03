#include <amxmodx>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <resident_evil>
#include <re_inventory>

enum _:MaxItems
{
    ITEM_FIRSTAID = 0,
    ITEM_HERB,
    AMMO_HANDGUN,
    AMMO_50AE,
    AMMO_SHOTGUN,
    AMMO_SMG,
    AMMO_RIFLE,
    AMMO_SNIPER,
    AMMO_AWP,
    AMMO_MACHINE
};

new const Float:ITEM_CHANCES[] = {0.4, 0.6, 0.6, 0.2, 0.4, 0.5, 0.35, 0.3, 0.2, 0.25};

public plugin_precache()
{
    precache_model("models/w_medkit.mdl");
    precache_model("models/w_medkitt.mdl");

    precache_model("models/w_rad.mdl");
    precache_model("models/w_radt.mdl");

    precache_model("models/w_9mmclip.mdl");
    precache_model("models/w_9mmclipt.mdl");

    precache_model("models/resident_evil_test/w_50ae.mdl");
    precache_model("models/resident_evil_test/w_50aet.mdl");

    precache_model("models/w_shotshell.mdl");
    precache_model("models/w_shotshellt.mdl");

    precache_model("models/w_9mmarclip.mdl");
    precache_model("models/w_9mmarclipt.mdl");

    precache_model("models/resident_evil_test/w_556nato.mdl");
    precache_model("models/resident_evil_test/w_556natot.mdl");

    precache_model("models/resident_evil_test/w_762nato.mdl");
    precache_model("models/resident_evil_test/w_762natot.mdl");

    precache_model("models/resident_evil_test/w_338magnum.mdl");
    precache_model("models/resident_evil_test/w_338magnumt.mdl");

    precache_model("models/w_chainammo.mdl");
    precache_model("models/w_chainammot.mdl");
}

public plugin_init()
{
    register_plugin("RE: Item Entity", "0.1", "Holla");

    register_clcmd("powerful", "CmdPowerful");

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", 1);

    register_touch("item_entity", "player", "OnPlayerTouchItem");
}

public CmdPowerful(id)
{
    set_pev(id, pev_armorvalue, 999.0);
    set_pev(id, pev_health, 999.0);
    give_item(id, "weapon_ak47");
    re_give_named_item(id, "ammo_rifle", 100, false);
    re_give_named_item(id, "ammo_handgun", 50, false);
}

public OnPlayerKilled_Post(id, attacker)
{
    if (re_is_user_zombie(id))
    {
        new rand = random(MaxItems);
        if (random_float(0.0, 1.0) <= ITEM_CHANCES[rand])
        {
            new Float:origin[3];
            pev(id, pev_origin, origin);

            CreateItemEntity(rand, origin);
        }
    }
}

public OnPlayerTouchItem(entity, id)
{
    if (is_user_alive(id) && !re_is_user_zombie(id))
    {
        new class[32];
        pev(entity, pev_netname, class, charsmax(class));

        new amount = pev(entity, pev_iuser1);
        if (amount < 1)
            amount = 1;

        re_give_named_item(id, class, amount, false);

        client_print(0, print_chat, "[TEST] %n picked up %s x %d", id, class, amount);

        remove_entity(entity);
    }
}

stock CreateItemEntity(item, Float:origin[3])
{
    new ent = create_entity("info_target");

    entity_set_origin(ent, origin);

    set_pev(ent, pev_classname, "item_entity");

    switch (item)
    {
        case ITEM_FIRSTAID:
        {
            entity_set_model(ent, "models/w_medkit.mdl");
            set_pev(ent, pev_netname, "item_firstaid");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
        }
        case ITEM_HERB:
        {
            entity_set_model(ent, "models/w_rad.mdl");
            set_pev(ent, pev_netname, "item_herb");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
        }
        case AMMO_HANDGUN:
        {
            entity_set_model(ent, "models/w_9mmclip.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_handgun");
            set_pev(ent, pev_iuser1, random_num(30, 100));
        }
        case AMMO_50AE:
        {
            entity_set_model(ent, "models/resident_evil_test/w_50ae.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_50ae");
            set_pev(ent, pev_iuser1, random_num(1, 14));
        }
        case AMMO_SHOTGUN:
        {
            entity_set_model(ent, "models/w_shotshell.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_shotgun");
            set_pev(ent, pev_iuser1, random_num(8, 24));
        }
        case AMMO_SMG:
        {
            entity_set_model(ent, "models/w_9mmarclip.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_smg");
            set_pev(ent, pev_iuser1, random_num(40, 60));
        }
        case AMMO_RIFLE:
        {
            entity_set_model(ent, "models/resident_evil_test/w_556nato.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_rifle");
            set_pev(ent, pev_iuser1, random_num(40, 60));
        }
        case AMMO_SNIPER:
        {
            entity_set_model(ent, "models/resident_evil_test/w_762nato.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_sniper");
            set_pev(ent, pev_iuser1, random_num(30, 60));
        }
        case AMMO_AWP:
        {
            entity_set_model(ent, "models/resident_evil_test/w_338magnum.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_awp");
            set_pev(ent, pev_iuser1, random_num(5, 20));
        }
        case AMMO_MACHINE:
        {
            entity_set_model(ent, "models/w_chainammo.mdl");
            set_pev(ent, pev_solid, SOLID_TRIGGER);
            set_pev(ent, pev_netname, "ammo_machine");
            set_pev(ent, pev_iuser1, random_num(50, 100));
        }
    }

    set_pev(ent, pev_movetype, MOVETYPE_TOSS);
}