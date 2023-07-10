#include "CXXDotProduct.h"

#include <valarray>

ProgressResult aggregate(std::valarray<float>&& progresses, std::valarray<float>&& weights) noexcept {
    ProgressResult result;
    result.raw_progress = progresses.sum();
    progresses *= std::move(weights);
    result.weighted_progress = std::move(progresses).sum();
    return result;
}

extern "C" ProgressResult aggregate_progress5(const float *progresses, const float *weights, size_t len) {
    std::valarray<float> floatProgresses(progresses, len);
    std::valarray<float> weightsArray(weights, len);
    return aggregate(std::move(floatProgresses), std::move(weightsArray));
}
