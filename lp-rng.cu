// lp = low precision

typedef struct {
    uint64_t state;
    uint64_t inc;
    uint64_t p_inc;
    uint64_t p_seed;
    uint64_t current_seed;
} lp_RandomNumberGenerator;

typedef struct {
    int character;
    int abilityCharacter;
    double abilityLevel;
    int itemCounts[8];
    double startTime;
    int32_t colorState;
    double intensity;
} lp_loadout;

__device__ lp_RandomNumberGenerator lp_Initialise() {
    lp_RandomNumberGenerator rng = {0};
	rng.p_inc = 1442695040888963407;
	rng.p_seed = 12047754176567800795;
    return rng;
};

__device__ uint32_t lp_Randi(lp_RandomNumberGenerator* rng) {
    uint64_t oldstate = rng->state;
    rng->state = oldstate * 6364136223846793005UL + (rng->inc | 1UL);
    uint16_t xorshifted = (uint16_t)(((oldstate >> 18u) ^ oldstate) >> 27u);
    uint16_t rot = (uint16_t)(oldstate >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

__device__ uint32_t lp_randbound(lp_RandomNumberGenerator* rng, uint32_t bound) {
	uint32_t threshold = -bound % bound;

	for (;;) {
		uint32_t r = lp_Randi(rng);
		if (r >= threshold)
			return r % bound;
	}
}

__device__ float lp_randf32(lp_RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = lp_Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return ldexp((float)(lp_Randi(rng) | 0x80000001), -32 - __clzll(proto_exp_offset));
}

__device__ void lp_Set_seed(lp_RandomNumberGenerator* rng, uint64_t p_seed) {
	rng->current_seed = p_seed;
    rng->state = 0U;
    rng->inc = (rng->p_inc << 1u) | 1u;
    lp_Randi(rng);
    rng->state += rng->current_seed;
    lp_Randi(rng);
}

__device__ uint64_t lp_Get_seed(lp_RandomNumberGenerator* rng) { return rng->current_seed; }
__device__ void     lp_Set_state(lp_RandomNumberGenerator* rng, uint64_t p_state) { rng->state = p_state; }
__device__ uint64_t lp_Get_state(lp_RandomNumberGenerator* rng) { return rng->state; }

__device__ float lp_Randf(lp_RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = lp_Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return (ldexp((float)(lp_Randi(rng) | 0x80000001), -32 - __clz(proto_exp_offset))); 
}

__device__ float lp_Randf_range(lp_RandomNumberGenerator* rng, float p_from, float p_to) {
    float temp = lp_randf32(rng);
    // printf("%.15f\n", temp);
    return temp*(p_to-p_from)+p_from;
}

__device__ float lp_Randfn(lp_RandomNumberGenerator* rng, float p_mean, float p_deviation) {
    float temp = lp_randf32(rng);
    if (temp < 0.00001f) {
        temp += 0.00001f;
    }
    return p_mean + p_deviation * cos(6.283185307179586f * (lp_randf32(rng)) * sqrt(-2.0f * log((temp))));
}


__device__ int lp_Randi_range(lp_RandomNumberGenerator* rng, int p_from, int p_to) {
	if (p_from == p_to) {
		return p_from;
	}
    uint32_t bounds = (uint16_t)((int)(fabs((double)(p_from-p_to)))+1);
    int randomValue = (int)(lp_randbound(rng, bounds));
    if (p_from < p_to) {
        return p_from+randomValue;
    }
    return p_to+randomValue;
}

__device__ void lp_Shuffle(lp_RandomNumberGenerator* rng, int *arr) {
    // if (n <= 1) // assumes n = 8
        // return;
    for (uint16_t i = 7; i > 0; i--) {
        uint16_t r = lp_randbound(rng, i+1);
        uint16_t j = r % (i + 1);
        int tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;
    }
}

// low precision helper functions


// helper functions

__forceinline__ __device__
float lp_clamp(float m_a, float m_min, float m_max) {
	if (m_a < m_min) {
		return m_min;
	} else if (m_a > m_max) {
		return m_max;
	}
	return m_a;
}

__forceinline__ __device__
float lp_lerp(float a, float b, float t) {
    return a + t * (b - a);
}

__forceinline__ __device__
float lp_pinch(float v) { // function run() uses
	if (v < 0.5) {
		return -v * v;
	}
	return v * v;
}

__device__ float lp_run(float x, float a, float b, float c) { // TorCurve.run() in windowkill
	c = lp_pinch(c);
	x = fmaxf(0, fminf(1, x));
    const float eps = 0.00001f;
	float s = exp(a);
	float s2 = 1.0 / (s + eps);
	float t = fmaxf(0, fminf(1, b));
	float u = c;

	float res, c1, c2, c3;

	if (x < t) {
		c1 = (t * x) / (x + s*(t-x) + eps);
		c2 = t - pow(1/(t+eps), s2-1)*pow(abs(x-t), s2);
		c3 = pow(1/(t+eps), s-1) * pow(x, s);
	} else {
		c1 = (1-t)*(x-1)/(1-x-s*(t-x)+eps) + 1;
		c2 = pow(1/((1-t)+eps), s2-1)*pow(abs(x-t), s2) + t;
		c3 = 1 - pow(1/((1-t)+eps), s-1)*pow(1-x, s);
	}

	if (u <= 0) {
		res = (-u)*c2 + (1+u)*c1;
	} else {
		res = (u)*c3 + (1-u)*c1;
	}

	return res;
}

__forceinline__ __device__
float lp_smoothCorner(float x, float m, float l, float s) { // TorCurve.smoothCorner in windowkill
	float s1 = pow(s/10.0, 2.0);
	return 0.5 * ((l*x + m*(1.0+s1)) - sqrt(pow(abs(l*x-m*(1.0-s1)), 2.0)+4.0*m*m*s1));
}

// low precision seed func

__device__
lp_loadout lp_get_results(uint64_t seed) {
    lp_RandomNumberGenerator rng = lp_Initialise();
    lp_RandomNumberGenerator globalRng = lp_Initialise();
    lp_Set_seed(&rng, seed);

//                                 speed fireRate multiShot wallPunch splashDamage piercing freezing infection
    int itemCategories[8] = {      0,    1,       2,        3,        4,           5,       6,       7        };
    float itemCosts[8] = {         1.0f, 2.8f,    3.3f,     1.25f,    2.0f,        2.4f,    1.5f,    2.15f    };
    //                 basic mage laser melee pointer swarm
    int charList[6] = {0,    1,   2,    3,    4,      5};

    int itemCounts[8];

    float intensity = lp_Randf_range(&rng, 0.20f, 1.0f);

    int character = charList[lp_Randi(&rng) % 6];
    int abilityChar = charList[lp_Randi(&rng) % 6];
    float abilityLevel = 1.0 + round(lp_run(lp_Randf(&rng), 1.5/(1.0+intensity),1.0,0.0)*6);

    float itemCount = 8.0;


    float points = 0.66 * itemCount * lp_Randf_range(&rng, 0.5, 1.5) * (1.0 + 4.0*pow(intensity, 1.5));

    float itemDistSteepness = lp_Randf_range(&rng, -0.5, 2.0);
    
    float itemDistArea = 1.0 / (1.0 + pow(2.0, 0.98*itemDistSteepness));

    lp_Set_seed(&globalRng, lp_Get_seed(&rng));
    lp_Shuffle(&globalRng, itemCategories);
    
    if (lp_Randf(&rng) < intensity) {
        int multishotIdx = -1;
        for (int i = 0; i < itemCount; ++i) {
            if (itemCategories[i] == 2) {
                multishotIdx = i;
                break;
            }
        }

        if (multishotIdx != -1) {
            // Remove the multishot element
            for (int i = multishotIdx; i < itemCount - 1; ++i) {
                itemCategories[i] = itemCategories[i + 1];
            }
        }

        // Insert multiShot at a new index
        int insertIdx = itemCount - 1 - lp_Randi_range(&rng, 0, 2);
        for (int i = itemCount; i > insertIdx; --i) {
            itemCategories[i] = itemCategories[i - 1];
        }
        itemCategories[insertIdx] = 2;
    }

    if (lp_Randf(&rng) < intensity) {
        int fireRateIdx = -1;
        for (int i = 0; i < itemCount; ++i) {
            if (itemCategories[i] == 1) {
                fireRateIdx = i;
                break;
            }
        }

        if (fireRateIdx != -1) {
            // Remove the firerate element
            for (int i = fireRateIdx; i < itemCount - 1; ++i) {
                itemCategories[i] = itemCategories[i + 1];
            }
        }

        // Insert firerate at a new index
        int insertIdx = itemCount - 1 - lp_Randi_range(&rng, 0, 2);
        for (int i = itemCount; i > insertIdx; --i) {
            itemCategories[i] = itemCategories[i - 1];
        }
        itemCategories[insertIdx] = 1;
    }

    float catMax = 7.0;
    // int total = 0; // why does this exist?
    for (int i = 0; i < 8; i++) {
        int item = itemCategories[i];
        float catT = ((float) i) / catMax;
        float cost = itemCosts[item];
        cost = 1.0 + ((cost - 1.0) / 2.5);
        float baseAmount = 0.0;

        float special = 0.0;
        if (i == 7) {
            special += 4.0 * lp_Randf_range(&rng, 0.0, pow(intensity, 2.0));
        }
        float amount = fmax(0.0, 3.0 * lp_run(catT, itemDistSteepness, 1.0, 0.0) + 3.0 * lp_clamp(lp_Randfn(&rng, 0.0, 0.15), -0.5, 0.5));
        
        itemCounts[item] = (int) lp_clamp(round(baseAmount+amount*((points/cost)/(1.0+5.0*itemDistArea))+special), 0.0, 26.0);
    }

    intensity = -0.05 + intensity*lp_lerp(0.33, 1.2, lp_smoothCorner(((float) itemCounts[2]*1.8+(float) itemCounts[1])/12.0, 1.0, 1.0, 4.0)); // TODO: smoothCorner()

    float finalT = lp_Randfn(&rng, (float) pow(intensity, 1.2), 0.05);
    float startTime = lp_clamp(lp_lerp(60.0*2.0, 60.0*20.0, finalT), 60.0*2.0, 60.0*25.0);

    lp_Randf(&rng);
    lp_Randf(&rng);
    int colorState = lp_Randi_range(&rng, 0, 2);
    return lp_loadout{character, abilityChar, abilityLevel, {itemCounts[0], itemCounts[1], itemCounts[2], itemCounts[3], itemCounts[4], itemCounts[5], itemCounts[6], itemCounts[7]}, startTime, colorState};
}
