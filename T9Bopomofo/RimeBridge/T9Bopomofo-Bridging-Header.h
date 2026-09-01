#ifndef T9Bopomofo_Bridging_Header_h
#define T9Bopomofo_Bridging_Header_h

// rime_api.h uses `#define Bool int` / True / False, which clobber Swift.Bool.
typedef int RimeCBool;
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
