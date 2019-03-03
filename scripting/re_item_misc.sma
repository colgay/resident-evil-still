#include <amxmodx>
#include <fakemeta>
#include <re_inventory>

enum _:MaxItems
{
    ITEM_FIRSTAID = 0,
    ITEM_HERB,
}

new g_items[MaxItems];

public plugin_init()
{
    register_plugin("RE: Item Misc", "0.1", "Holla");

    g_items[ITEM_FIRSTAID] = re_create_item("急救包", "item_firstaid", "恢復 80% 生命值", 1);
    g_items[ITEM_HERB] = re_create_item("草藥", "item_herb", "恢復 30% 生命值", 3);
}

public re_on_use_item(id, slot)
{
    new item = re_get_slot_item(id, slot);

    if (item == g_items[ITEM_FIRSTAID])
    {
        new Float:maxhp, Float:hp;
        pev(id, pev_max_health, maxhp);
        pev(id, pev_health, hp);

        set_pev(id, pev_health, floatmin(hp + (maxhp * 0.8), maxhp));

        client_print(id, print_chat, "你使用了急救包 1 個.");

        re_remove_slot_item(id, slot, 1);
    }
    else if (item == g_items[ITEM_HERB])
    {
        new Float:maxhp, Float:hp;
        pev(id, pev_max_health, maxhp);
        pev(id, pev_health, hp);

        set_pev(id, pev_health, floatmin(hp + (maxhp * 0.3), maxhp));

        client_print(id, print_chat, "你使用了草藥 1 個.");

        re_remove_slot_item(id, slot, 1);
    }
}