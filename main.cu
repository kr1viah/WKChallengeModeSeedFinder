#include <iostream>
#include <cuda_runtime.h>
#include <vector>

#define PCG_DEFAULT_INC_64 1442695040888963407ULL
#define Math_TAU 6.2831853071795864769252867666
#define CMP_EPSILON 0.00001

typedef struct { uint64_t state;  uint64_t inc; } pcg32_random_t;
typedef struct {
    int character;
    int abilityCharacter;
    double abilityLevel;
    int itemCounts[8];
    double startTime;
    int32_t colorState;
    double intensity;
    // would do rgb but cba to figure out imports/packages/whatever or to make my own colour converter
} loadout;

// __device__
// bool seenSeeds[4294967296];

// std::vector<char> characterSet = {
//     '0', '1', '2', '2', '3', '4', '5', '6', '7', '8', '9',
//     'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
// };

// helper functions

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

__device__ void intToChar(uint32_t num, char* str, int maxLength) {
    int index = 0;
    while (num > 0 && index < maxLength - 1) {
        int digit = num % 10;
        str[index++] = '0' + digit;
        num /= 10;
    }
    if (index < maxLength) {
        str[index] = '\0';
    }
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
// end of helper functions

// RandomNumberGenerator

typedef struct {
    uint64_t state;
    uint64_t inc;
    uint64_t p_inc;
    uint64_t p_seed;
    uint64_t current_seed;
} RandomNumberGenerator;

__device__ void Initialise(RandomNumberGenerator* rng) {
	rng->p_inc = 1442695040888963407;
	rng->p_seed = 12047754176567800795;
	rng->current_seed = 0;
};

__device__ uint32_t Randi(RandomNumberGenerator* rng) {
    uint64_t oldstate = rng->state;
    // printf("ab %llu\n", oldstate);
    rng->state = oldstate * 6364136223846793005ULL + (rng->inc | 1UL);
    // printf("cd %llu\n", rng->state);
    uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
    // printf("ef %u\n", xorshifted);
    uint32_t rot = oldstate >> 59u;
    // printf("gh %u\n", rot);
    // printf("ij %u\n\n", (xorshifted >> rot) | (xorshifted << ((-rot) & 31)));
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
	return (double) (Randf(rng)*(p_to - p_from) + p_from);
}

__device__ double Randfn(RandomNumberGenerator* rng, float p_mean, float p_deviation) {
    double temp = Randf(rng);
    if (temp < 0.00001) {
        temp += 0.00001;
    }
    return p_mean + p_deviation * (cos(6.2831853071795864769252867666 * static_cast<double>(Randf(rng))) * sqrt(-2.0 * log(static_cast<double>(temp))));
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
// seed function

__device__
loadout get_results(uint64_t seed) {
    RandomNumberGenerator rng;
    RandomNumberGenerator globalRng;
    Initialise(&rng);
    Initialise(&globalRng);


//                                 speed fireRate multiShot wallPunch splashDamage piercing freezing infection
    int itemCategories[8] = {      0,    1,       2,        3,        4,           5,       6,       7        };
    float itemCosts[8] = {         1.0f, 2.8f,    3.3f,     1.25f,    2.0f,        2.4f,    1.5f,    2.15f    };
    //                 basic mage laser melee pointer swarm
    int charList[6] = {0,    1,   2,    3,    4,      5};

    int itemCounts[8];

    Set_seed(&rng, seed);
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
__device__ uint32_t djb2Hash(const char *str) {
    unsigned long hash = 5381;
    int c;
    while (c = *str++) {
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    }

    return hash;
}

__device__ bool shouldStop = false;

__device__
uint32_t hash = 0;

__global__
void bruteForce() {
    int totalThreads = blockDim.x * gridDim.x;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int64_t i = idx;
    loadout loadout = get_results(0);
    for (;i < 4294967296;i = i + totalThreads) {
        loadout = get_results(i);
		if (loadout.itemCounts[0]+
			loadout.itemCounts[1]+
			loadout.itemCounts[2]+
			loadout.itemCounts[3]+
			loadout.itemCounts[4]+
			loadout.itemCounts[5]+
			loadout.itemCounts[6]+
			loadout.itemCounts[7] <= 2) {
            shouldStop = true;
            hash = i;
            // printf("%lld\n", i);
        }
        if (shouldStop) {
            return;
        }
    }
}

__global__
void cudamain() {
    RandomNumberGenerator rng;
    Initialise(&rng);
    Set_seed(&rng, 123456789);
    printf("Random number: %u\n", Randi(&rng));
    printf("Random float: %f\n", Randf(&rng));
    printf("Random integer in range (1, 10): %d\n", Randi_range(&rng, 1, 10));
    printf("Random double in range (0.0, 1.0): %f\n", Randf_range(&rng, 0.0f, 1.0f));
    printf("Random normal distribution: %f\n", Randfn(&rng, 0.0, 1.0));
}

int main() {
    // test rng
    cudamain<<<1,1>>>();
    cudaDeviceSynchronize();
}
