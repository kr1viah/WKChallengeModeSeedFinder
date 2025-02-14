package main

import (
	"math"
	"math/bits"
	"time"
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
	rng.current_seed = 0
}

func (rng *RandomNumberGenerator) randbound(bounds uint32) uint32 { // rand() with bounds
	threshold := -bounds % bounds
	for {
		r := rng.Randi()
		if r >= threshold {
			return r % bounds
		}
	}
}

func (rng *RandomNumberGenerator) randf32() float32 {
	var proto_exp_offset uint32 = rng.Randi()
	if proto_exp_offset == 0 {
		return 0
	}
	return float32(math.Ldexp(float64(rng.Randi()|0x80000001), -32-bits.LeadingZeros32(proto_exp_offset)))
}

func (rng *RandomNumberGenerator) randf64() float64 {
	var proto_exp_offset uint32 = rng.Randi()
	if proto_exp_offset == 0 {
		return 0
	}
	var significand uint64 = ((uint64(rng.Randi())) << 32) | uint64(rng.Randi()) | 0x8000000000000001
	return math.Ldexp(float64(significand), -64-bits.LeadingZeros32(proto_exp_offset))
}

func (rng *RandomNumberGenerator) Set_seed(p_seed uint64) {
	rng.current_seed = p_seed
	rng.state = uint64(0)
	rng.inc = (rng.p_inc << 1) | 1
	rng.Randi()
	rng.state += rng.current_seed
	rng.Randi()
}

func (rng *RandomNumberGenerator) Get_seed() uint64         { return rng.current_seed }
func (rng *RandomNumberGenerator) Set_state(p_state uint64) { rng.state = p_state }
func (rng *RandomNumberGenerator) Get_state() uint64        { return rng.state }

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

func (rng *RandomNumberGenerator) Randi() uint32 {
	var oldstate uint64 = rng.state
	rng.state = (oldstate * 6364136223846793005) + (rng.inc | 1)
	var xorshifted uint32 = uint32(((oldstate >> uint64(18)) ^ oldstate) >> uint64(27))
	var rot uint32 = uint32(oldstate >> uint64(59))
	return (xorshifted >> rot) | (xorshifted << ((-rot) & 31))
}

func (rng *RandomNumberGenerator) Randomize() { // required for godot, but techincally will never be used since it just randomises, can only really be used for seeing which random numbers are more likely than others
	rng.Set_seed((uint64(time.Now().Unix()+time.Now().UnixNano()/1000)*rng.state + 1442695040888963407)) // PCG_DEFAULT_INC_64
}

func (rng *RandomNumberGenerator) Globalrandf() float64 {
	return float64(float32(rng.Randi()) / float32(4294967295))
}

func (rng *RandomNumberGenerator) Globalrandf_range(p_from float64, p_to float64) float64 {
	return rng.randf64()*(p_to-p_from) + p_from
}
