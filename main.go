package main

import (
	"fmt"
	"math"
	"strconv"
	"time"

	"github.com/crazy3lf/colorconv"
	"github.com/dim13/djb2"
)

type upgrade int
type Char int

const ( // constants, defined in different places
	Math_TAU      = 6.2831853071795864769252867666
	charset       = "abcdefghijklmnopqrstuvwxyz0123456789"
	basic    Char = iota
	mage
	laser
	melee
	pointer
	swarm
)

const (
	speed upgrade = iota
	fireRate
	multiShot
	wallPunch
	splashDamage
	piercing
	freezing
	infection
)

var rng RandomNumberGenerator
var globalRng RandomNumberGenerator

// windowkill

type loadout struct {
	char         Char
	abilityChar  Char
	abilityLevel float64
	itemCounts   map[upgrade]int
	startTime    float64
	colorState   int32
	r            float32
	g            float32
	b            float32
}

var itemCats = []upgrade{speed, fireRate, multiShot, wallPunch, splashDamage, piercing, freezing, infection}
var itemCosts = map[upgrade]float64{
	speed:        1.0,  // speed
	fireRate:     2.8,  // firerate
	multiShot:    3.3,  // multishot
	wallPunch:    1.25, // wallpunch
	splashDamage: 2.0,  // splashdamage
	piercing:     2.4,  // piercing
	freezing:     1.5,  //freezing
	infection:    2.15, //infection
}

var charList = [6]Char{basic, mage, laser, melee, pointer, swarm}

func bruteForce() {
	var seenSeeds = make([]uint64, 67108864)
	var seenDuplicates []uint64
	var seenResults []uint32
	var i uint64 = 0
	var seed uint32 = 0
	var start = time.Now()
	for i = 0; i < 4294967600; i++ {
		seed = djb2.SumString(strconv.FormatUint(i, 10))
		index := seed / 64
		bitPos := seed % 64
		mask := uint64(1) << bitPos
		if seenSeeds[index]&mask != 0 {
			seenDuplicates = append(seenDuplicates, i)
			seenResults = append(seenResults, seed)
			fmt.Println("seen! seed:", seed, "i:", i, "hash position:", seenSeeds[seed/64]&uint64(1)<<seed%64)
			continue
		}
		_ = Get_results(uint64(seed))
		seenSeeds[seed/64] |= uint64(1) << seed % 64

	}
	fmt.Println("runtime:", time.Since(start))
	fmt.Println(seed)
	fmt.Println("duplicates:", seenDuplicates)
	fmt.Println("duplicates:", seenResults)
	fmt.Println("average runtime:", time.Since(start)/time.Duration(i))
}

func main() {
	fmt.Println(Get_results(uint64(djb2.SumString(strconv.FormatUint(53569271, 10)))))
	fmt.Println(Get_results(3823837572363))
	/* 	test seed, this seed should print:

	   	seed: 3823837572363
	   	char: laser
	   	abilityChar: mage
	   	abilityLevel: 1
	   	itemCategories: [wallPunch speed infection splashDamage multiShot fireRate piercing freezing]
	   	itemCounts: map[fireRate:6 freezing:26 infection:7 multiShot:3 piercing:9 speed:0 splashDamage:0 wallPunch:0]
	   	startTime: 641.089106798172
	   	colorState: 1
	   	color: 1 0.75686276 0.75686276 1
	*/
	// var output loadout

	var start = time.Now()
	var i uint64
	for i = 0; i < 10000000; i++ {
		Get_results(i)
	}
	fmt.Println("avg runtime:", time.Since(start)/time.Duration(i))
	fmt.Println("runtime in microseconds:", time.Since(start).Microseconds())
}

// var char Char
// var intensity float64
// var abilityChar Char
// var abilityLevel float64
// var itemCount float64
// var points float64
// var itemCategories = make([]upgrade, len(itemCats))
// var itemDistSteepness float64
// var itemDistArea float64
// var total int
// var catMax float64
// var finalT float64
// var startTime float64
// var itemCounts = make(map[upgrade]int)
// var cost float64
// var item upgrade
// var catT float64
// var rInt, gInt, bInt uint8

var itemCategories = make([]upgrade, len(itemCats))

func Get_results(seed uint64) loadout {
	copy(itemCategories, itemCats)
	rng.Initialise()
	globalRng.Initialise()

	rng.Set_seed(seed)

	// intensity determines basis for other rolls
	var intensity = rng.Randf_range(0.20, 1.0)

	var char = charList[int(rng.Randi())%len(charList)]
	var abilityChar = charList[int(rng.Randi())%len(charList)]
	var abilityLevel = 1.0 + math.Round(run(rng.Randf(), 1.5/(1.0+intensity), 1.0, 0.0)*6)

	var itemCount = float64(len(itemCategories))
	// points determine item layout
	var points = 0.66 * itemCount * rng.Randf_range(0.5, 1.5) * (1.0 + 4.0*math.Pow(intensity, 1.5))

	var itemDistSteepness = rng.Randf_range(-0.5, 2.0)
	var itemDistArea = 1.0 / (1.0 + math.Pow(2, 0.98*itemDistSteepness))

	globalRng.Set_seed(rng.Get_seed())
	globalRng.shuffle(&itemCategories)

	// chance to move offensive upgrades closer to end if not already

	if rng.Randf() < intensity {
		multishotIdx := -1
		for i, category := range itemCategories {
			if category == multiShot {
				multishotIdx = i
				break
			}
		}

		if multishotIdx != -1 {
			itemCategories = append(itemCategories[:multishotIdx], itemCategories[multishotIdx+1:]...)
		}
		insertIdx := int32(itemCount) - 1 - rng.Randi_range(0, 2)
		itemCategories = append(itemCategories[:insertIdx], append([]upgrade{multiShot}, itemCategories[insertIdx:]...)...)
	}

	if rng.Randf() < intensity {
		fireRateIdx := -1
		for i, category := range itemCategories {
			if category == fireRate {
				fireRateIdx = i
				break
			}
		}

		if fireRateIdx != -1 {
			itemCategories = append(itemCategories[:fireRateIdx], itemCategories[fireRateIdx+1:]...)
		}
		insertIdx := int32(itemCount) - 1 - rng.Randi_range(0, 2)
		itemCategories = append(itemCategories[:insertIdx], append([]upgrade{fireRate}, itemCategories[insertIdx:]...)...)
	}

	var itemCounts = make(map[upgrade]int)
	var catMax = float64(itemCount - 1)
	var total = 0
	for i := 0; i < int(itemCount); i++ {
		var item = itemCategories[i]
		var catT = float64(i) / catMax
		var cost = itemCosts[item]
		cost = 1.0 + ((cost - 1.0) / 2.5)
		baseAmount := 0.0

		var special = 0.0
		if i == int(itemCount)-1 {
			special += 4.0 * rng.Randf_range(0.0, float32(math.Pow(intensity, 2.0)))
		}
		amount := math.Max(0.0, 3.0*run(catT, itemDistSteepness, 1.0, 0.0)+3.0*clamp(rng.Randfn(0.0, 0.15), -0.5, 0.5))
		itemCounts[item] = int(clamp(math.Round(baseAmount+amount*((points/cost)/(1.0+5.0*itemDistArea))+special), 0.0, 26.0))
		total += itemCounts[item]
	}

	// balance for offensive upgrades
	intensity = -0.05 + intensity*lerp(0.33, 1.2, smoothCorner((float64(itemCounts[multiShot])*1.8+float64(itemCounts[fireRate]))/12.0, 1.0, 1.0, 4.0))

	var finalT = rng.Randfn(float32(math.Pow(intensity, 1.2)), 0.05)
	var startTime = clamp(lerp(60.0*2.0, 60.0*20.0, finalT), 60.0*2.0, 60.0*25.0)

	var rInt, gInt, bInt, _ = colorconv.HSVToRGB(rng.Randf(), rng.Randf(), float64(1.0))
	r, g, b = float32(rInt)/255, float32(gInt)/255, float32(bInt)/255

	colorState = rng.Randi_range(0, 2)
	return (loadout{char, abilityChar, abilityLevel, itemCounts, startTime, colorState, r, g, b})
}

var colorState int32
var r, g, b float32

// helper functions

func pinch(v float64) float64 { // function run() uses
	if v < 0.5 {
		return -v * v
	}
	return v * v
}

func run(x, a, b, c float64) float64 { // TorCurve.run() in godot
	c = pinch(c)
	x = math.Max(0, math.Min(1, x))

	const eps = 0.00001
	s := math.Exp(a)
	s2 := 1.0 / (s + eps)
	t := math.Max(0, math.Min(1, b))
	u := c

	var res, c1, c2, c3 float64

	if x < t {
		c1 = (t * x) / (x + s*(t-x) + eps)
		c2 = t - math.Pow(1/(t+eps), s2-1)*math.Pow(math.Abs(x-t), s2)
		c3 = math.Pow(1/(t+eps), s-1) * math.Pow(x, s)
	} else {
		c1 = (1-t)*(x-1)/(1-x-s*(t-x)+eps) + 1
		c2 = math.Pow(1/((1-t)+eps), s2-1)*math.Pow(math.Abs(x-t), s2) + t
		c3 = 1 - math.Pow(1/((1-t)+eps), s-1)*math.Pow(1-x, s)
	}

	if u <= 0 {
		res = (-u)*c2 + (1+u)*c1
	} else {
		res = (u)*c3 + (1-u)*c1
	}

	return res
}

func smoothCorner(x, m, l, s float64) float64 { // TorCurve.smoothCorner in godot
	s1 := math.Pow(s/10.0, 2.0)
	return 0.5 * ((l*x + m*(1.0+s1)) - math.Sqrt(math.Pow(math.Abs(l*x-m*(1.0-s1)), 2.0)+4.0*m*m*s1))
}

func lerp(a, b, t float64) float64 {
	return a + t*(b-a)
}

func clamp(m_a, m_min, m_max float64) float64 {
	if m_a < m_min {
		return m_min
	} else if m_a > m_max {
		return m_max
	}
	return m_a
}

func (rng2 RandomNumberGenerator) shuffle(arr *[]upgrade) {
	n := len((*arr))
	if n <= 1 {
		return
	}
	for i := n - 1; i > 0; i-- {
		j := rng2.randbound(uint32(i + 1))
		(*arr)[i], (*arr)[j] = (*arr)[j], (*arr)[i]
	}
}
