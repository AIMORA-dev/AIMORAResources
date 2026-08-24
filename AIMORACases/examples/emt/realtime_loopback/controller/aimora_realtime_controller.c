#include <stddef.h>
#include <stdint.h>

typedef struct {
    double filtered_measurement;
} aimora_realtime_controller_state;

uint32_t aimora_realtime_controller_abi_version(void) {
    return 1u;
}

size_t aimora_realtime_controller_state_bytes(void) {
    return sizeof(aimora_realtime_controller_state);
}

int aimora_realtime_controller_reset(void *state_memory, size_t state_bytes) {
    if (state_memory == NULL || state_bytes != sizeof(aimora_realtime_controller_state)) {
        return 1;
    }
    aimora_realtime_controller_state *state =
        (aimora_realtime_controller_state *)state_memory;
    state->filtered_measurement = 0.0;
    return 0;
}

int aimora_realtime_controller_step(
    void *state_memory,
    const double *model_outputs,
    size_t output_count,
    double *model_inputs,
    size_t input_count,
    uint64_t logical_step,
    int64_t logical_time_ns
) {
    (void)logical_step;
    (void)logical_time_ns;
    if (state_memory == NULL || model_outputs == NULL || model_inputs == NULL) {
        return 2;
    }
    if (output_count != 1u || input_count != 1u) {
        return 3;
    }
    aimora_realtime_controller_state *state =
        (aimora_realtime_controller_state *)state_memory;
    state->filtered_measurement +=
        0.25 * (model_outputs[0] - state->filtered_measurement);
    model_inputs[0] = 2.0 * state->filtered_measurement;
    return 0;
}
