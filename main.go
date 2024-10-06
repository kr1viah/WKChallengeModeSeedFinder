package main

import (
	"fmt"
	"math"

	"github.com/crazy3lf/colorconv"
	"github.com/dim13/djb2"
)

const ( // constants, defined in different
	Math_TAU           = 6.2831853071795864769252867666
	PCG_DEFAULT_INC_64 = 1442695040888963407
)

var itemCategories = []string{"speed", "fireRate", "multiShot", "wallPunch", "splashDamage", "piercing", "freezing", "infection"}

var itemCosts = map[string]float64{
	"speed":        1.0,
	"fireRate":     2.8,
	"multiShot":    3.3,
	"wallPunch":    1.25,
	"splashDamage": 2.0,
	"piercing":     2.4,
	"freezing":     1.5,
	"infection":    2.15,
}

var charList = [6]string{"basic", "mage", "laser", "melee", "pointer", "swarm"}

var rng2 RandomNumberGenerator // rename to rng maybe?

// windowkill

func main() {
	rng2.Initialise()

	fmt.Println(djb2.SumString("Ab"))
	rng2.Set_seed(3823837572363)

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

	// fmt.Println("state:", get_state())
	fmt.Println("seed:", rng2.Get_seed())

	// intensity determines basis for other rolls
	var intensity = rng2.Randf_range(0.20, 1.0)

	var char = charList[int(rng2.Randi())%len(charList)]
	var abilityChar = charList[int(rng2.Randi())%len(charList)]
	var abilityLevel = 1.0 + math.Round(run(rng2.Randf(), 1.5/(1.0+intensity), 1.0, 0.0)*6)

	var itemCount float64 = float64(len(itemCategories))
	// points determine item layout
	var points = 0.66 * itemCount * rng2.Randf_range(0.5, 1.5) * (1.0 + 4.0*math.Pow(intensity, 1.5))

	var itemDistSteepness = rng2.Randf_range(-0.5, 2.0)
	var itemDistArea = 1.0 / (1.0 + math.Pow(2, 0.98*itemDistSteepness))

	// windowkill uses the ""global"" randomness and shuffle()
	// instead of that this saves the state (and inc)
	// then sets the seed to the current seed (because setting the current seed advances the state 2 times im pretty sure, although doesnt really matter)
	// and after calling shuffle() set the state (and inc) back to what it was before directly

	var oldstate = rng2.state
	var oldInc = rng2.inc

	rng2.Set_seed(rng2.Get_seed())
	shuffle(itemCategories)

	rng2.inc = oldInc
	rng2.state = oldstate

	// chance to move offensive upgrades closer to end if not already

	if rng2.Randf() < intensity {
		multishotIdx := -1
		for i, category := range itemCategories {
			if category == "multiShot" {
				multishotIdx = i
				break
			}
		}

		if multishotIdx != -1 {
			itemCategories = append(itemCategories[:multishotIdx], itemCategories[multishotIdx+1:]...)
		}
		insertIdx := int32(itemCount) - 1 - rng2.Randi_range(0, 2)
		itemCategories = append(itemCategories[:insertIdx], append([]string{"multiShot"}, itemCategories[insertIdx:]...)...)
	}

	if rng2.Randf() < intensity {
		fireRateIdx := -1
		for i, category := range itemCategories {
			if category == "fireRate" {
				fireRateIdx = i
				break
			}
		}

		if fireRateIdx != -1 {
			itemCategories = append(itemCategories[:fireRateIdx], itemCategories[fireRateIdx+1:]...)
		}
		insertIdx := int32(itemCount) - 1 - rng2.Randi_range(0, 2)
		itemCategories = append(itemCategories[:insertIdx], append([]string{"fireRate"}, itemCategories[insertIdx:]...)...)
	}

	var itemCounts = make(map[string]int)
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
			special += 4.0 * rng2.Randf_range(0.0, float32(math.Pow(intensity, 2.0)))
		}
		amount := math.Max(0.0, 3.0*run(catT, itemDistSteepness, 1.0, 0.0)+3.0*clamp(rng2.Randfn(0.0, 0.15), -0.5, 0.5))
		itemCounts[item] = int(clamp(math.Round(baseAmount+amount*((points/cost)/(1.0+5.0*itemDistArea))+special), 0.0, 26.0))
		total += itemCounts[item]
	}

	// balance for offensive upgrades
	intensity = -0.05 + intensity*lerp(0.33, 1.2, smoothCorner((float64(itemCounts["multiShot"])*1.8+float64(itemCounts["fireRate"]))/12.0, 1.0, 1.0, 4.0))

	var finalT = rng2.Randfn(float32(math.Pow(intensity, 1.2)), 0.05)
	var startTime = clamp(lerp(60.0*2.0, 60.0*20.0, finalT), 60.0*2.0, 60.0*25.0)

	var r, g, b, _ = colorconv.HSVToRGB(rng2.Randf(), rng2.Randf(), float64(1.0)) // color
	var colorState = rng2.Randi_range(0, 2)

	fmt.Println("char:", char)
	fmt.Println("abilityChar:", abilityChar)
	fmt.Println("abilityLevel:", abilityLevel)
	fmt.Println("itemCategories:", itemCategories)
	fmt.Println("itemCounts:", itemCounts)
	fmt.Println("startTime:", startTime)
	fmt.Println("colorState:", colorState)
	fmt.Println("color:", float32(r)/255, float32(g)/255, float32(b)/255, 1.0) // figure out how to pack r g and b into a single `color` variable
}

//
//
//
//
//
//
//
//
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

func shuffle(arr []string) {
	n := len(arr)
	if n <= 1 {
		return
	}
	for i := n - 1; i > 0; i-- {
		j := rng2.randbound(uint32(i + 1))
		arr[i], arr[j] = arr[j], arr[i]
	}
}
