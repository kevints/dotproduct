#include "DotProductRNG.h"

#include <random>

struct DotProductRNG final {
    std::mt19937_64 rng;
    DotProductRNG() noexcept : rng(std::mt19937_64{}) {}
    void Seed(uint64_t value) & noexcept {
        rng.seed(value);
    }
    uint64_t Next() & noexcept {
        return rng();
    }
};

extern "C" DotProductRNG* DotProductRNG_New() {
    try {
        return new DotProductRNG{};
    } catch (const std::bad_alloc&) {
        std::terminate();
    }
}

extern "C" DotProductRNG* DotProductRNG_Copy(const DotProductRNG* rng) {
    try {
        return new DotProductRNG{*rng};
    } catch (const std::bad_alloc&) {
        std::terminate();
    }
}

extern "C" void DotProductRNG_Seed(DotProductRNG* rng, uint64_t value) {
    rng->Seed(value);
}

extern "C" uint64_t DotProductRNG_Next(DotProductRNG *rng) {
    return rng->Next();
}

extern "C" void DotProductRNG_Delete(DotProductRNG* rng) {
    delete rng;
}
