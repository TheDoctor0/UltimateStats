#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <unixtime>
#include <cstrike>
#include <nvault>
#include <sqlx>
#include <fun>

#define PLUGIN  "Ultimate Stats"
#define VERSION "1.0"
#define AUTHOR  "O'Zone"

#pragma dynamic 	32768

#define CSW_SHIELD  2
#define MAX_WEAPONS CSW_P90 + 1
#define HIT_END     HIT_RIGHTLEG + 1
#define STATS_END   STATS_RANK + 1
#define MAX_MONEY   16000

#define TASK_TIME   6701

#define get_bit(%2,%1) (%1 & (1<<(%2&31)))
#define set_bit(%2,%1) (%1 |= (1<<(%2&31)))
#define rem_bit(%2,%1) (%1 &= ~(1 <<(%2&31)))

#define get_elo(%1,%2) (1.0 / (1.0 + floatpower(10.0, ((%1 - %2) / 400.0))))
#define set_elo(%1,%2,%3) (%1 + 20.0 * (%2 - %3))

//FEATURES:
//All from StatsX
//All from CsStats
//All from StatsSystem
//Rankings and top15 for all features + weapons
//Skill - elo rank
//#define get_elo(%1,%2) (1.0 / (1.0 + floatpower(10.0, ((%1 - %2) / 400.0))))
//#define set_elo(%1,%2,%3) (%1 + 20.0 * (%2 - %3))
//
//NATIVES:
//get_stats(index,stats[8],bodyhits[8],name[],len); - overall stats for index from ranking  (https://www.amxmodx.org/api/tsstats/get_stats)
//get_stats2(index, stats[4], authid[] = "", authidlen = 0); - overall stats for objectives for index from ranking (https://www.amxmodx.org/api/csstats/get_stats2)
//get_user_stats(index,stats[8],bodyhits[8]); - overall player stats (https://www.amxmodx.org/api/tsstats/get_user_stats)
//get_user_rstats(index,stats[8],bodyhits[8]); - round player stats (https://www.amxmodx.org/api/tsstats/get_user_rstats)
//get_user_stats2(index, stats[4]); - overall player stats for objectives (https://www.amxmodx.org/api/csstats/get_user_stats2)
//get_statsnum(); - numbers of players in ranking (https://www.amxmodx.org/api/tsstats/get_statsnum)
//get_user_wstats(index,wpnindex,stats[8],bodyhits[8]); - overall player stats for given weapon (https://www.amxmodx.org/api/tsstats/get_user_wstats)
//get_user_wrstats(index,wpnindex,stats[8],bodyhits[8]); - round player stats for given weapon (https://www.amxmodx.org/api/tsstats/get_user_wrstats)
//get_user_vstats(index,victim,stats[8],bodyhits[8],wpnname[]="",len=0); - round victim stats (https://www.amxmodx.org/api/tsstats/get_user_vstats)
//get_user_astats(index,wpnindex,stats[8],bodyhits[8],wpnname[]="",len=0); - round attacker stats (https://www.amxmodx.org/api/tsstats/get_user_astats)
//reset_user_wstats(index); (https://www.amxmodx.org/api/tsstats/reset_user_wstats) - reset wrstats, vstats, astats

new const cmdMenu[][] = { "menustaty", "say /statsmenu", "say_team /statsmenu", "say /statymenu", "say_team /statymenu", "say /menustaty", "say_team /menustaty" };
new const cmdTime[][] = { "czas", "say /time", "say_team /time", "say /czas", "say_team /czas" };
new const cmdTimeAdmin[][] = { "czasadmin", "say /timeadmin", "say_team /timeadmin", "say /tadmin", "say_team /tadmin", "say /czasadmin", "say_team /czasadmin", "say /cadmin", "say_team /cadmin", "say /adminczas", "say_team /adminczas" };
new const cmdTimeTop[][] = { "topczas", "say /ttop15", "say_team /ttop15", "say /toptime", "say_team /toptime", "say /ctop15", "say_team /ctop15", "say /topczas", "say_team /topczas" };
new const cmdStats[][] = { "say /staty", "say_team /staty", "say /beststats", "say_team /beststats", "say /bstats", "say_team /bstats", "say /najlepszestaty", "say_team /najlepszestaty", "say /nstaty", "say_team /nstaty" };
new const cmdStatsTop[][] = { "najlepszestaty", "say /stop15", "say_team /stop15", "say /topstats", "say_team /topstats", "say /topstaty", "say_team /topstaty", "topstaty" };
new const cmdMedals[][] = { "medale", "say /medal", "say_team /medal", "say /medale", "say_team /medale", "say /medals", "say_team /medals" };
new const cmdMedalsTop[][] = { "topmedale", "say /mtop15", "say_team /mtop15", "say /topmedals", "say_team /topmedals", "say /topmedale", "say_team /topmedale" };
new const cmdSounds[][] = { "dzwieki", "say /dzwiek", "say_team /dzwiek", "say /dzwieki", "say_team /dzwieki", "say /sound", "say_team /sound" };

enum _:forwards { FORWARD_DAMAGE, FORWARD_DEATH, FORWARD_ASSIST, FORWARD_PLANTING, FORWARD_PLANTED, FORWARD_EXPLODE, FORWARD_DEFUSING, FORWARD_DEFUSED, FORWARD_THROW };
enum _:statsData { STATS_KILLS = HIT_END, STATS_DEATHS, STATS_HS, STATS_TK, STATS_SHOTS, STATS_HITS, STATS_DAMAGE, STATS_RANK };
enum _:winers { THIRD, SECOND, FIRST };
enum _:save { NORMAL = -1, ROUND, FINAL, MAP_END };
enum _:playerData{ BOMB_DEFUSIONS = STATS_END, BOMB_DEFUSED, BOMB_PLANTED, BOMB_EXPLODED, RANK, ADMIN, PLAYER_ID, FIRST_VISIT, LAST_VISIT, TIME, CONNECTS, ASSISTS, ROUNDS, ROUNDS_CT, ROUNDS_T, WIN_CT, WIN_T, BRONZE, SILVER, 
	GOLD, MEDALS, BEST_STATS, BEST_KILLS, BEST_DEATHS, BEST_HS, CURRENT_STATS, CURRENT_KILLS, CURRENT_DEATHS, CURRENT_HS, Float:ELO_RANK, NAME[32], SAFE_NAME[64], STEAMID[32], IP[16] };

new playerStats[MAX_PLAYERS + 1][playerData], playerRStats[MAX_PLAYERS + 1][playerData], playerWStats[MAX_PLAYERS + 1][MAX_WEAPONS][STATS_END], playerWRStats[MAX_PLAYERS + 1][MAX_WEAPONS][STATS_END], 
	playerAStats[MAX_PLAYERS + 1][MAX_PLAYERS + 1][STATS_END], playerVStats[MAX_PLAYERS + 1][MAX_PLAYERS + 1][STATS_END], weaponsAmmo[MAX_PLAYERS + 1][MAX_WEAPONS], statsForwards[forwards], statsNum,
	Handle:sql, Handle:connection, bool:sqlConnection, bool:oneAndOnly, bool:block, bool:mapChange, round, sounds, statsLoaded, weaponStatsLoaded, visit, soundMayTheForce, soundOneAndOnly, soundPrepare, 
	soundHumiliation, soundLastLeft, ret, cvarSaveType, rankSaveType, assistEnabled, assistMinDamage, assistMoney, medalsEnabled, prefixEnabled, chatInfoEnabled, xvsxEnabled, soundsEnabled, planter, defuser;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	create_cvar("ultimate_stats_host", "localhost", FCVAR_SPONLY | FCVAR_PROTECTED); 
	create_cvar("ultimate_stats_user", "user", FCVAR_SPONLY | FCVAR_PROTECTED); 
	create_cvar("ultimate_stats_pass", "password", FCVAR_SPONLY | FCVAR_PROTECTED); 
	create_cvar("ultimate_stats_db", "database", FCVAR_SPONLY | FCVAR_PROTECTED);

	cvarSaveType = get_cvar_pointer("csstats_rank");

	bind_pcvar_num(create_cvar("ultimate_stats_assist_enabled", "0"), assistEnabled);
	bind_pcvar_num(create_cvar("ultimate_stats_assist_min_damage", "65"), assistMinDamage);
	bind_pcvar_num(create_cvar("ultimate_stats_assist_money", "300"), assistMoney);
	bind_pcvar_num(create_cvar("ultimate_stats_medals_enabled", "0"), medalsEnabled);
	bind_pcvar_num(create_cvar("ultimate_stats_prefix_enabled", "0"), soundsEnabled);
	bind_pcvar_num(create_cvar("ultimate_stats_chat_info_enabled", "0"), chatInfoEnabled);
	bind_pcvar_num(create_cvar("ultimate_stats_xvsx_enabled", "0"), xvsxEnabled);
	bind_pcvar_num(create_cvar("ultimate_stats_sounds_enabled", "0"), soundsEnabled);

	// for(new i; i < sizeof(cmdMenu); i++) register_clcmd(cmdMenu[i], "cmd_menu");
	// for(new i; i < sizeof(cmdTime); i++) register_clcmd(cmdTime[i], "cmd_time");
	// for(new i; i < sizeof(cmdTimeAdmin); i++) register_clcmd(cmdTimeAdmin[i], "cmd_time_admin");
	// for(new i; i < sizeof(cmdTimeTop); i++) register_clcmd(cmdTimeTop[i], "cmd_time_top");
	// for(new i; i < sizeof(cmdStats); i++) register_clcmd(cmdStats[i], "cmd_stats");
	// for(new i; i < sizeof(cmdStatsTop); i++) register_clcmd(cmdStatsTop[i], "cmd_stats_top");
	// for(new i; i < sizeof(cmdMedals); i++) register_clcmd(cmdMedals[i], "cmd_medals");
	// for(new i; i < sizeof(cmdMedalsTop); i++) register_clcmd(cmdMedalsTop[i], "cmd_medals_top");
	// for(new i; i < sizeof(cmdSounds); i++) register_clcmd(cmdSounds[i], "cmd_sounds");
	
	statsForwards[FORWARD_DAMAGE] = CreateMultiForward("client_damage", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	statsForwards[FORWARD_DEATH] =  CreateMultiForward("client_death", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	statsForwards[FORWARD_ASSIST] = CreateMultiForward("client_assist", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	statsForwards[FORWARD_PLANTING] = CreateMultiForward("bomb_planting", ET_IGNORE, FP_CELL);
	statsForwards[FORWARD_PLANTED] = CreateMultiForward("bomb_planted", ET_IGNORE, FP_CELL);
	statsForwards[FORWARD_EXPLODE] = CreateMultiForward("bomb_explode", ET_IGNORE, FP_CELL, FP_CELL);
	statsForwards[FORWARD_DEFUSING] = CreateMultiForward("bomb_defusing", ET_IGNORE, FP_CELL);
	statsForwards[FORWARD_DEFUSED] = CreateMultiForward("bomb_defused", ET_IGNORE, FP_CELL);
	statsForwards[FORWARD_THROW] = CreateMultiForward("grenade_throw", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

	RegisterHam(Ham_Spawn , "player", "player_spawned", 1);

	register_logevent("round_end", 2, "1=Round_End");
	register_logevent("planted_bomb", 3, "2=Planted_The_Bomb");
	register_logevent("defused_bomb", 3, "2=Defused_The_Bomb");
	register_logevent("defusing_bomb", 3, "2=Begin_Bomb_Defuse_Without_Kit");
	register_logevent("defusing_bomb", 3, "2=Begin_Bomb_Defuse_With_Kit");
	register_logevent("explode_bomb", 6, "3=Target_Bombed");

	register_event("HLTV", "new_round", "a", "1=0", "2=0");
	register_event("TextMsg", "round_restart", "a", "2&#Game_C", "2&#Game_w");
	register_event("SendAudio", "win_t" , "a", "2&%!MRAD_terwin");
	register_event("SendAudio", "win_ct", "a", "2&%!MRAD_ct_win_round");
	register_event("23", "planted_bomb_no_round", "a", "1=17", "6=-105", "7=17");
	register_event("BarTime", "planting_bomb", "be", "1=3");
	register_event("CurWeapon", "cur_weapon", "b" ,"1=1");
	register_event("Damage", "damage","b", "2!0");

	register_message(SVC_INTERMISSION, "message_intermission");
	register_message(get_user_msgid("SayText"), "say_text");

	sounds = nvault_open("stats_sound");
}

public plugin_natives()
{
	// register_library("csstats");

	// register_native("get_statsnum", "native_get_statsnum", 1);

	// register_native("reset_user_wstats", "native_reset_user_wstats", 1);
}

public plugin_cfg()
{
	new configPath[64];

	get_localinfo("amxx_configsdir", configPath, charsmax(configPath));

	server_cmd("exec %s/ultimate_stats.cfg", configPath);
	server_exec();

	rankSaveType = get_pcvar_num(cvarSaveType);

	sql_init();
}

public plugin_precache()
{
	precache_sound("misc/maytheforce.wav");
	precache_sound("misc/oneandonly.wav");
	precache_sound("misc/prepare.wav");
	precache_sound("misc/humiliation.wav");
	precache_sound("misc/lastleft.wav");
}

public plugin_end()
{
	SQL_FreeHandle(sql);
	SQL_FreeHandle(connection);
}

public client_connect(id)
{
	clear_stats(id);

	rem_bit(id, soundMayTheForce);
	rem_bit(id, soundOneAndOnly);
	rem_bit(id, soundHumiliation);
	rem_bit(id, soundLastLeft);
	rem_bit(id, soundPrepare);

	rem_bit(id, statsLoaded);
	rem_bit(id, weaponStatsLoaded);
	rem_bit(id, visit);

	if (is_user_bot(id) || is_user_hltv(id)) return;

	get_user_name(id, playerStats[id][NAME], charsmax(playerStats[][NAME]));
	get_user_authid(id, playerStats[id][STEAMID], charsmax(playerStats[][STEAMID]));
	get_user_ip(id, playerStats[id][IP], charsmax(playerStats[][IP]), 1);

	sql_safe_string(playerStats[id][NAME], playerStats[id][SAFE_NAME], charsmax(playerStats[][SAFE_NAME]));

	set_task(random_float(0.1, 1.0), "load_stats", id);
}

public client_authorized(id)
	playerStats[id][ADMIN] = get_user_flags(id) & ADMIN_BAN ? 1 : 0;

public client_putinserver(id)
	playerStats[id][CONNECTS]++;

public client_disconnected(id)
{
	remove_task(id);
	remove_task(id + TASK_TIME);

	save_stats(id, mapChange ? MAP_END : FINAL);
}

public amxbans_admin_connect(id)
	client_authorized(id, "");

public player_spawned(id)
	if (!get_bit(id, visit)) set_task(3.0, "check_time", id + TASK_TIME);

public check_time(id)
{
	id -= TASK_TIME;

	if (!get_bit(id, visit)) return;
	
	if (!get_bit(id, statsLoaded)) { 
		set_task(3.0, "check_time", id + TASK_TIME);

		return;
	}

	set_bit(id, visit);
	
	new time = get_systime(), visitYear, Year, visitMonth, Month, visitDay, Day, visitHour, visitMinutes, visitSeconds;
	
	UnixToTime(time, visitYear, visitMonth, visitDay, visitHour, visitMinutes, visitSeconds, UT_TIMEZONE_SERVER);
	
	client_print_color(id, id, "^x04[STATS]^x01 Aktualnie jest godzina^x03 %02d:%02d:%02d (Data: %02d.%02d.%02d)^x01.", visitHour, visitMinutes, visitSeconds, visitDay, visitMonth, visitYear);
	
	if (playerStats[id][FIRST_VISIT] == playerStats[id][LAST_VISIT]) client_print_color(id, id, "^x04[STATS]^x01 To twoja^x04 pierwsza wizyta^x01 na serwerze. Zyczymy milej gry!" );
	else {
		UnixToTime(playerStats[id][LAST_VISIT], Year, Month, Day, visitHour, visitMinutes, visitSeconds, UT_TIMEZONE_SERVER);
		
		if (visitYear == Year && visitMonth == Month && visitDay == Day) client_print_color(id, id, "^x04[STATS]^x01 Twoja ostatnia wizyta miala miejsce^x03 dzisiaj^x01 o^x03 %02d:%02d:%02d^x01. Zyczymy milej gry!", visitHour, visitMinutes, visitSeconds);
		else if (visitYear == Year && visitMonth == Month && (visitDay - 1) == Day) client_print_color(id, id, "^x04[STATS]^x01 Twoja ostatnia wizyta miala miejsce^x03 wczoraj^x01 o^x03 %02d:%02d:%02d^x01. Zyczymy milej gry!", visitHour, visitMinutes, visitSeconds);
		else client_print_color(id, id, "^x04[STATS]^x01 Twoja ostatnia wizyta:^x03 %02d:%02d:%02d (Data: %02d.%02d.%02d)^x01. Zyczymy milej gry!", visitHour, visitMinutes, visitSeconds, Day, Month, Year);
	}
}

public round_end()
{
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id)) continue;

		if (get_user_team(id) == 1 || get_user_team(id) == 2) {
			playerStats[id][ROUNDS]++;
			playerStats[id][get_user_team(id) == 1 ? ROUNDS_T : ROUNDS_CT]++;
		}

		save_stats(id, ROUND);
	}
}

public first_round()
	block = false;

public round_restart()
	round = 0;

public new_round()
{
	clear_stats();

	planter = 0;
	defuser = 0;

	oneAndOnly = false;

	if (!round) {
		set_task(30.0, "first_round");

		block = true;
	}

	round++;

	if (!chatInfoEnabled) return;

	new bestId, bestFrags, tempFrags, bestDeaths, tempDeaths;

	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) continue;

		tempFrags = get_user_frags(id);
		tempDeaths = get_user_deaths(id);

		if (tempFrags > 0 && (tempFrags > bestFrags || (tempFrags == bestFrags && tempDeaths < bestDeaths))) {
			bestFrags = tempFrags;
			bestDeaths = tempDeaths;
			bestId = id;
		}
	}

	if (is_user_connected(bestId)) client_print_color(0, bestId, "* ^x03 %s^x01 prowadzi w grze z^x04 %i^x01 fragami i^x04 %i^x01 zgonami. *", playerStats[bestId][NAME], bestFrags, bestDeaths);
}

public planting_bomb(planter)
	ExecuteForward(statsForwards[FORWARD_PLANTING], ret, planter);

public planted_bomb()
{
	planter = get_loguser_index();

	playerStats[planter][BOMB_PLANTED]++;
	
	ExecuteForward(statsForwards[FORWARD_PLANTED], ret, planter);

	if (!soundsEnabled) return;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if(!is_user_connected(i)) continue;

		if(((is_user_alive(i) && get_user_team(i) == 2) || (!is_user_alive(i) && get_user_team(pev(i, pev_iuser2)) == 2)) && get_bit(i, soundPrepare)) client_cmd(i, "spk misc/prepare");
	}
}

public planted_bomb_no_round(planter)
{
	playerStats[planter][BOMB_PLANTED]++;

	ExecuteForward(statsForwards[FORWARD_PLANTED], ret, planter);
}

public defused_bomb()
{
	defuser = get_loguser_index();

	playerStats[defuser][BOMB_DEFUSED]++;

	ExecuteForward(statsForwards[FORWARD_DEFUSED], ret, defuser);
}

public defusing_bomb()
{
	defuser = get_loguser_index();

	playerStats[defuser][BOMB_DEFUSIONS]++;
}

public explode_bomb()
{
	if (is_user_connected(planter)) playerStats[planter][BOMB_EXPLODED]++;
	
	ExecuteForward(statsForwards[FORWARD_EXPLODE], ret, planter, defuser);
}

public cur_weapon(id)
{
	static weapon, ammo;
	
	weapon = read_data(2);
	ammo = read_data(3);
	
	if (weaponsAmmo[id][weapon] != ammo) {
		if (weaponsAmmo[id][weapon] > ammo) {
			playerStats[id][STATS_SHOTS]++;
			playerRStats[id][STATS_SHOTS]++;
			playerWStats[id][weapon][STATS_SHOTS]++;
			playerWRStats[id][weapon][STATS_SHOTS]++;
		}

		weaponsAmmo[id][weapon] = ammo;
	}
}

public damage(victim)
{
	static damage, inflictor;

	damage = read_data(2);

	inflictor = pev(victim, pev_dmg_inflictor);

	if (!pev_valid(inflictor)) return;

	new attacker, weapon, hitPlace, sameTeam;

	attacker = get_user_attacker(victim, weapon, hitPlace);

	if (!(0 <= attacker <= MAX_PLAYERS)) return;

	sameTeam = get_user_team(victim) == get_user_team(attacker) ? true : false;

	if (!(0 < inflictor <= MAX_PLAYERS)) weapon = CSW_HEGRENADE;

	if (0 <= hitPlace < HIT_END) {
		ExecuteForward(statsForwards[FORWARD_DAMAGE], ret, attacker, victim, damage, weapon, hitPlace, sameTeam);

		playerStats[attacker][STATS_DAMAGE] += damage;
		playerRStats[attacker][STATS_DAMAGE] += damage;
		playerWStats[attacker][weapon][STATS_DAMAGE] += damage;
		playerWRStats[attacker][weapon][STATS_DAMAGE] += damage;
		playerVStats[attacker][victim][STATS_DAMAGE] += damage;
		playerAStats[victim][attacker][STATS_DAMAGE] += damage;
		playerVStats[attacker][0][STATS_DAMAGE] += damage;
		playerAStats[victim][0][STATS_DAMAGE] += damage;

		playerStats[attacker][STATS_HITS]++;
		playerRStats[attacker][STATS_HITS]++;
		playerWStats[attacker][weapon][STATS_HITS]++;
		playerWRStats[attacker][weapon][STATS_HITS]++;
		playerVStats[attacker][victim][STATS_HITS]++;
		playerAStats[victim][attacker][STATS_HITS]++;
		playerVStats[attacker][0][STATS_HITS]++;
		playerAStats[victim][0][STATS_HITS]++;

		if (hitPlace) {
			playerStats[attacker][hitPlace]++;
			playerRStats[attacker][hitPlace]++;
			playerWStats[attacker][weapon][hitPlace]++;
			playerWRStats[attacker][weapon][hitPlace]++;
			playerVStats[attacker][victim][hitPlace]++;
			playerAStats[victim][attacker][hitPlace]++;
			playerVStats[attacker][0][hitPlace]++;
			playerAStats[victim][0][hitPlace]++;
		}

		if (!is_user_alive(victim)) death(attacker, victim, weapon, hitPlace, sameTeam);
	}
}

public death(killer, victim, weapon, hitPlace, teamKill)
{
	ExecuteForward(statsForwards[FORWARD_DEATH], ret, killer, victim, weapon, hitPlace, teamKill);

	playerStats[victim][CURRENT_DEATHS]++;
	playerStats[victim][STATS_DEATHS]++;
	playerRStats[victim][STATS_DEATHS]++;
	playerWStats[victim][weapon][STATS_DEATHS]++;
	playerWRStats[victim][weapon][STATS_DEATHS]++;

	save_stats(victim, NORMAL);

	if (is_user_connected(killer) && killer != victim) {
		playerStats[killer][ELO_RANK] = _:set_elo(playerStats[killer][ELO_RANK], 1.0, get_elo(playerStats[victim][ELO_RANK], playerStats[killer][ELO_RANK]));
		playerStats[victim][ELO_RANK] = floatmax(1.0, set_elo(playerStats[victim][ELO_RANK], 0.0, get_elo(playerStats[killer][ELO_RANK], playerStats[victim][ELO_RANK])));

		playerStats[killer][CURRENT_KILLS]++;
		playerStats[killer][STATS_KILLS]++;
		playerRStats[killer][STATS_KILLS]++;
		playerWStats[killer][weapon][STATS_KILLS]++;
		playerWRStats[killer][weapon][STATS_KILLS]++;
		playerVStats[killer][victim][STATS_KILLS]++;
		playerAStats[victim][killer][STATS_KILLS]++;
		playerVStats[killer][0][STATS_KILLS]++;
		playerAStats[victim][0][STATS_KILLS]++;

		if (hitPlace == HIT_HEAD) {
			playerStats[killer][CURRENT_HS]++;
			playerStats[killer][STATS_HS]++;
			playerRStats[killer][STATS_HS]++;
			playerWStats[killer][weapon][STATS_HS]++;
			playerWRStats[killer][weapon][STATS_HS]++;
			playerVStats[killer][victim][STATS_HS]++;
			playerAStats[victim][killer][STATS_HS]++;
			playerVStats[killer][0][STATS_HS]++;
			playerAStats[victim][0][STATS_HS]++;
		}

		if (teamKill) {
			playerStats[killer][STATS_TK]++;
			playerRStats[killer][STATS_TK]++;
			playerWStats[killer][weapon][STATS_TK]++;
			playerWRStats[killer][weapon][STATS_TK]++;
			playerVStats[killer][victim][STATS_TK]++;
			playerAStats[victim][killer][STATS_TK]++;
			playerVStats[killer][0][STATS_TK]++;
			playerAStats[victim][0][STATS_TK]++;
		}

		save_stats(killer, NORMAL);

		if (chatInfoEnabled) {
			client_print_color(victim, killer, "* Zostales zabity przez^x03 %s^x01, ktoremu zostalo^x04 %i^x01 HP. *", playerStats[killer][NAME], get_user_health(killer));
			client_print_color(killer, victim, "* Zabiles^x03 %s^x01. *", playerStats[victim][NAME]);
		}

		if (assistEnabled) {
			new assistKiller, assistDamage;

			for (new i = 1; i <= MAX_PLAYERS; i++) {
				if(!is_user_connected(i) || i == killer || i == victim) continue;
				
				if(playerAStats[victim][i][STATS_DAMAGE] >= assistMinDamage && playerAStats[victim][i][STATS_DAMAGE] > assistDamage) {
					assistKiller = i;
					assistDamage = playerAStats[victim][i][STATS_DAMAGE];
				}
			}

			if (assistKiller) {
				playerStats[assistKiller][STATS_KILLS]++;
				playerStats[assistKiller][CURRENT_KILLS]++;
				playerStats[assistKiller][ASSISTS]++;

				save_stats(assistKiller, NORMAL);

				set_user_frags(assistKiller, get_user_frags(assistKiller) + 1);
				cs_set_user_deaths(assistKiller, cs_get_user_deaths(assistKiller));

				new money = min(cs_get_user_money(assistKiller) + assistMoney, MAX_MONEY);

				cs_set_user_money(assistKiller, money);

				if (is_user_alive(assistKiller)) {
					static msgMoney;

					if (!msgMoney) msgMoney = get_user_msgid("Money");

					message_begin(MSG_ONE_UNRELIABLE, msgMoney, _, assistKiller);
					write_long(money);
					write_byte(1);
					message_end();
				}
				
				client_print_color(assistKiller, killer, "^x03[ASYSTA]^x01 Pomogles^x04 %s^x01 w zabiciu^x04 %s^x01. Dostajesz fraga!", playerStats[killer][NAME], playerStats[victim][NAME]);
			}
		}
	}

	if (!soundsEnabled && !xvsxEnabled) return;

	if (weapon == CSW_KNIFE && soundsEnabled) {
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_connected(i)) continue;

			if ((pev(i, pev_iuser2) == victim || i == victim) && get_bit(i, soundHumiliation)) client_cmd(i, "spk misc/humiliation");
		}
	}

	if (block) return;

	new tCount, ctCount, lastT, lastCT;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_alive(i)) continue;

		switch(get_user_team(i)) {
			case 1: {
				tCount++;
				lastT = i;
			} case 2: {
				ctCount++;
				lastCT = i;
			}
		}
	}
	
	if (tCount == 1 && ctCount == 1) {
		if (soundsEnabled) {
			for (new i = 1; i <= MAX_PLAYERS; i++) {
				if (!is_user_connected(i)) continue;

				if ((pev(i, pev_iuser2) == lastT || pev(i, pev_iuser2) == lastCT || i == lastT || i == lastCT) && get_bit(i, soundMayTheForce)) client_cmd(i, "spk misc/maytheforce");
			}
		}

		if (xvsxEnabled) {
			new nameT[32], nameCT[32];

			get_user_name(lastT, nameT, charsmax(nameT));
			get_user_name(lastCT, nameCT, charsmax(nameCT));

			set_dhudmessage(255, 128, 0, -1.0, 0.30, 0, 3.0, 3.0, 0.5, 0.15);
			show_dhudmessage(0, "%s vs. %s", nameT, nameCT);
		}
	}

	if (tCount == 1 && ctCount > 1) {
		if (!oneAndOnly && soundsEnabled) {
			for (new i = 1; i <= MAX_PLAYERS; i++) {
				if (!is_user_connected(i)) continue;

				if (((is_user_alive(i) && get_user_team(i) == 2) || (!is_user_alive(i) && pev(i, pev_iuser2) != lastT)) && get_bit(i, soundLastLeft)) client_cmd(i, "spk misc/lastleft");

				if ((pev(i, pev_iuser2) == lastT || i == lastT) && get_bit(i, soundOneAndOnly)) client_cmd(i, "spk misc/oneandonly");
			}
		}

		oneAndOnly = true;

		if (xvsxEnabled) {
			set_dhudmessage(255, 128, 0, -1.0, 0.30, 0, 3.0, 3.0, 0.5, 0.15);
			show_dhudmessage(0, "%i vs %i", tCount, ctCount);
		}
	}

	if (tCount > 1 && ctCount == 1) {
		if (!oneAndOnly && soundsEnabled) {
			for (new i = 1; i <= MAX_PLAYERS; i++) {
				if (!is_user_connected(i)) continue;
				
				if (((is_user_alive(i) && get_user_team(i) == 1) || (!is_user_alive(i) && pev(i, pev_iuser2) != lastCT)) && get_bit(i, soundLastLeft)) client_cmd(i, "spk misc/lastleft");

				if ((pev(i, pev_iuser2) == lastCT || i == lastCT) && get_bit(i, soundOneAndOnly)) client_cmd(i, "spk misc/oneandonly");
			}
		}

		oneAndOnly = true;

		if (xvsxEnabled) {
			set_dhudmessage(255, 128, 0, -1.0, 0.30, 0, 3.0, 3.0, 0.5, 0.15);
			show_dhudmessage(0, "%i vs %i", ctCount, tCount);
		}
	}
}

public win_t()
	round_winner(1);
	
public win_ct()
	round_winner(2);

public round_winner(team)
{
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || get_user_team(id) != team) continue;

		playerStats[id][team == 1 ? WIN_T : WIN_CT]++;
	}
}

public message_intermission() 
{
	mapChange = true;

	if (medalsEnabled) {
		new playerName[32], winnersId[3], winnersFrags[3], tempFrags, swapFrags, swapId;

		for (new id = 1; id <= MAX_PLAYERS; id++) {
			if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) continue;
			
			tempFrags = get_user_frags(id);
			
			if (tempFrags > winnersFrags[THIRD]) {
				winnersFrags[THIRD] = tempFrags;
				winnersId[THIRD] = id;
				
				if (tempFrags > winnersFrags[SECOND]) {
					swapFrags = winnersFrags[SECOND];
					swapId = winnersId[SECOND];
					winnersFrags[SECOND] = tempFrags;
					winnersId[SECOND] = id;
					winnersFrags[THIRD] = swapFrags;
					winnersId[THIRD] = swapId;
					
					if (tempFrags > winnersFrags[FIRST]) {
						swapFrags = winnersFrags[FIRST];
						swapId = winnersId[FIRST];
						winnersFrags[FIRST] = tempFrags;
						winnersId[FIRST] = id;
						winnersFrags[SECOND] = swapFrags;
						winnersId[SECOND] = swapId;
					}
				}
			}
		}
		
		if (!winnersId[FIRST]) return PLUGIN_CONTINUE;

		new const medals[][] = { "Brazowy", "Srebrny", "Zloty" };

		client_print_color(0, 0, "^x04[STATS]^x01 Gratulacje dla^x03 Najlepszych Graczy^x01!");
		
		for (new i = 2; i >= 0; i--) {
			switch(i) {
				case THIRD: playerStats[winnersId[i]][BRONZE]++;
				case SECOND: playerStats[winnersId[i]][SILVER]++;
				case FIRST: playerStats[winnersId[i]][GOLD]++;
			}

			save_stats(winnersId[i], FINAL);
			
			get_user_name(winnersId[i], playerName, charsmax(playerName));

			client_print_color(0, 0, "^x04[STATS]^x03 %s^x01 -^x03 %i^x01 Zabojstw - %s Medal.", playerName, winnersFrags[i], medals[i]);
		}
	}
	
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) continue;
		
		save_stats(id, FINAL);
	}

	return PLUGIN_CONTINUE;
}

public say_text(msgId, msgDest, msgEnt)
{
	if (!prefixEnabled) return PLUGIN_CONTINUE;

	new id = get_msg_arg_int(1);
	
	if (is_user_connected(id)) {
		new tempMessage[192], message[192], playerName[32], chatPrefix[16];
		
		get_msg_arg_string(2, tempMessage, charsmax(tempMessage));

		if (playerStats[id][RANK] > 3) return PLUGIN_CONTINUE;
			
		switch (playerStats[id][RANK]) {
			case 1: formatex(chatPrefix, charsmax(chatPrefix), "^x04[TOP1]");
			case 2: formatex(chatPrefix, charsmax(chatPrefix), "^x04[TOP2]");
			case 3: formatex(chatPrefix, charsmax(chatPrefix), "^x04[TOP3]");
		}

		if (!equal(tempMessage, "#Cstrike_Chat_All")) {
			add(message, charsmax(message), chatPrefix);
			add(message, charsmax(message), " ");
			add(message, charsmax(message), tempMessage);
		} else {
	        get_user_name(id, playerName, charsmax(playerName));
	        
	        get_msg_arg_string(4, tempMessage, charsmax(tempMessage)); 
	        set_msg_arg_string(4, "");
	    
	        add(message, charsmax(message), chatPrefix);
	        add(message, charsmax(message), "^x03 ");
	        add(message, charsmax(message), playerName);
	        add(message, charsmax(message), "^x01 :  ");
	        add(message, charsmax(message), tempMessage);
		}
		
		set_msg_arg_string(2, message);
	}

	return PLUGIN_CONTINUE;
}

public cmd_time(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) AS count FROM `ultimate_stats`) a CROSS JOIN (SELECT COUNT(*) AS rank FROM `ultimate_stats` WHERE time > %i ORDER BY time DESC) b", playerStats[id][TIME] + get_user_time(id));

	SQL_ThreadQuery(sql, "show_time", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_time(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}
	
	new id = playerId[0], rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1), seconds = (playerStats[id][TIME] + get_user_time(id)), minutes, hours;
	
	while (seconds >= 60) {
		seconds -= 60;
		minutes++;
	}

	while (minutes >= 60) {
		minutes -= 60;
		hours++;
	}
	
	client_print_color(id, id, "^x04[STATS]^x01 Spedziles na serwerze lacznie^x03 %i h %i min %i s^x01.", hours, minutes, seconds);
	client_print_color(id, id, "^x04[STATS]^x01 Zajmujesz^x03 %i/%i^x01 miejsce w rankingu czasu gry.", rank, players);

	return PLUGIN_HANDLED;
}

public cmd_time_admin(id)
{
	if (!(get_user_flags(id) & ADMIN_BAN)) return;

	new queryData[128], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT name, time FROM `ultimate_stats` WHERE admin = 1 ORDER BY time DESC");

	SQL_ThreadQuery(sql, "show_time_admin_top", queryData, playerId, sizeof(playerId));
}

public show_time_admin_top(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], topLength, place, seconds, minutes, hours;

	topLength = 0, place = 0;
	
	new id = playerId[0];
	
	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %9s^n", "#", "Nick", "Czas Gry");
	
	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		seconds = SQL_ReadResult(query, 1);
		minutes = 0;
		hours = 0;
		
		while (seconds >= 60) {
			seconds -= 60;
			minutes++;
		}

		while (minutes >= 60) {
			minutes -= 60;
			hours++;
		}
		
		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %0ih %1imin %1is^n", place, name, hours, minutes, seconds);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1ih %1imin %1is^n", place, name, hours, minutes, seconds);
		
		SQL_NextRow(query);
	}
	
	show_motd(id, topData, "Czas Gry Adminow");
	
	return PLUGIN_HANDLED;
}

public cmd_time_top(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT name, time FROM `ultimate_stats` ORDER BY time DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_time_top", queryData, playerId, sizeof(playerId));
}

public show_time_top(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], topLength, place, seconds, minutes, hours;

	topLength = 0, place = 0;
	
	new id = playerId[0];
	
	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %9s^n", "#", "Nick", "Czas Gry");
	
	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		seconds = SQL_ReadResult(query, 1);
		minutes = 0;
		hours = 0;
		
		while (seconds >= 60) {
			seconds -= 60;
			minutes++;
		}

		while (minutes >= 60) {
			minutes -= 60;
			hours++;
		}
		
		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %0ih %1imin %1is^n", place, name, hours, minutes, seconds);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1ih %1imin %1is^n", place, name, hours, minutes, seconds);
		
		SQL_NextRow(query);
	}
	
	show_motd(id, topData, "Top15 Czasu Gry");
	
	return PLUGIN_HANDLED;
}

public cmd_stats(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;

	playerStats[id][CURRENT_STATS] = playerStats[id][CURRENT_KILLS] * 2 + playerStats[id][CURRENT_HS] - playerStats[id][CURRENT_DEATHS] * 2;
	
	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) AS count FROM `ultimate_stats`) a CROSS JOIN (SELECT COUNT(*) AS rank FROM `ultimate_stats` WHERE best_stats > %i ORDER BY `best_stats` DESC) b", 
	playerStats[id][CURRENT_STATS] > playerStats[id][BEST_STATS] ? playerStats[id][CURRENT_STATS] : playerStats[id][BEST_STATS]);

	SQL_ThreadQuery(sql, "show_stats", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_stats(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}
	
	new id = playerId[0], rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1);
	
	if (playerStats[id][CURRENT_STATS] > playerStats[id][BEST_STATS]) client_print_color(id, id, "^x04[STATS]^x01 Twoje najlepsze staty to^x03 %i^x01 zabic (w tym^x03 %i^x01 z HS) i^x03 %i^x01 zgonow^x01.", playerStats[id][CURRENT_KILLS], playerStats[id][CURRENT_HS], playerStats[id][CURRENT_DEATHS]);
	else client_print_color(id, id, "^x04[STATS]^x01 Twoje najlepsze staty to^x03 %i^x01 zabic (w tym^x03 %i^x01 z HS) i^x03 %i^x01 zgonow^x01.", playerStats[id][BEST_KILLS], playerStats[id][BEST_HS], playerStats[id][BEST_DEATHS]);

	client_print_color(id, id, "^x04[STATS]^x01 Zajmujesz^x03 %i/%i^x01 miejsce w rankingu najlepszych statystyk.", rank, players);

	return PLUGIN_HANDLED;
}

public cmd_stats_top(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT name, best_kills, best_hs, best_deaths FROM `ultimate_stats` ORDER BY best_stats DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_stats_top", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_stats_top(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], topLength, place, kills, headShots, deaths;

	topLength = 0, place = 0;
	
	new id = playerId[0];
	
	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %19s %4s^n", "#", "Nick", "Zabojstwa", "Zgony");
	
	while (SQL_MoreResults(query))
	{
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		kills = SQL_ReadResult(query, 1);
		headShots = SQL_ReadResult(query, 2);
		deaths = SQL_ReadResult(query, 3);
		
		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1d (%i HS) %12d^n", place, name, kills, headShots, deaths);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %2d (%i HS) %12d^n", place, name, kills, headShots, deaths);
		
		SQL_NextRow(query);
	}
	
	show_motd(id, topData, "Top15 Statystyk");
	
	return PLUGIN_HANDLED;
}

public cmd_medals(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) AS count FROM `ultimate_stats`) a CROSS JOIN (SELECT COUNT(*) AS rank FROM `ultimate_stats` WHERE medals > %i ORDER BY `medals` DESC) b", playerStats[id][MEDALS]);

	SQL_ThreadQuery(sql, "show_medals", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_medals(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("cssstats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}
	
	new id = playerId[0], rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1);
	
	client_print_color(id, id, "^x04[STATS]^x01 Twoje medale:^x03 %i Zlote^x01,^x03 %i Srebre^x01,^x03 %i Brazowe^x01.", playerStats[id][GOLD], playerStats[id][SILVER], playerStats[id][BRONZE]);
	client_print_color(id, id, "^x04[STATS]^x01 Zajmujesz^x03 %i/%i^x01 miejsce w rankingu medalowym.", rank, players);
	
	return PLUGIN_HANDLED;
}

public cmd_medals_top(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;
	
	formatex(queryData, charsmax(queryData), "SELECT name, gold, silver, bronze, medals FROM `ultimate_stats` ORDER BY medals DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_medals_top", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_medals_top(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], topLength, place, gold, silver, bronze, medals;

	topLength = 0, place = 0;
	
	new id = playerId[0];
	
	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %6s %8s %8s %5s^n", "#", "Nick", "Zlote", "Srebrne", "Brazowe", "Suma");
	
	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		gold = SQL_ReadResult(query, 1);
		silver = SQL_ReadResult(query, 2);
		bronze = SQL_ReadResult(query, 3);
		medals = SQL_ReadResult(query, 4);
		
		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %2d %7d %8d %7d^n", place, name, gold, silver, bronze, medals);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %3d %7d %8d %7d^n", place, name, gold, silver, bronze, medals);
		
		SQL_NextRow(query);
	}
	
	show_motd(id, topData, "Top15 Medali");
	
	return PLUGIN_HANDLED;
}

public cmd_sounds(id)
{
	if (!soundsEnabled) return PLUGIN_HANDLED;

	new menuData[64], menu = menu_create("\yUstawienia \rDzwiekow\w:", "cmd_sounds_handle");

	formatex(menuData, charsmax(menuData), "\wThe Force Will Be With You \w[\r%s\w]", get_bit(id, soundMayTheForce) ? "Wlaczony" : "Wylaczony");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wI Am The One And Only \w[\r%s\w]", get_bit(id, soundOneAndOnly) ? "Wlaczony" : "Wylaczony");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wDziabnal Mnie \w[\r%s\w]", get_bit(id, soundHumiliation) ? "Wlaczony" : "Wylaczony");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wKici Kici Tas Tas \w[\r%s\w]", get_bit(id, soundLastLeft) ? "Wlaczony" : "Wylaczony");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wNie Obijac Sie \w[\r%s\w]", get_bit(id, soundPrepare) ? "Wlaczony" : "Wylaczony");
	menu_additem(menu, menuData);
	
	menu_setprop(menu, MPROP_EXITNAME, "Wyjscie");
	
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}

public cmd_sounds_handle(id, menu, item)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	
	if (item == MENU_EXIT) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}
	
	switch(item) {
		case 0: get_bit(id, soundMayTheForce) ? rem_bit(id, soundMayTheForce) : set_bit(id, soundMayTheForce);
		case 1: get_bit(id, soundOneAndOnly) ? rem_bit(id, soundOneAndOnly) : set_bit(id, soundOneAndOnly);
		case 2: get_bit(id, soundHumiliation) ? rem_bit(id, soundHumiliation) : set_bit(id, soundHumiliation);
		case 3: get_bit(id, soundLastLeft) ? rem_bit(id, soundLastLeft) : set_bit(id, soundLastLeft);
		case 4: get_bit(id, soundPrepare) ? rem_bit(id, soundPrepare) : set_bit(id, soundPrepare);
	}
	
	save_sounds(id);

	cmd_sounds(id);

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public sql_init()
{
	new host[32], user[32], pass[32], db[32], error[128], errorNum;
	
	get_cvar_string("ultimate_stats_host", host, charsmax(host));
	get_cvar_string("ultimate_stats_user", user, charsmax(user));
	get_cvar_string("ultimate_stats_pass", pass, charsmax(pass));
	get_cvar_string("ultimate_stats_db", db, charsmax(db));
	
	sql = SQL_MakeDbTuple(host, user, pass, db);

	connection = SQL_Connect(sql, errorNum, error, charsmax(error));
	
	if (errorNum) {
		log_to_file("ultimate_stats.log", "SQL Query Error: %s", error);
		
		return;
	}

	new queryData[2048];
	
	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `ultimate_stats` (`id` INT(11) AUTO_INCREMENT, `name` VARCHAR(64) NOT NULL, `steamid` VARCHAR(32) NOT NULL, `ip` VARCHAR(16) NOT NULL, `admin` INT NOT NULL DEFAULT 0, `kills` INT NOT NULL DEFAULT 0, ");
	add(queryData,  charsmax(queryData), "`deaths` INT NOT NULL DEFAULT 0, `hs_kills` INT NOT NULL DEFAULT 0, `assists` INT NOT NULL DEFAULT 0, `team_kills` INT NOT NULL DEFAULT 0, `shots` INT NOT NULL DEFAULT 0, `hits` INT NOT NULL DEFAULT 0, ");   
	add(queryData,  charsmax(queryData), "`damage` INT NOT NULL DEFAULT 0, `rounds` INT NOT NULL DEFAULT 0, `rounds_ct` INT NOT NULL DEFAULT 0, `rounds_t` INT NOT NULL DEFAULT 0, `wins_ct` INT NOT NULL DEFAULT 0, `wins_t` INT NOT NULL DEFAULT 0, "); 
	add(queryData,  charsmax(queryData), "`connects` INT NOT NULL DEFAULT 0, `time` INT NOT NULL DEFAULT 0, `gold` INT NOT NULL DEFAULT 0, `silver` INT NOT NULL DEFAULT 0, `bronze` INT NOT NULL DEFAULT 0, `medals` INT NOT NULL DEFAULT 0, "); 
	add(queryData,  charsmax(queryData), "`best_kills` INT NOT NULL DEFAULT 0, `best_deaths` INT NOT NULL DEFAULT 0, `best_hs` INT NOT NULL DEFAULT 0, `best_stats` INT NOT NULL DEFAULT 0, `defusions` INT NOT NULL DEFAULT 0, `defused` INT NOT NULL DEFAULT 0, ");
	add(queryData,  charsmax(queryData), "`planted` INT NOT NULL DEFAULT 0, `exploded` INT NOT NULL DEFAULT 0, `elo_rank` DOUBLE NOT NULL DEFAULT 100, `h_1` INT NOT NULL DEFAULT 0, `h_2` INT NOT NULL DEFAULT 0, `h_3` INT NOT NULL DEFAULT 0, `h_4` INT NOT NULL DEFAULT 0, "); 
	add(queryData,  charsmax(queryData), "`h_5` INT NOT NULL DEFAULT 0, `h_6` INT NOT NULL DEFAULT 0, `h_7` INT NOT NULL DEFAULT 0, `first_visit` BIGINT NOT NULL DEFAULT 0, `last_visit` BIGINT NOT NULL DEFAULT 0,  PRIMARY KEY(`id`), UNIQUE KEY `name` (`name`));");

	new Handle:query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `ultimate_stats_weapons` (`player_id` INT(11), `weapon` VARCHAR(32) NOT NULL, `kills` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `hs_kills` INT NOT NULL DEFAULT 0, `team_kills` INT NOT NULL DEFAULT 0, ");
	add(queryData,  charsmax(queryData), "`shots` INT NOT NULL DEFAULT 0, `hits` INT NOT NULL DEFAULT 0, `damage` INT NOT NULL DEFAULT 0, `h_0` INT NOT NULL DEFAULT 0, `h_1` INT NOT NULL DEFAULT 0, `h_2` INT NOT NULL DEFAULT 0, ");   
	add(queryData,  charsmax(queryData), "`h_3` INT NOT NULL DEFAULT 0, `h_4` INT NOT NULL DEFAULT 0, `h_5` INT NOT NULL DEFAULT 0, `h_6` INT NOT NULL DEFAULT 0, `h_7` INT NOT NULL DEFAULT 0, PRIMARY KEY(`player_id`, `weapon`));");  

	query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	formatex(queryData, charsmax(queryData), "SELECT COUNT(*) FROM `ultimate_stats`");

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_NumResults(query)) statsNum = SQL_ReadResult(query, 0);

	SQL_Execute(query);
	
	SQL_FreeHandle(query);

	sqlConnection = true;
}

public ignore_handle(failState, Handle:query, error[], errorCode, data[], dataSize)
{
	if (failState == TQUERY_CONNECT_FAILED) log_to_file("ultimate_stats.log", "Could not connect to SQL database. [%d] %s", errorCode, error);
	else if (failState == TQUERY_QUERY_FAILED) log_to_file("ultimate_stats.log", "Query failed. [%d] %s", errorCode, error);
}

public load_stats(id)
{
	if (!sqlConnection) {
		set_task(1.0, "load_stats", id);

		return;
	}

	static playerId[1], queryData[256], queryTemp[64];
	
	playerId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.*, (SELECT COUNT(*) FROM `ultimate_stats` WHERE (kills - deaths) >= (a.kills - a.deaths)) AS rank FROM `ultimate_stats` a WHERE ");

	switch (rankSaveType) {
		case 0: formatex(queryTemp, charsmax(queryTemp), "`name` = ^"%s^"", playerStats[id][SAFE_NAME]);
		case 1: formatex(queryTemp, charsmax(queryTemp), "`steamid` = ^"%s^"", playerStats[id][STEAMID]);
		case 2: formatex(queryTemp, charsmax(queryTemp), "`ip` = ^"%s^"", playerStats[id][IP]);
	}

	add(queryData, charsmax(queryData), queryTemp);
	
	SQL_ThreadQuery(sql, "load_stats_handle", queryData, playerId, sizeof(playerId));
}

public load_stats_handle(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return;
	}
	
	new id = playerId[0];
	
	if (SQL_NumResults(query)) {
		playerStats[id][PLAYER_ID] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
		playerStats[id][STATS_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
		playerStats[id][STATS_DEATHS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "deaths"));
		playerStats[id][STATS_HS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hs_kills"));
		playerStats[id][STATS_TK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "team_kills"));
		playerStats[id][STATS_SHOTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "shots"));
		playerStats[id][STATS_HITS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hits"));
		playerStats[id][STATS_DAMAGE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "damage"));
		playerStats[id][STATS_RANK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rank"));
		playerStats[id][HIT_HEAD] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_1"));
		playerStats[id][HIT_CHEST] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_2"));
		playerStats[id][HIT_STOMACH] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_3"));
		playerStats[id][HIT_LEFTARM] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_4"));
		playerStats[id][HIT_RIGHTARM] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_5"));
		playerStats[id][HIT_LEFTLEG] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_6"));
		playerStats[id][HIT_RIGHTLEG] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_7"));
		playerStats[id][BOMB_DEFUSIONS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "defusions"));
		playerStats[id][BOMB_DEFUSED] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "defused"));
		playerStats[id][BOMB_PLANTED] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "planted"));
		playerStats[id][BOMB_EXPLODED] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "exploded"));
		playerStats[id][ROUNDS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rounds"));
		playerStats[id][ROUNDS_CT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rounds_ct"));
		playerStats[id][ROUNDS_T] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rounds_t"));
		playerStats[id][WIN_CT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins_ct"));
		playerStats[id][WIN_T] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins_t"));
		playerStats[id][TIME] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "time"));
		playerStats[id][CONNECTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "connects"));
		playerStats[id][ASSISTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "assists"));
		playerStats[id][BRONZE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "bronze"));
		playerStats[id][SILVER] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "silver"));
		playerStats[id][GOLD] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "gold"));
		playerStats[id][MEDALS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "medals"));
		playerStats[id][BEST_STATS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "best_stats"));
		playerStats[id][BEST_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "best_kills"));
		playerStats[id][BEST_HS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "best_hs"));
		playerStats[id][BEST_DEATHS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "best_deaths"));
		playerStats[id][FIRST_VISIT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "first_visit"));
		playerStats[id][LAST_VISIT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "last_visit"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "elo"), playerStats[id][ELO_RANK]);
	} else {
		static queryData[256], queryTemp[64], playerId[2];

		playerId[1] = playerId[0] = id;

		formatex(queryData, charsmax(queryData), "INSERT IGNORE INTO `ultimate_stats` (`name`, `steamid`, `ip`, `first_visit`) VALUES (^"%s^", '%s', '%s', UNIX_TIMESTAMP())", playerStats[id][SAFE_NAME], playerStats[id][STEAMID], playerStats[id][IP]);

		SQL_ThreadQuery(sql, "ignore_handle", queryData);

		formatex(queryData, charsmax(queryData), "SELECT COUNT(*) AS `all`, (SELECT COUNT(*) FROM `ultimate_stats` WHERE (kills - deaths) >= (a.kills - a.deaths)) AS `rank` FROM `ultimate_stats` a WHERE ");

		switch (rankSaveType) {
			case 0: formatex(queryTemp, charsmax(queryTemp), "name = ^"%s^"", playerStats[id][SAFE_NAME]);
			case 1: formatex(queryTemp, charsmax(queryTemp), "steamid = ^"%s^"", playerStats[id][STEAMID]);
			case 2: formatex(queryTemp, charsmax(queryTemp), "ip = ^"%s^"", playerStats[id][IP]);
		}

		add(queryData, charsmax(queryData), queryTemp);
		
		SQL_ThreadQuery(sql, "get_rank_handle", queryData, playerId, sizeof(playerId));
	}

	set_bit(id, statsLoaded);

	set_task(0.25, "load_weapons_stats", id);
}

public get_rank_handle(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return;
	}
	
	new id = playerId[0];
	
	if (SQL_NumResults(query)) {
		//if (!playerStats[id][PLAYER_ID]) playerStats[id][PLAYER_ID] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
		if (playerId[1]) statsNum = SQL_ReadResult(query, SQL_FieldNameToNum(query, "all"));
		playerStats[id][STATS_RANK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rank"));
	}
}

public load_weapons_stats(id)
{
	static queryData[256], playerId[1];

	playerId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.*, (SELECT COUNT(*) FROM `ultimate_stats_weapons` WHERE (kills - deaths) >= (a.kills - a.deaths) AND weapon = a.weapon) AS rank FROM `ultimate_stats_weapons` a WHERE `player_id` = '%i'", playerStats[id][PLAYER_ID]);
		
	SQL_ThreadQuery(sql, "load_weapons_stats_handle", queryData, playerId, sizeof(playerId));
}

public load_weapons_stats_handle(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("ultimate_stats.log", "SQL Error: %s (%d)", error, errorNum);
		
		return;
	}
	
	new id = playerId[0], weaponName[32], weapon;
	
	while (SQL_MoreResults(query)) {
		if (!playerStats[id][PLAYER_ID]) playerStats[id][PLAYER_ID] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "player_id"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "weapon"), weaponName, charsmax(weaponName));

		weapon = get_weaponid(weaponName);

		playerWStats[id][weapon][STATS_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
		playerWStats[id][weapon][STATS_DEATHS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "deaths"));
		playerWStats[id][weapon][STATS_TK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "team_kills"));
		playerWStats[id][weapon][STATS_HS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hs_kills"));
		playerWStats[id][weapon][STATS_SHOTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "shots"));
		playerWStats[id][weapon][STATS_HITS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hits"));
		playerWStats[id][weapon][STATS_DAMAGE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "damage"));
		playerWStats[id][weapon][STATS_RANK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rank"));
		playerWStats[id][weapon][HIT_HEAD] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_1"));
		playerWStats[id][weapon][HIT_CHEST] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_2"));
		playerWStats[id][weapon][HIT_STOMACH] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_3"));
		playerWStats[id][weapon][HIT_LEFTARM] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_4"));
		playerWStats[id][weapon][HIT_RIGHTARM] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_5"));
		playerWStats[id][weapon][HIT_LEFTLEG] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_6"));
		playerWStats[id][weapon][HIT_RIGHTLEG] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "h_7"));

		SQL_NextRow(query);
	}

	if (!weapon) {
		static queryData[4096], queryTemp[196];
		queryData = "";

		if (!playerStats[id][PLAYER_ID]) playerStats[id][PLAYER_ID] = get_player_id(id);

		for (new i = 1; i < MAX_WEAPONS; i++) {
			if (i == CSW_SHIELD || i == CSW_C4 || i == CSW_FLASHBANG || i == CSW_SMOKEGRENADE) continue;

			get_weaponname(i, weaponName, charsmax(weaponName));

			formatex(queryTemp, charsmax(queryTemp), "INSERT IGNORE INTO `ultimate_stats_weapons` (`player_id`, `weapon`) VALUES ('%i', '%s');", playerStats[id][PLAYER_ID], weaponName);

			add(queryData, charsmax(queryData), queryTemp);
		}

		SQL_ThreadQuery(sql, "ignore_handle", queryData);
	}

	set_bit(id, weaponStatsLoaded);
}

stock save_stats(id, end = 0)
{
	if (!get_bit(id, statsLoaded)) return;

	static queryData[2048], queryTemp[256];

	formatex(queryData, charsmax(queryData), "UPDATE `ultimate_stats` SET name = ^"%s^", steamid = ^"%s^", ip = ^"%s^", admin = %d, kills = %d, deaths = %d, hs_kills = %d, ",
	playerStats[id][SAFE_NAME], playerStats[id][STEAMID], playerStats[id][IP], playerStats[id][ADMIN], playerStats[id][STATS_KILLS], playerStats[id][STATS_DEATHS], playerStats[id][STATS_HS]);

	formatex(queryTemp, charsmax(queryTemp), "assists = %d, team_kills = %d, shots = %d, hits = %d, damage = %d, rounds = %d, rounds_ct = %d, rounds_t = %d, ",
	playerStats[id][ASSISTS], playerStats[id][STATS_TK], playerStats[id][STATS_SHOTS], playerStats[id][STATS_HITS], playerStats[id][STATS_DAMAGE], playerStats[id][ROUNDS], playerStats[id][ROUNDS_CT], playerStats[id][ROUNDS_T]);  
	add(queryData, charsmax(queryData), queryTemp);
	
	formatex(queryTemp, charsmax(queryTemp), "wins_ct = %d, wins_t = %d, connects = %d, time = %d, defusions = %d, defused = %d,  planted = %d, exploded = %d, ",
	playerStats[id][WIN_CT], playerStats[id][WIN_T], playerStats[id][CONNECTS], playerStats[id][TIME] + get_user_time(id), playerStats[id][BOMB_DEFUSIONS], playerStats[id][BOMB_DEFUSED], playerStats[id][BOMB_PLANTED], playerStats[id][BOMB_EXPLODED]); 
	add(queryData, charsmax(queryData), queryTemp);
	
	formatex(queryTemp, charsmax(queryTemp), "elo_rank = %.2f, h_1 = %d, h_2 = %d, h_3 = %d, h_4 = %d, h_5 = %d, h_6 = %d, h_7 = %d, last_visit = UNIX_TIMESTAMP()",
	playerStats[id][ELO_RANK], playerStats[id][HIT_HEAD], playerStats[id][HIT_CHEST], playerStats[id][HIT_STOMACH], playerStats[id][HIT_RIGHTARM], playerStats[id][HIT_LEFTARM], playerStats[id][HIT_RIGHTLEG], playerStats[id][HIT_LEFTLEG]);
	add(queryData, charsmax(queryData), queryTemp);

	playerStats[id][CURRENT_STATS] = playerStats[id][CURRENT_KILLS] * 2 + playerStats[id][CURRENT_HS] - playerStats[id][CURRENT_DEATHS] * 2;

	if (playerStats[id][CURRENT_STATS] > playerStats[id][BEST_STATS]) {
		formatex(queryTemp, charsmax(queryTemp), ", best_stats = %d, best_kills = %d, best_hs = %d, best_deaths = %d", 
		playerStats[id][CURRENT_STATS], playerStats[id][CURRENT_KILLS], playerStats[id][CURRENT_HS], playerStats[id][CURRENT_DEATHS]);
		add(queryData, charsmax(queryData), queryTemp);
	}

	new medals = playerStats[id][GOLD] * 3 + playerStats[id][SILVER] * 2 + playerStats[id][BRONZE];
	
	if (medals > playerStats[id][MEDALS]) {			
		formatex(queryTemp, charsmax(queryTemp), ", gold = %d, silver = %d, bronze = %d, medals = '%d'", 
		playerStats[id][GOLD], playerStats[id][SILVER], playerStats[id][BRONZE], medals);
		add(queryData, charsmax(queryData), queryTemp);
	}

	switch(rankSaveType) {
		case 0: formatex(queryTemp, charsmax(queryTemp), " WHERE name = ^"%s^"", playerStats[id][SAFE_NAME]);
		case 1: formatex(queryTemp, charsmax(queryTemp), " WHERE steamid = ^"%s^"", playerStats[id][STEAMID]);
		case 2: formatex(queryTemp, charsmax(queryTemp), " WHERE ip = ^"%s^"", playerStats[id][IP]);
	}

	add(queryData, charsmax(queryData), queryTemp);

	if (end == MAP_END) {
		static error[128], errorNum, Handle:query;
		
		query = SQL_PrepareQuery(connection, queryData);
		
		if (!SQL_Execute(query)) {
			errorNum = SQL_QueryError(query, error, charsmax(error));
			
			log_to_file("ultimate_stats.log", "SQL Query Error. [%d] %s", errorNum, error);
		}

		SQL_FreeHandle(query);
	} else SQL_ThreadQuery(sql, "ignore_handle", queryData);

	if (end == ROUND) {
		static playerId[2];

		playerId[0] = id;
		playerId[1] = 0;

		formatex(queryData, charsmax(queryData), "SELECT (SELECT COUNT(*) FROM `ultimate_stats` WHERE (kills - deaths) >= (a.kills - a.deaths)) AS rank FROM `ultimate_stats` a WHERE ");

		switch (rankSaveType) {
			case 0: formatex(queryTemp, charsmax(queryTemp), "name = ^"%s^"", playerStats[id][SAFE_NAME]);
			case 1: formatex(queryTemp, charsmax(queryTemp), "steamid = ^"%s^"", playerStats[id][STEAMID]);
			case 2: formatex(queryTemp, charsmax(queryTemp), "ip = ^"%s^"", playerStats[id][IP]);
		}

		add(queryData, charsmax(queryData), queryTemp);
		
		SQL_ThreadQuery(sql, "get_rank_handle", queryData, playerId, sizeof(playerId));
	}

	if (end > 0) rem_bit(id, statsLoaded);

	save_weapons_stats(id, end);
}

stock save_weapons_stats(id, end = 0)
{
	if (!get_bit(id, weaponStatsLoaded)) return;

	static queryData[2048], queryTemp[512], weaponName[32];
	queryData = "";

	for (new i = 1; i < MAX_WEAPONS; i++) {
		if ((i == CSW_SHIELD || i == CSW_C4 || i == CSW_FLASHBANG || i == CSW_SMOKEGRENADE) || (!playerWRStats[id][i][STATS_SHOTS] && !playerWRStats[id][i][STATS_DEATHS])) continue;

		get_weaponname(i, weaponName, charsmax(weaponName));

		formatex(queryTemp, charsmax(queryTemp), "UPDATE `ultimate_stats_weapons` SET kills = %d, deaths = %d, hs_kills = %d, team_kills = %d, shots = %d, hits = %d, damage = %d, h_1 = %d, h_2 = %d, h_3 = %d, h_4 = %d, h_5 = %d, h_6 = %d, h_7 = %d WHERE weapon = '%s' AND player_id = %i; ", 
		playerWStats[id][i][STATS_KILLS], playerWStats[id][i][STATS_DEATHS], playerWStats[id][i][STATS_HS], playerWStats[id][i][STATS_TK], playerWStats[id][i][STATS_SHOTS], playerWStats[id][i][STATS_HITS], playerWStats[id][i][STATS_DAMAGE], playerWStats[id][i][HIT_HEAD], 
		playerWStats[id][i][HIT_CHEST], playerWStats[id][i][HIT_STOMACH], playerWStats[id][i][HIT_LEFTARM], playerWStats[id][i][HIT_RIGHTARM], playerWStats[id][i][HIT_LEFTLEG], playerWStats[id][i][HIT_RIGHTLEG], weaponName, playerStats[id][PLAYER_ID]);

		add(queryData, charsmax(queryData), queryTemp);
	}

	if (queryData[0]) {
		if (end == MAP_END) {
			static error[128], errorNum, Handle:query;
				
			query = SQL_PrepareQuery(connection, queryData);
			
			if (!SQL_Execute(query)) {
				errorNum = SQL_QueryError(query, error, charsmax(error));
				
				log_to_file("ultimate_stats.log", "SQL Query Error. [%d] %s", errorNum, error);
			}

			SQL_FreeHandle(query);
		} else SQL_ThreadQuery(sql, "ignore_handle", queryData);
	}

	if (end > 0) rem_bit(id, weaponStatsLoaded);
}

public load_sounds(id)
{
	if (!soundsEnabled) return;

	new vaultKey[64], vaultData[16], soundsData[5][5];
	
	formatex(vaultKey, charsmax(vaultKey), "%s-sounds", playerStats[id][NAME]);
	
	if (nvault_get(sounds, vaultKey, vaultData, charsmax(vaultData))) {
		parse(vaultData, soundsData[0], charsmax(soundsData), soundsData[1], charsmax(soundsData), soundsData[2], charsmax(soundsData), soundsData[3], charsmax(soundsData), soundsData[4], charsmax(soundsData));

		if (str_to_num(soundsData[0])) set_bit(id, soundMayTheForce);
		if (str_to_num(soundsData[1])) set_bit(id, soundOneAndOnly);
		if (str_to_num(soundsData[2])) set_bit(id, soundHumiliation);
		if (str_to_num(soundsData[3])) set_bit(id, soundPrepare);
		if (str_to_num(soundsData[4])) set_bit(id, soundLastLeft);
	}
} 

public save_sounds(id)
{
	if (!soundsEnabled) return;

	new vaultKey[64], vaultData[16];
	
	formatex(vaultKey, charsmax(vaultKey), "%s-sounds", playerStats[id][NAME]);
	formatex(vaultData, charsmax(vaultData), "%d %d %d %d %d", get_bit(id, soundMayTheForce), get_bit(id, soundOneAndOnly), get_bit(id, soundHumiliation), get_bit(id, soundPrepare), get_bit(id, soundLastLeft));
	
	nvault_set(sounds, vaultKey, vaultData);
}

stock get_player_id(id)
{
	new queryData[128], error[128], Handle:query, errorNum, playerId;

	switch (rankSaveType) {
		case 0: formatex(queryData, charsmax(queryData), "SELECT id FROM `ultimate_stats` WHERE name = ^"%s^"", playerStats[id][SAFE_NAME]);
		case 1: formatex(queryData, charsmax(queryData), "SELECT id FROM `ultimate_stats` WHERE steamid = ^"%s^"", playerStats[id][STEAMID]);
		case 2: formatex(queryData, charsmax(queryData), "SELECT id FROM `ultimate_stats` WHERE ip = ^"%s^"", playerStats[id][IP]);
	}

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) playerId = SQL_ReadResult(query, 0);
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		log_to_file("ultimate_stats.log", "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return playerId;
}

stock clear_stats(player = 0, reset = 0)
{
	new limit = player ? player : MAX_PLAYERS;

	for (new id = player; id <= limit; id++) {
		if (player) playerStats[id][ELO_RANK] = _:100.0;

		for (new i = HIT_GENERIC; i <= CURRENT_HS; i++) {
			if (player) playerStats[id][i] = 0;
			if (!reset) playerRStats[id][i] = 0;
		}

		for (new i = 1; i < MAX_WEAPONS; i++) {
			for (new j = 1; j < STATS_END; j++) {
				if (player) playerWStats[id][i][j] = 0;

				playerWRStats[id][i][j] = 0;
			}
		}

		for (new i = 1; i <= MAX_PLAYERS; i++) {
			for (new j = 1; j < STATS_END; j++) {
				playerAStats[id][i][j] = 0;
				playerVStats[id][i][j] = 0;
			}
		}
	}
}

stock get_loguser_index()
{
	new userLog[96], userName[32];
	
	read_logargv(0, userLog, charsmax(userLog));
	parse_loguser(userLog, userName, charsmax(userName));

	return get_user_index(userName);
}

stock sql_safe_string(const source[], dest[], length)
{
	copy(dest, length, source);
	
	replace_all(dest, length, "\\", "\\\\");
	replace_all(dest, length, "\0", "\\0");
	replace_all(dest, length, "\n", "\\n");
	replace_all(dest, length, "\r", "\\r");
	replace_all(dest, length, "\x1a", "\Z");
	replace_all(dest, length, "'", "\'");
	replace_all(dest, length, "`", "\`");
	replace_all(dest, length, "^"", "\^"");
}

public native_get_statsnum()
	return statsNum;

public native_reset_user_wstats(id)
{
	if (!is_user_connected(id)) return false;

	clear_stats(id, 1);

	return true;
}
