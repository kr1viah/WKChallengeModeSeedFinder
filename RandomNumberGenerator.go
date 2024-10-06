package main

import (
	"math"
	"math/bits"
)

// pcg.h

type RandomNumberGenerator struct {
	state        uint64
	inc          uint64
	p_inc        uint64
	p_seed       uint64 // required for godot, it's the default seed it uses for when no seed is set
	current_seed uint64
}

func (rng *RandomNumberGenerator) Initialise() {
	rng.p_inc = 1442695040888963407
	rng.p_seed = 12047754176567800795
}

// pcg.cpp

// func (rng *rng) pcg32_random_r() uint32 {

// }

// func (rng *RandomNumberGenerator) pcg32_srandom_r(initstate uint64, initseq uint64) {
// 	rng.state = uint64(0)
// 	rng.inc = (initseq << 1) | 1
// 	rng.Randi()
// 	rng.state += initstate
// 	rng.Randi()
// }

// func (rng *RandomNumberGenerator) pcg32_boundedrand_r(bound uint32) uint32 {
// 	threshold := -bound % bound
// 	for {
// 		r := rng.Randi()
// 		if r >= threshold {
// 			return r % bound
// 		}
// 	}
// }

// random_pcg.cpp

// func (rng *RandomNumberGenerator) randomf32(p_from float32, p_to float32) float32 { // `random()` float version
// 	return rng.randf32()*(p_to-p_from) + p_from
// }

// func (rng *RandomNumberGenerator) randomi(p_from int, p_to int) int { // `random()` int version
// 	if p_from == p_to {
// 		return p_from
// 	}
// 	bounds := uint32(int(math.Abs(float64(p_from-p_to))) + 1)
// 	randomValue := int(rng.randbound(bounds))
// 	if p_from < p_to {
// 		return p_from + randomValue
// 	}
// 	return p_to + randomValue
// }

// random_pcg.h

func (rng *RandomNumberGenerator) randbound(bounds uint32) uint32 { // rand() with bounds
	threshold := -bounds % bounds
	for {
		r := rng.Randi()
		if r >= threshold {
			return r % bounds
		}
	}
}

func (rng *RandomNumberGenerator) Randi() uint32 { // normal rand
	var oldstate uint64 = rng.state
	rng.state = (oldstate * 6364136223846793005) + (rng.inc | 1)
	var xorshifted uint32 = uint32(((oldstate >> uint64(18)) ^ oldstate) >> uint64(27))
	var rot uint32 = uint32(oldstate >> uint64(59))
	return (xorshifted >> rot) | (xorshifted << ((-rot) & 31))
}

func (rng *RandomNumberGenerator) randf32() float32 {
	var proto_exp_offset uint32 = rng.Randi()
	if proto_exp_offset == 0 {
		return 0
	}
	return float32(math.Ldexp(float64(rng.Randi()|0x80000001), -32-bits.LeadingZeros32(proto_exp_offset)))
}

// random_number_generator.h

func (rng *RandomNumberGenerator) Set_seed(p_seed uint64) {
	rng.current_seed = p_seed
	// rng.pcg32_srandom_r(rng.current_seed, rng.p_inc)
	rng.state = uint64(0)
	rng.inc = (rng.p_inc << 1) | 1
	rng.Randi()
	rng.state += rng.current_seed
	rng.Randi()
}
func (rng *RandomNumberGenerator) Get_seed() uint64 { return rng.current_seed }

// func (rng *rng) Randi() uint32 {
// 	return rng.rand()
// }

func (rng *RandomNumberGenerator) Randf() float64 {
	var proto_exp_offset uint32 = rng.Randi()
	if proto_exp_offset == 0 {
		return 0
	}
	return float64(float32(math.Ldexp(float64(rng.Randi()|0x80000001), -32-bits.LeadingZeros32(proto_exp_offset)))) // conversion to float32 and back to float64 is to round to the nearest floqata32
}

func (rng *RandomNumberGenerator) Randf_range(p_from float32, p_to float32) float64 {
	return float64(rng.randf32()*(p_to-p_from) + p_from)
}

func (rng *RandomNumberGenerator) Randfn(p_mean float32, p_deviation float32) float64 {
	var temp float32 = rng.randf32()
	if temp < 0.00001 {
		temp += 0.00001 // this is what CMP_EPSILON is defined as
	}
	return float64(p_mean + p_deviation*(float32(math.Cos(6.2831853071795864769252867666*float64(rng.randf32()))*math.Sqrt(-2.0*math.Log(float64(temp)))))) // math_tau sneaked in
}

func (rng *RandomNumberGenerator) Randi_range(p_from int32, p_to int32) int32 {
	// return int32(rng.randomi(p_from, p_to))
	if p_from == p_to {
		return p_from
	}
	bounds := uint32(int32(math.Abs(float64(p_from-p_to))) + 1)
	randomValue := int32(rng.randbound(bounds))
	if p_from < p_to {
		return p_from + randomValue
	}
	return p_to + randomValue
}
