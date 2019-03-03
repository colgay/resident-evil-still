#include <amxmodx>
#include <amxmisc>

#define MAX_SLOTS 35
#define NULL -1

#define ACTION_MOVE 1
#define ACTION_HALF 2

enum _:ItemData
{
    Array:ITEM_NAME,
    Array:ITEM_CLASS,
    Array:ITEM_DESC,
    Array:ITEM_AMT,
    ITEM_COUNT,
};

enum _:ForwardData
{
    FWD_GIVE_ITEM,
    FWD_REMOVE_ITEM,
    FWD_USE_ITEM,
};

new g_Items[ItemData];
new g_Forwards[ForwardData];

new g_Inventory[MAX_PLAYERS + 1][MAX_SLOTS];
new g_Inventory2[MAX_PLAYERS + 1][MAX_SLOTS];
new g_MaxSlots[MAX_PLAYERS + 1] = {8, ...};

new g_MenuPage[MAX_PLAYERS + 1];
new g_MenuSlot[MAX_PLAYERS + 1] = {NULL, ...};
new g_MenuAction[MAX_PLAYERS + 1];

public plugin_precache()
{
    g_Items[ITEM_NAME] = ArrayCreate(32);
    g_Items[ITEM_CLASS] = ArrayCreate(32);
    g_Items[ITEM_DESC] = ArrayCreate(128);
    g_Items[ITEM_AMT] = ArrayCreate(1);
}

public plugin_init()
{
    register_plugin("RE: Inventory", "0.2", "Holla");

    register_clcmd("inventory", "CmdInventory");
    register_clcmd("give_item", "CmdGiveItem");

    register_menucmd(register_menuid("Info"), 1023, "HandleMenuInfo");

    for (new i = 1; i <= MaxClients; i++)
    {
        arrayset(g_Inventory[i], NULL, sizeof g_Inventory[]);
    }


    g_Forwards[FWD_GIVE_ITEM] = CreateMultiForward("re_on_give_item", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forwards[FWD_REMOVE_ITEM] = CreateMultiForward("re_on_remove_item", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forwards[FWD_USE_ITEM] = CreateMultiForward("re_on_use_item", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives()
{
	register_library("re_inventory");

	register_native("re_give_user_item", "native_give_user_item");
    register_native("re_give_named_item", "native_give_named_item");
    register_native("re_remove_user_item", "native_remove_user_item");
    register_native("re_remove_named_item", "native_remove_named_item");
    register_native("re_remove_slot_item", "native_remove_slot_item");
    register_native("re_count_user_items", "native_count_user_items");
    register_native("re_get_slot_item", "native_get_slot_item");

    register_native("re_create_item", "native_create_item");
    register_native("re_find_item_by_class", "native_find_item_by_class");
    register_native("re_get_item_name", "native_get_item_name");
    register_native("re_get_item_class", "native_get_item_class");
    register_native("re_get_item_amt", "native_get_item_amt");
}

public CmdInventory(id)
{
    g_MenuAction[id] = 0;
    g_MenuSlot[id] = NULL;
    ShowMenuInventory(id);
}

public CmdGiveItem(id)
{
	new arg[32], arg2[32], arg3[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
    read_argv(3, arg3, charsmax(arg3));

    new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);

	new amount = str_to_num(arg3);

	GiveNamedItem(player, arg2, amount, false);
	return PLUGIN_HANDLED;
}

public ShowMenuInventory(id)
{
    new item, amt, max;

    new buff[128], name[32];
    new slot = g_MenuSlot[id];

	if (g_MenuAction[id] == ACTION_MOVE && g_Inventory[id][slot] != NULL)
	{
        item = g_Inventory[id][slot];
        amt = g_Inventory2[id][slot];
        max = GetItemAmount(item);
		GetItemName(item, name, charsmax(name));

		formatex(buff, charsmax(buff), "選擇把 \d#%d \w%s \y(%d/%d) 移動到的位置...", g_MenuSlot[id], name, amt, max);
	}
	else if (g_MenuAction[id] == ACTION_HALF && g_Inventory[id][slot] != NULL)
	{
        item = g_Inventory[id][slot];
        amt = g_Inventory2[id][slot];
        max = GetItemAmount(item);
		GetItemName(item, name, charsmax(name));

		formatex(buff, charsmax(buff), "選擇把 \d#%d \w%s \y(%d/%d) 分成一半的空位...", g_MenuSlot[id], name, amt, max);
	}
    else
    {
        formatex(buff, charsmax(buff), "Inventory");
    }

    new menu = menu_create(buff, "HandleMenuInventroy");

    for (new i = 0; i < g_MaxSlots[id]; i++)
    {
        item = g_Inventory[id][i];

        if (item != NULL)
        {
            GetItemName(item, name, charsmax(name));
            max = GetItemAmount(item);
            amt = g_Inventory2[id][i];

            if (slot == i)
                formatex(buff, charsmax(buff), "\d#%d %s [%d/%d]", i, name, amt, max);
            else
                formatex(buff, charsmax(buff), "\d#%d \w%s \y[%d/%d]", i, name, amt, max);
        }
        else
        {
            formatex(buff, charsmax(buff), "\d---");
        }

        menu_additem(menu, buff);
    }

	menu_setprop(menu, MPROP_NUMBER_COLOR, "\y");
	menu_display(id, menu, g_MenuPage[id]);
}

public HandleMenuInventroy(id, menu, i)
{
    menu_destroy(menu);

	if (is_user_connected(id))
	{
		new dummy;
		player_menu_info(id, dummy, dummy, g_MenuPage[id]);
	}

    if (i == MENU_EXIT)
        return;
    
    if (g_MenuAction[id] == ACTION_MOVE)
    {
		new slot = g_MenuSlot[id];
        new item = g_Inventory[id][i];
        new max = (item != NULL) ? GetItemAmount(item) : 0;

		if (item == g_Inventory[id][slot] && g_Inventory2[id][i] < max)
		{
			g_Inventory2[id][i] += g_Inventory2[id][slot];
			g_Inventory2[id][slot] = 0;
			g_Inventory[id][slot] = NULL;

			if (g_Inventory2[id][i] > max)
			{
				g_Inventory2[id][slot] = g_Inventory2[id][i] - max;
				g_Inventory2[id][i] = max;
				g_Inventory[id][slot] = item;
			}
		}
		else
		{
			new amt = g_Inventory2[id][i]

			g_Inventory[id][i] = g_Inventory[id][slot];
			g_Inventory2[id][i] = g_Inventory2[id][slot];

			g_Inventory[id][slot] = item;
			g_Inventory2[id][slot] = amt; 
		}

        g_MenuSlot[id] = NULL;
		g_MenuAction[id] = 0;

        ShowMenuInventory(id);
    }
    else if (g_MenuAction[id] == ACTION_HALF)
    {
        new slot = g_MenuSlot[id];
        new item = g_Inventory[id][slot];

        if (item != NULL && g_Inventory[id][i] == NULL)
        {
            new amt = g_Inventory2[id][slot];
            if (amt > 1)
            {
                g_Inventory[id][i] = item;
                g_Inventory2[id][i] = amt / 2;
                g_Inventory2[id][slot] = amt - g_Inventory2[id][i];
            }
        }

        g_MenuSlot[id] = NULL;
		g_MenuAction[id] = 0;

        ShowMenuInventory(id);
    }
    else
    {
        new item = g_Inventory[id][i];
        if (item != NULL)
        {
            ShowMenuInfo(id, i);
        }
        else
        {
            ShowMenuInventory(id);
        }
    }
}

public ShowMenuInfo(id, slot)
{
    new item = g_Inventory[id][slot];
    new amt = g_Inventory2[id][slot];
    new max = GetItemAmount(item);

	new name[32], desc[128];
	GetItemName(item, name, charsmax(name));
	GetItemDesc(item, desc, charsmax(desc));

    new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9;

	static menu[512], len;

	len = formatex(menu, 511, "\y如何處理 \d#%d \w%s \y(%d/%d) ?^n", slot, name, amt, max);
	len += formatex(menu[len], 511-len, "\w%s^n^n", desc);
	
	len += formatex(menu[len], 511-len, "\y1. \w使用^n");
    len += formatex(menu[len], 511-len, "\y2. \w移位^n");
    len += formatex(menu[len], 511-len, "\y3. \w分成一半^n");
	len += formatex(menu[len], 511-len, "\y9. \w丟棄 %d 個^n", amt);
	
	len += formatex(menu[len], 511-len, "^n\y0. \w返回");

	g_MenuSlot[id] = slot;
	show_menu(id, keys, menu, -1, "Info");
}

public HandleMenuInfo(id, key)
{
	if (key == 9)
	{
		ShowMenuInventory(id);
		return;
	}

    new slot = g_MenuSlot[id];

    new item = g_Inventory[id][slot];
    if (item == NULL)
        return;
    
    new name[32];
    GetItemName(item, name, charsmax(name));

	switch (key)
	{
		case 0:
		{
            new ret;
            ExecuteForward(g_Forwards[FWD_USE_ITEM], ret, id, slot);
		}
		case 1:
		{
			g_MenuAction[id] = ACTION_MOVE;
			ShowMenuInventory(id);
		}
		case 2:
		{
			g_MenuAction[id] = ACTION_HALF;
			ShowMenuInventory(id);
		}
		case 8:
		{
            RemoveSlotItem(id, slot, g_Inventory2[id][slot]);
		}
	}
}

public native_give_user_item()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return NULL;

    new item = get_param(2);
    if (item < 0 || item >= g_Items[ITEM_COUNT])
        return NULL;

    new amount = get_param(3);
    new bool:checkSpace = bool:get_param(4);

    return GiveItem(id, item, amount, checkSpace);
}

public native_give_named_item()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return NULL;

    new name[32];
    get_string(2, name, charsmax(name));

    new amount = get_param(3);
    new bool:checkSpace = bool:get_param(4);

    return GiveNamedItem(id, name, amount, checkSpace);
}

public native_remove_user_item()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return NULL;

    new item = get_param(2);
    if (item < 0 || item >= g_Items[ITEM_COUNT])
        return NULL;

    new amount = get_param(3);

    return RemoveItem(id, item, amount);
}

public native_remove_named_item()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return NULL;

    new name[32];
    get_string(2, name, charsmax(name));

    new amount = get_param(3);
    return RemoveNamedItem(id, name, amount);
}

public native_remove_slot_item()
{
    new id = get_param(1);
    if (!is_user_connected(id))
        return 0;
    
    new slot = get_param(2);
    if (slot < 0 || slot >= MAX_SLOTS || g_Inventory[id][slot] == NULL)
        return 0;
    
    new amount = get_param(3);
    RemoveSlotItem(id, slot, amount);
    return 1;
}

public native_count_user_items()
{
	new id = get_param(1)
	if (!is_user_connected(id))
		return 0;

	new item = get_param(2);
	if (item < 0 || item >= g_Items[ITEM_COUNT])
        return 0;

	return CountItems(id, item);
}

public native_get_slot_item()
{
	new id = get_param(1)
	if (!is_user_connected(id))
		return NULL;
    
    new slot = get_param(2);
    if (slot < 0 || slot >= MAX_SLOTS)
        return NULL

    return g_Inventory[id][slot];
}

public native_create_item()
{
	new name[32], class[32], desc[128];
	get_string(1, name, charsmax(name));
	get_string(2, class, charsmax(class));
	get_string(3, desc, charsmax(desc));

	new amount = get_param(4);
	return CreateItem(name, class, desc, amount);
}

public native_find_item_by_class()
{
	new string[32];
	get_string(1, string, charsmax(string));

	return FindItemByClass(string);
}

public native_get_item_name()
{
    new item = get_param(1);
	if (item < 0 || item >= g_Items[ITEM_COUNT])
        return 0;

    new string[32];
    GetItemName(item, string, charsmax(string));

    new len = get_param(3);
    set_string(2, string, len);
    return 1;
}

public native_get_item_class()
{
    new item = get_param(1);
	if (item < 0 || item >= g_Items[ITEM_COUNT])
        return 0;

    new string[32];
    GetItemClass(item, string, charsmax(string));

    new len = get_param(3);
    set_string(2, string, len);
    return 1;
}

public native_get_item_amt()
{
    new item = get_param(1);
	if (item < 0 || item >= g_Items[ITEM_COUNT])
        return NULL;

    return GetItemAmount(item);
}

stock GiveItem(id, item, amount, bool:checkSpace)
{
    new max = GetItemAmount(item);
    new remains = amount;
    
    if (checkSpace)
    {
        for (new i = 0; i < g_MaxSlots[id]; i++)
        {
            if (remains <= 0)
                break;
            
            if (g_Inventory[id][i] == NULL
            || (g_Inventory[id][i] == item && g_Inventory2[id][i] < max))
            {
                new count = min(max - g_Inventory2[id][i], remains);
                remains -= count;
            }
        }
        
        if (remains > 0)
            return NULL;
    }
    
    remains = amount;
    
    for (new i = 0; i < g_MaxSlots[id]; i++)
    {
        if (remains <= 0)
            break;
        
        if (g_Inventory[id][i] == NULL
        || (g_Inventory[id][i] == item && g_Inventory2[id][i] < max))
        {
            new count = min(max - g_Inventory2[id][i], remains);
            g_Inventory[id][i] = item;
            g_Inventory2[id][i] += count;
            remains -= count;
        }
    }
    
    new ret;
    ExecuteForward(g_Forwards[FWD_GIVE_ITEM], ret, id, item);
    return amount - remains;
}

stock GiveNamedItem(id, const class[], amount, bool:checkSpace)
{
	new item = FindItemByClass(class);
	if (item != NULL)
	{
		return GiveItem(id, item, amount, checkSpace);
	}
	
	return NULL;
}

stock RemoveItem(id, item, amount)
{
    new remains = amount;
    
    for (new i = (g_MaxSlots[id] - 1); i >= 0; i--)
    {
        if (remains <= 0)
            break;
        
        if (g_Inventory[id][i] == item)
        {
            if (remains >= g_Inventory2[id][i])
            {
                remains -= g_Inventory2[id][i];
                g_Inventory[id][i] = NULL;
                g_Inventory2[id][i] = 0;
            }
            else
            {
                g_Inventory2[id][i] -= remains;
                remains = 0;
            }
        }
    }

    new ret;
    ExecuteForward(g_Forwards[FWD_REMOVE_ITEM], ret, id, item);
    return amount - remains;
}

stock RemoveNamedItem(id, const class[], amount)
{
	new item = FindItemByClass(class);
	if (item != NULL)
	{
        return RemoveItem(id, item, amount);
	}

    return NULL;
}

stock CountItems(id, item)
{
	new count = 0;
	for (new i = 0; i < g_MaxSlots[id]; i++)
	{
		if (g_Inventory[id][i] == item)
		{
			count += g_Inventory2[id][i];
		}
	}

	return count;
}

stock FindItemByClass(const class[])
{
    new class2[32];

    for (new i = 0; i < g_Items[ITEM_COUNT]; i++)
    {
        ArrayGetString(g_Items[ITEM_CLASS], i, class2, charsmax(class2));
        
        if (equal(class, class2))
            return i;
    }

    return NULL;
}

stock RemoveSlotItem(id, slot, amount=1)
{
	new item = g_Inventory[id][slot];
	g_Inventory2[id][slot] -= amount;

	if (g_Inventory2[id][slot] <= 0)
	{
		g_Inventory[id][slot] = NULL;
		g_Inventory2[id][slot] = 0;
	}

    new ret;
    ExecuteForward(g_Forwards[FWD_REMOVE_ITEM], ret, id, item);
}

stock CreateItem(const name[], const class[], const desc[], amount)
{
	ArrayPushString(g_Items[ITEM_NAME], name);
	ArrayPushString(g_Items[ITEM_CLASS], class);
	ArrayPushString(g_Items[ITEM_DESC], desc);
	ArrayPushCell(g_Items[ITEM_AMT], amount);

    g_Items[ITEM_COUNT]++;
	return g_Items[ITEM_COUNT] - 1;
}

stock GetItemName(item, name[], len)
{
    ArrayGetString(g_Items[ITEM_NAME], item, name, len);
}

stock GetItemDesc(item, name[], len)
{
    ArrayGetString(g_Items[ITEM_DESC], item, name, len);
}

stock GetItemClass(item, name[], len)
{
    ArrayGetString(g_Items[ITEM_CLASS], item, name, len);
}

stock GetItemAmount(item)
{
    return ArrayGetCell(g_Items[ITEM_AMT], item);
}