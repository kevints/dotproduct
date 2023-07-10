#ifndef _RNG_RNG_h
#define _RNG_RNG_h

#include <inttypes.h>

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct DotProductRNG DotProductRNG;
DotProductRNG * DotProductRNG_New(void);
DotProductRNG * DotProductRNG_Copy(const DotProductRNG *rng);
void DotProductRNG_Seed(DotProductRNG*, uint64_t);
uint64_t DotProductRNG_Next(DotProductRNG*);
void DotProductRNG_Delete(DotProductRNG*);

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // _RNG_RNG_h
