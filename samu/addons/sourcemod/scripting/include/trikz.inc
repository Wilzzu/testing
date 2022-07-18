#if defined _trikz_included
	#endinput
#endif
#define _trikz_included

/**
 * Check if the client has a partner.
 * 
 * @param client					Client index.
 * @error							Throw error if client is invalid.
 * @return							True if the client has a partner, else false.
 */
native bool Trikz_HasPartner(int client);

/**
 * Get the client's current Trikz partner.
 * 
 * @param client					Client index.
 * @error							Throw error if client is invalid.
 * @return							Trikz partner, or -1 if none.
 */
native int Trikz_FindPartner(int client);

public SharedPlugin __pl_trikz =
{
	name = "trikz",
	file = "trikz_redux.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public void __pl_trikz_SetNTVOptional()
{
	MarkNativeAsOptional("Trikz_FindPartner");
	MarkNativeAsOptional("Trikz_HasPartner");
}