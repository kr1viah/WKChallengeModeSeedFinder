
// RandomNumberGenerator

typedef struct {
    uint64_t state;
    uint64_t inc;
    uint64_t p_inc;
    uint64_t p_seed;
    uint64_t current_seed;
} RandomNumberGenerator;

__device__ RandomNumberGenerator Initialise() {
    RandomNumberGenerator rng = {0};
	rng.p_inc = 1442695040888963407;
	rng.p_seed = 12047754176567800795;
    return rng;
};

__device__ uint32_t Randi(RandomNumberGenerator* rng) {
    uint64_t oldstate = rng->state;
    rng->state = oldstate * 6364136223846793005UL + (rng->inc | 1UL);
    uint16_t xorshifted = (uint16_t)(((oldstate >> 18u) ^ oldstate) >> 27u);
    uint16_t rot = (uint16_t)(oldstate >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

__device__ uint32_t randbound(RandomNumberGenerator* rng, uint32_t bound) {
	uint32_t threshold = -bound % bound;

	for (;;) {
		uint32_t r = Randi(rng);
		if (r >= threshold)
			return r % bound;
	}
}

__device__ double randf32(RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return (double) (float) (ldexp((double)(Randi(rng) | 0x80000001), -32 - __clzll(proto_exp_offset)));
}

__device__ double randf64(RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	uint64_t significand = (((uint64_t)Randi(rng)) << 32) | Randi(rng) | 0x8000000000000001U;
	return ldexp((double)significand, -64 - __clz(proto_exp_offset));
}

__device__ void Set_seed(RandomNumberGenerator* rng, uint64_t p_seed) {
	rng->current_seed = p_seed;
    rng->state = 0U;
    rng->inc = (rng->p_inc << 1u) | 1u;
    Randi(rng);
    rng->state += rng->current_seed;
    Randi(rng);
}

__device__ uint64_t Get_seed(RandomNumberGenerator* rng) { return rng->current_seed; }
__device__ void     Set_state(RandomNumberGenerator* rng, uint64_t p_state) { rng->state = p_state; }
__device__ uint64_t Get_state(RandomNumberGenerator* rng) { return rng->state; }

__device__ double Randf(RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return (double) (float) (ldexp((double)(Randi(rng) | 0x80000001), -32 - __clz(proto_exp_offset))); 
}

__device__ double Randf_range(RandomNumberGenerator* rng, float p_from, float p_to) {
    float temp = randf32(rng);
    // printf("%.15f\n", temp);
    return (double)(temp*(p_to-p_from)+p_from);
}

__device__ double Randfn(RandomNumberGenerator* rng, float p_mean, float p_deviation) {
    double temp = randf32(rng);
    if (temp < 0.00001) {
        temp += 0.00001;
    }
    return p_mean + p_deviation * (cos(6.2831853071795864769252867666 * (double)(randf32(rng))) * sqrt(-2.0 * log((double)(temp))));
}

__device__ int Randi_range(RandomNumberGenerator* rng, int p_from, int p_to) {
	if (p_from == p_to) {
		return p_from;
	}
    uint32_t bounds = (uint16_t)((int)(fabs((double)(p_from-p_to)))+1);
    int randomValue = (int)(randbound(rng, bounds));
    if (p_from < p_to) {
        return p_from+randomValue;
    }
    return p_to+randomValue;
}

// RandomNumberGenerator

__device__ void Shuffle(RandomNumberGenerator* rng, int *arr) {
    // if (n <= 1) // assumes n = 8
        // return;
    for (uint16_t i = 7; i > 0; i--) {
        uint16_t r = randbound(rng, i+1);
        uint16_t j = r % (i + 1);
        int tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;
    }
}
