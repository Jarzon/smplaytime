#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME     "Play time"
#define PLUGIN_AUTHOR   "Master J"
#define PLUGIN_VERSION  "1.0.3"
#define PLUGIN_DESCRIP  "Save the play time in a DB"
#define PLUGIN_CONTACT  "http://masterj.net"

new Handle:gh_db = INVALID_HANDLE;
    
new g_times[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIP,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	if(SQL_CheckConfig("playtime")) {
		gh_db = SQL_Connect("playtime", true, error, err_max);
	} else {
		gh_db = SQL_Connect("default", true, error, err_max);
	}
	
	if(gh_db == INVALID_HANDLE) {
		return APLRes_Failure;
	}
	
	SQL_SetCharset(gh_db, "utf8");
	
	return APLRes_Success;
}

public OnPluginStart()
{
    for(new i = 1; i <= MaxClients; i++) {
        if(IsClientConnected(i)) {
            GetPlaytime(i);
        }
    }
}

public OnClientConnected(client)
{
    
}

public GetPlaytime(client)
{
    // Bot or LAN player
    if (IsFakeClient(client)) {
        return;
    }
    
    // Insert the timestamp in the row of the client
    g_times[client] = GetTime();
}

public OnClientAuthorized(client, const String:auth[])
{
    GetPlaytime(client);
}

public T_InsertPlaytime(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE) {
		PrintToServer("Insert new player playtime query failed: %s", error);
    }
}

public T_UpdatedPlaytime(Handle:owner, Handle:hndl, const String:error[], Handle pack)
{
    if (hndl == INVALID_HANDLE) {
        LogError("Update playtime query failed: %s", error);
    }

    // If the player is not in the DB yet, then we do a insert
    if(SQL_GetAffectedRows(hndl) == 0) {
        decl String:steamid[32],
            String:name[45],
            String:ip[45];
        
        ResetPack(pack);
        int client = ReadPackCell(pack);
        int time = ReadPackCell(pack);
        
        ReadPackString(pack, steamid, sizeof(steamid));
        ReadPackString(pack, name, sizeof(name));
        ReadPackString(pack, ip, sizeof(ip));
        
        decl String:query[256];
        FormatEx(query, sizeof(query), "INSERT INTO playtime (steamid, ip, name, time) VALUES(\"%s\", \"%s\", \"%s\", %i)", steamid, ip, name, time);
        SQL_TQuery(gh_db, T_InsertPlaytime, query, client, DBPrio_High);
    }
    
    CloseHandle(pack);
}

public OnClientDisconnect(client)
{
    // Bot or LAN player
    if (IsFakeClient(client)) {
        return;
    }
    
    if(gh_db != INVALID_HANDLE && g_times[client] > 0) {
        decl String:steamid[32],
            String:name[45],
            String:ip[45];
            
        int time = GetTime() - g_times[client];
        
        g_times[client] = 0;
        
        GetClientAuthId(client, AuthId_Steam3, steamid, sizeof(steamid));
        
        GetClientName(client, name, sizeof(name));
        
        GetClientIP(client, ip, sizeof(ip));
        
        new Handle:pack = CreateDataPack();
        
        WritePackCell(pack, client);
        WritePackCell(pack, time);
        WritePackString(pack, steamid);
        WritePackString(pack, name);
        WritePackString(pack, ip);
        
        decl String:query[256];
        FormatEx(query, sizeof(query), "UPDATE playtime SET ip = \"%s\", name = \"%N\", time = time + %i WHERE steamid = \"%s\"", ip, client, time, steamid);
        SQL_TQuery(gh_db, T_UpdatedPlaytime, query, pack, DBPrio_High);
    }
}