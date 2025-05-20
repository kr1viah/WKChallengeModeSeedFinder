#include "rng.cuh"

// __device__ double randf32(RandomNumberGenerator* rng) {
// 	uint32_t proto_exp_offset = Randi(rng);
// 	if (proto_exp_offset == 0) {
// 		return 0;
// 	}
// 	return (double) (float) (ldexp((double)(Randi(rng) | 0x80000001), -32 - __clzll(proto_exp_offset)));
// }

// __device__ double randf64(RandomNumberGenerator* rng) {
// 	uint32_t proto_exp_offset = Randi(rng);
// 	if (proto_exp_offset == 0) {
// 		return 0;
// 	}
// 	uint64_t significand = (((uint64_t)Randi(rng)) << 32) | Randi(rng) | 0x8000000000000001U;
// 	return ldexp((double)significand, -64 - __clz(proto_exp_offset));
// }

__device__ double Randf(RandomNumberGenerator* rng) {
	uint32_t proto_exp_offset = Randi(rng);
	if (proto_exp_offset == 0) {
		return 0;
	}
	return (double) (float) (ldexp((double)(Randi(rng) | 0x80000001), -32 - __clz(proto_exp_offset))); 
}

__device__ double Randfn(RandomNumberGenerator* rng, float p_mean, float p_deviation) {
    double temp = Randf(rng);
    if (temp < 0.00001) {
        temp += 0.00001;
    }
    return p_mean + p_deviation * (cos(6.2831853071795864769252867666 * Randf(rng)) * sqrt(-2.0 * log(temp)));
}

__device__ double Randf_range(RandomNumberGenerator* rng, float p_from, float p_to) {
    double temp = Randf(rng);
    // printf("%.15f\n", temp);
    return (double)(temp*(p_to-p_from)+p_from);
}


__forceinline__ __device__
double clamp(double m_a, double m_min, double m_max) {
	if (m_a < m_min) {
		return m_min;
	} else if (m_a > m_max) {
		return m_max;
	}
	return m_a;
}

__forceinline__ __device__
__device__ float lerp(float a, float b, float t) {
    return a + t * (b - a);
}

__forceinline__
__device__ double pinch(double v) { // function run() uses
	if (v < 0.5) {
		return -v * v;
	}
	return v * v;
}

__device__ double run(double x, double a, double b, double c) { // TorCurve.run() in windowkill
	c = pinch(c);
	x = fmaxf(0, fminf(1, x));
    const float eps = 0.00001f;
	double s = exp(a);
	double s2 = 1.0 / (s + eps);
	double t = fmaxf(0, fminf(1, b));
	double u = c;

	double res, c1, c2, c3;

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
double smoothCorner(double x, double m, double l, double s) { // TorCurve.smoothCorner in windowkill
	double s1 = pow(s/10.0, 2.0);
	return 0.5 * ((l*x + m*(1.0+s1)) - sqrt(pow(abs(l*x-m*(1.0-s1)), 2.0)+4.0*m*m*s1));
}

__device__
loadout get_results(uint64_t seed) {
    RandomNumberGenerator rng = GetRNG();
    RandomNumberGenerator globalRng = GetRNG();
    Set_seed(&rng, seed);

//                                 speed fireRate multiShot wallPunch splashDamage piercing freezing infection
    int itemCategories[8] = {      0,    1,       2,        3,        4,           5,       6,       7        };
    float itemCosts[8] = {         1.0f, 2.8f,    3.3f,     1.25f,    2.0f,        2.4f,    1.5f,    2.15f    };
    //                 basic mage laser melee pointer swarm
    int charList[6] = {0,    1,   2,    3,    4,      5};

    int itemCounts[8];

    double intensity = Randf_range(&rng, 0.20f, 1.0f);

    int character = charList[Randi(&rng) % 6];
    int abilityChar = charList[Randi(&rng) % 6];
    double abilityLevel = 1.0 + round(run(Randf(&rng), 1.5/(1.0+intensity),1.0,0.0)*6);

    double itemCount = 8.0;


    double points = 0.66 * itemCount * Randf_range(&rng, 0.5, 1.5) * (1.0 + 4.0*pow(intensity, 1.5));

    double itemDistSteepness = Randf_range(&rng, -0.5, 2.0);
    
    double itemDistArea = 1.0 / (1.0 + pow(2.0, 0.98*itemDistSteepness));

    Set_seed(&globalRng, Get_seed(&rng));
    Shuffle(&globalRng, itemCategories);
    
    if (Randf(&rng) < intensity) {
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

    if (Randf(&rng) < intensity) {
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
            special += 4.0 * Randf_range(&rng, 0.0, pow(intensity, 2.0));
        }
        double amount = fmax(0.0, 3.0 * run(catT, itemDistSteepness, 1.0, 0.0) + 3.0 * clamp(Randfn(&rng, 0.0, 0.15), -0.5, 0.5));
        
        itemCounts[item] = (int) clamp(round(baseAmount+amount*((points/cost)/(1.0+5.0*itemDistArea))+special), 0.0, 26.0);
    }

    intensity = -0.05 + intensity*lerp(0.33, 1.2, smoothCorner(((double) itemCounts[2]*1.8+(double) itemCounts[1])/12.0, 1.0, 1.0, 4.0)); // TODO: smoothCorner()

    double finalT = Randfn(&rng, (float) pow(intensity, 1.2), 0.05);
    double startTime = clamp(lerp(60.0*2.0, 60.0*20.0, finalT), 60.0*2.0, 60.0*25.0);

    Randf(&rng);
    Randf(&rng);
    int colorState = Randi_range(&rng, 0, 2);
    return loadout{character, abilityChar, abilityLevel, {itemCounts[0], itemCounts[1], itemCounts[2], itemCounts[3], itemCounts[4], itemCounts[5], itemCounts[6], itemCounts[7]}, startTime, colorState};
}
