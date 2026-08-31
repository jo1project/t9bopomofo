#ifndef T9Bopomofo_Bridging_Header_h
#define T9Bopomofo_Bridging_Header_h

// rime_api.h typedefs `Bool` as int and defines True/False macros.
// That collides with Swift.Bool across the whole keyboard target — rename first.
#define Bool RimeCBool
#include "rime_api.h"
#undef Bool
#ifdef True
#undef True
#endif
#ifdef False
#undef False
#endif

#endif /* T9Bopomofo_Bridging_Header_h */
