#include <amxmodx>
#include <sypb>
#include <resident_evil>

public plugin_init()
{
    register_plugin("RE: SyPB", "0.1", "Holla");
}

public re_on_make_zombie(id, attacker)
{
    if (is_user_sypb(id))
        sypb_set_zombie_player(id, 1);
}

public re_on_make_human(id)
{
    if (is_user_sypb(id))
        sypb_set_zombie_player(id, 0);
}