#ifndef _CXXDotProduct_CXXDotProduct_h
#define _CXXDotProduct_CXXDotProduct_h

#include <stddef.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

typedef struct ProgressResult {
    float weighted_progress;
    float raw_progress;
} ProgressResult;

ProgressResult aggregate_progress1(const uint8_t *progresses, const float *weights, size_t len);

typedef struct ProgressRecord {
    uint8_t progress;
    float weight;
} ProgressRecord;

typedef struct Aggregator Aggregator;
typedef struct AggregatorVTable {
    size_t(*size)(void);
    size_t(*align)(void);
    Aggregator*(*init)(void*);
    Aggregator*(*copy)(void*, const Aggregator*);
    void(*prepare)(Aggregator*, const ProgressRecord*, size_t);
    ProgressResult(*execute)(Aggregator*);
    void(*destroy)(Aggregator*);
} AggregatorVTable;
struct Aggregator {
    const AggregatorVTable *vtable;
};
extern const AggregatorVTable *progress1VTable;
Aggregator* Aggregator_New(const AggregatorVTable* vtable);
Aggregator* Aggregator_Copy(const Aggregator*);
void Aggregator_Prepare(Aggregator*, const ProgressRecord*, size_t);
ProgressResult Aggregator_Execute(Aggregator*);
void Aggreagator_Delete(Aggregator*);

ProgressResult aggregate_progress2(const ProgressRecord* progresses, size_t len);

ProgressResult aggregate_progress5(const float *progresses, const float *weights, size_t len);
ProgressResult aggregate_progress6(const ProgressRecord* progresses, size_t len);

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // _CXXDotProduct_CXXDotProduct_h
