#if defined _re_inventory_included
	#endinput
#endif
#define _re_inventory_included

native re_give_user_item(id, item, amount=1, bool:checkSpace=true);
native re_give_named_item(id, const name[], amount=1, bool:checkSpace=true);
native re_remove_user_item(id, item, amount=1);
native re_count_user_items(id, itemid);
native re_remove_slot_item(id, slot, amount=1);
native re_get_slot_item(id, slot);

native re_create_item(const name[], const class[], const desc[], amount);
native re_find_item_by_class(const class[]);
native re_get_item_name(itemid, string[], len);
native re_get_item_class(itemid, string[], len);
native re_get_item_amt(itemid);

forward re_on_give_item(id, item);
forward re_on_remove_item(id, item);
forward re_on_use_item(id, slot);