#include "CXXDotProduct.h"

#include <algorithm>
#include <cassert>
#include <memory>
#include <new>

namespace {
    
ProgressResult aggregate(const uint8_t *progresses, const float *weights, size_t size) noexcept {
    float total_progress = 0.0f;
    float weighted_progress = 0.0f;
    for (size_t i = 0; i < size; ++i) {
        weighted_progress += progresses[i] * weights[i];
        total_progress += progresses[i];
    }
    return ProgressResult{weighted_progress, total_progress};
}
    
ProgressResult aggregate(const ProgressRecord *records, size_t size) noexcept {
    ProgressResult result{};
    for (size_t i = 0; i < size; ++i) {
        result.weighted_progress += records[i].progress * records[i].weight;
        result.raw_progress += records[i].progress;
    }
    return result;
}
    
}

extern "C" ProgressResult aggregate_progress1(const uint8_t* progresses, const float *weights, size_t size) {
    return aggregate(progresses, weights, size);
}

extern "C" ProgressResult aggregate_progress2(const ProgressRecord* records, size_t size) {
    return aggregate(records, size);
}

struct Progress1Aggregator : Aggregator {
    std::unique_ptr<uint8_t[]> progresses = nullptr;
    std::unique_ptr<float[]> weights = nullptr;
    std::size_t size = 0;
    
    Progress1Aggregator() : Aggregator{.vtable = progress1VTable} {}
    Progress1Aggregator(Progress1Aggregator&&) noexcept = default;
    Progress1Aggregator& operator=(Progress1Aggregator&&) noexcept = default;
    
    Progress1Aggregator(const Progress1Aggregator& o) noexcept : size(o.size) {
        if (size > 0) {
            progresses = std::unique_ptr<uint8_t[]>{new uint8_t[size]};
            weights = std::unique_ptr<float[]>{new float[size]};
            std::copy_n(o.progresses.get(), o.size, progresses.get());
            std::copy_n(o.weights.get(), size, weights.get());
        }
    }
    Progress1Aggregator& operator=(const Progress1Aggregator& o) {
        *this = Progress1Aggregator{o};
        return *this;
    }
    
    void prepare(const ProgressRecord *records, size_t size) noexcept {
        if (size > 0) {
            this->size = size;
            progresses = std::unique_ptr<uint8_t[]>{new uint8_t[size]};
            weights = std::unique_ptr<float[]>{new float[size]};
            for (size_t i = 0; i < size; ++i) {
                progresses[i] = records[i].progress;
                weights[i] = records[i].weight;
            }
        }
    }
    
    ProgressResult execute() const noexcept {
        return aggregate_progress1(progresses.get(), weights.get(), size);
    }
};

static const AggregatorVTable progress1VTableData = {
    .size = []() -> size_t {
        return sizeof(Progress1Aggregator);
    },
    .align = []() -> size_t {
        return alignof(Progress1Aggregator);
    },
    .init = [](void* mem) noexcept -> Aggregator* {
        assert(mem != nullptr);
        assert(reinterpret_cast<uintptr_t>(mem) % alignof(Progress1Aggregator) == 0);
        return ::new(mem) Progress1Aggregator();
    },
    .copy = [](void* mem, const Aggregator* o) noexcept -> Aggregator* {
        assert(mem != nullptr);
        assert(reinterpret_cast<uintptr_t>(mem) % alignof(Progress1Aggregator) == 0);
        assert(o != nullptr);
        assert(o->vtable == progress1VTable);
        return ::new(mem) Progress1Aggregator(*static_cast<const Progress1Aggregator *>(o));
    },
    .prepare = [](Aggregator* a, const ProgressRecord *records, size_t records_count) noexcept {
        assert(a != nullptr);
        assert(a->vtable == progress1VTable);
        assert(records_count > 0 || records != nullptr);
        assert(records_count >= 0);
        static_cast<Progress1Aggregator*>(a)->prepare(records, records_count);
    },
    .execute = [](Aggregator* a) noexcept {
        assert(a != nullptr);
        assert(a->vtable == progress1VTable);
        return static_cast<Progress1Aggregator*>(a)->execute();
    },
    .destroy = [](Aggregator* a) noexcept {
        if (a != nullptr) {
            assert(a->vtable == progress1VTable);
            static_cast<Progress1Aggregator *>(a)->~Progress1Aggregator();
        }
    }
};

extern "C" const AggregatorVTable *progress1VTable = &progress1VTableData;

extern "C" Aggregator* Aggregator_New(const AggregatorVTable *vtable) {
    void *mem = ::operator new(vtable->size(), static_cast<std::align_val_t>(vtable->align()));
    return ::new(mem) Progress1Aggregator();
}

extern "C" void Aggregator_Prepare(Aggregator* aggregator, const ProgressRecord* records, size_t size) {
    return aggregator->vtable->prepare(aggregator, records, size);
}

extern "C" ProgressResult Aggregator_Execute(Aggregator* aggregator) {
    return aggregator->vtable->execute(aggregator);
}

extern "C" void Aggregator_Delete(Aggregator* aggregator) {
    if (aggregator != nullptr) {
        size_t alignment = aggregator->vtable->align();
        void (*destroy)(Aggregator*) = aggregator->vtable->destroy;
        (*destroy)(aggregator);
        ::operator delete(static_cast<void*>(aggregator), static_cast<std::align_val_t>(alignment));
    }
}
