#include "rng.cuh"
// lp means low precision

// __device__ float lp_randf32(RandomNumberGenerator* rng) {
// 	uint32_t proto_exp_offset = Randi(rng);
// 	if (proto_exp_offset == 0) {
// 		return 0;
// 	}
// 	return ldexp((float)(Randi(rng) | 0x80000001), -32 - __clzll(proto_exp_offset));
// } 
//
// im reading godot's source code and apparently this is literally not a thing??
// __clzll never occurs ever there (neither does clzll)
// - kr1v 20/05/2025 16:00
//
// ok apparently this existed because I used it originally
// to stay perfectly accurate with the godot version
// still don't know why I used clzll
// - kr1v 20/05/2025 16:38  

// __device__ double randf64(RandomNumberGenerator* rng) {
// 	uint32_t proto_exp_offset = Randi(rng);
// 	if (proto_exp_offset == 0) {
// 		return 0;
// 	}
// 	uint64_t significand = (((uint64_t)Randi(rng)) << 32) | Randi(rng) | 0x8000000000000001U;
// 	return ldexp((double)significand, -64 - __clz(proto_exp_offset));
// }

__device__ float lp_Randf(RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return ldexp((float)(Randi(rng) | 0x80000001), -32 - __clz(proto_exp_offset)); 
}

__device__ float lp_Randf_range(RandomNumberGenerator* rng, float p_from, float p_to) {
    return lp_Randf(rng)*(p_to-p_from)+p_from;
}

__device__ float lp_Randfn(RandomNumberGenerator* rng, float p_mean, float p_deviation) {
    float temp = lp_Randf(rng);
    if (temp < 0.00001f) {
        temp += 0.00001f;
    }
    return p_mean + p_deviation * (cos(6.283185307179586f * lp_Randf(rng)) * sqrt(-2.0f * log(temp)));
}


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

__device__
loadout lp_get_results(uint64_t seed) {
    RandomNumberGenerator rng = GetRNG();
    RandomNumberGenerator globalRng = GetRNG();
    Set_seed(&rng, seed);

//                                 speed fireRate multiShot wallPunch splashDamage piercing freezing infection
    int itemCategories[8] = {      0,    1,       2,        3,        4,           5,       6,       7        };
    float itemCosts[8] = {         1.0f, 2.8f,    3.3f,     1.25f,    2.0f,        2.4f,    1.5f,    2.15f    };
    //                 basic mage laser melee pointer swarm
    int charList[6] = {0,    1,   2,    3,    4,      5};

    int itemCounts[8];

    double intensity = lp_Randf_range(&rng, 0.20f, 1.0f);

    int character = charList[Randi(&rng) % 6];
    int abilityChar = charList[Randi(&rng) % 6];
    double abilityLevel = 1.0 + round(lp_run(lp_Randf(&rng), 1.5/(1.0+intensity),1.0,0.0)*6);

    double itemCount = 8.0;


    double points = 0.66 * itemCount * lp_Randf_range(&rng, 0.5, 1.5) * (1.0 + 4.0*pow(intensity, 1.5));

    double itemDistSteepness = lp_Randf_range(&rng, -0.5, 2.0);
    
    double itemDistArea = 1.0 / (1.0 + pow(2.0, 0.98*itemDistSteepness));

    Set_seed(&globalRng, Get_seed(&rng));
    Shuffle(&globalRng, itemCategories);
    
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
        int insertIdx = itemCount - 1 - Randi_range(&rng, 0, 2);
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
        int insertIdx = itemCount - 1 - Randi_range(&rng, 0, 2);
        for (int i = itemCount; i > insertIdx; --i) {
            itemCategories[i] = itemCategories[i - 1];
        }
        itemCategories[insertIdx] = 1;
    }

    double catMax = 7.0;
    // int total = 0; // why does this exist?
    for (int i = 0; i < 8; i++) {
        int item = itemCategories[i];
        double catT = (double) i / catMax;
        double cost = itemCosts[item];
        cost = 1.0 + ((cost - 1.0) / 2.5);
        double baseAmount = 0.0;

        double special = 0.0;
        if (i == 7) {
            special += 4.0 * lp_Randf_range(&rng, 0.0, pow(intensity, 2.0));
        }
        double amount = fmax(0.0, 3.0 * lp_run(catT, itemDistSteepness, 1.0, 0.0) + 3.0 * lp_clamp(lp_Randfn(&rng, 0.0, 0.15), -0.5, 0.5));
        
        itemCounts[item] = (int) lp_clamp(round(baseAmount+amount*((points/cost)/(1.0+5.0*itemDistArea))+special), 0.0, 26.0);
    }

    intensity = -0.05 + intensity*lp_lerp(0.33, 1.2, lp_smoothCorner(((double) itemCounts[2]*1.8+(double) itemCounts[1])/12.0, 1.0, 1.0, 4.0)); // TODO: smoothCorner()

    double finalT = lp_Randfn(&rng, (float) pow(intensity, 1.2), 0.05);
    double startTime = lp_clamp(lp_lerp(60.0*2.0, 60.0*20.0, finalT), 60.0*2.0, 60.0*25.0);

    lp_Randf(&rng);
    lp_Randf(&rng);
    int colorState = Randi_range(&rng, 0, 2);
    return loadout{character, abilityChar, abilityLevel, {itemCounts[0], itemCounts[1], itemCounts[2], itemCounts[3], itemCounts[4], itemCounts[5], itemCounts[6], itemCounts[7]}, startTime, colorState};
}