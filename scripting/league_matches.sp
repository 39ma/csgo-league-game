// Modified version of:
// https://github.com/DistrictNineHost/Sourcemod-SQLMatches/blob/master/game%20server/sqlmatch.sp

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

Handle db;

public Plugin myinfo = {
	name = "[League] Matches",
	author = "B3none",
	description = "League scoreboard saving system.",
	version = "1.0.0",
	url = "https://github.com/b3none/csgo-league-game"
};

public void OnPluginStart() {
	char buffer[1024];

	if ((db = SQL_Connect("league", true, buffer, sizeof(buffer))) == null) {
		SetFailState(buffer);
	}

	HookEventEx("cs_win_panel_match", cs_win_panel_match);
}

public void cs_win_panel_match(Handle event, const char[] eventname, bool dontBroadcast) {
	CreateTimer(0.1, delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action delay(Handle timer) {
	Transaction txn = SQL_CreateTransaction();

	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	
	char teamname1[64];
	char teamname2[64];

	GetConVarString(FindConVar("mp_teamname_1"), teamname1, sizeof(teamname1));
	GetConVarString(FindConVar("mp_teamname_2"), teamname2, sizeof(teamname2));

	char buffer[512];

	Format(buffer, sizeof(buffer), "INSERT INTO sql_matches_scoretotal (team_0, team_1, team_2, team_3, teamname_1, teamname_2, map, timestamp) VALUES (0, 0, 0, 0, '%s', '%s', '%s', '%i');", teamname1, teamname2, mapname, GetTime());
	SQL_AddQuery(txn, buffer);

	int ent = MaxClients + 1;
	
	while ((ent = FindEntityByClassname(ent, "cs_team_manager")) != -1) {
		Format(buffer, sizeof(buffer), "UPDATE sql_matches_scoretotal SET team_%i = %i WHERE match_id = LAST_INSERT_ID();", GetEntProp(ent, Prop_Send, "m_iTeamNum"), GetEntProp(ent, Prop_Send, "m_scoreTotal"));
		SQL_AddQuery(txn, buffer);
	}

	char name[MAX_NAME_LENGTH];
	char steamid64[64];

	int m_iTeam;
	int m_bAlive;
	int m_iPing;
	int m_iAccount;
	int m_iKills;
	int m_iAssists;
	int m_iDeaths;
	int m_iMVPs;
	int m_iScore;

	if ((ent = FindEntityByClassname(-1, "cs_player_manager")) != -1) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i)) {
				continue;
			}

			m_iTeam = GetEntProp(ent, Prop_Send, "m_iTeam", _, i);
			m_bAlive = GetEntProp(ent, Prop_Send, "m_bAlive", _, i);
			m_iPing = GetEntProp(ent, Prop_Send, "m_iPing", _, i);
			m_iAccount = GetEntProp(i, Prop_Send, "m_iAccount");
			m_iKills = GetEntProp(ent, Prop_Send, "m_iKills", _, i);
			m_iAssists = GetEntProp(ent, Prop_Send, "m_iAssists", _, i);
			m_iDeaths = GetEntProp(ent, Prop_Send, "m_iDeaths", _, i);
			m_iMVPs = GetEntProp(ent, Prop_Send, "m_iMVPs", _, i);
			m_iScore = GetEntProp(ent, Prop_Send, "m_iScore", _, i);

			Format(name, MAX_NAME_LENGTH, "%N", i);
			SQL_EscapeString(db, name, name, sizeof(name));

			if (!GetClientAuthId(i, AuthId_SteamID64, steamid64, sizeof(steamid64))) {
				steamid64[0] = '\0';
			}

			Format(buffer, sizeof(buffer), "INSERT INTO sql_matches");
			Format(buffer, sizeof(buffer), "%s (match_id, team, alive, ping, name, account, kills, assists, deaths, mvps, score, steam)", buffer);
			Format(buffer, sizeof(buffer), "%s VALUES (LAST_INSERT_ID(), '%i', '%i', '%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i', '%s');", buffer, m_iTeam, m_bAlive, m_iPing, name, m_iAccount, m_iKills, m_iAssists, m_iDeaths, m_iMVPs, m_iScore, steamid64);
			SQL_AddQuery(txn, buffer);
		}
	}

	SQL_ExecuteTransaction(db, txn);
}

public void onSuccess(Database database, any data, int numQueries, Handle[] results, any[] bufferData) {
	PrintToServer("onSuccess");
}

public void onError(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
	PrintToServer("onError");
}
