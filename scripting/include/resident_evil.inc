#if defined _resident_evil_included
	#endinput
#endif
#define _resident_evil_included

native re_is_user_zombie(id);

forward re_on_make_zombie(id, attacker);
forward re_on_make_human(id);