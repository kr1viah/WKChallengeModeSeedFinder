package main

import (
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/dim13/djb2"
)

const Math_TAU = 6.2831853071795864769252867666

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

type upgrade int
type Char int

var itemCats = []upgrade{speed, fireRate, multiShot, wallPunch, splashDamage, piercing, freezing, infection}

var itemCosts = map[upgrade]float64{
	speed:        1.0,
	fireRate:     2.8,
	multiShot:    3.3,
	wallPunch:    1.25,
	splashDamage: 2.0,
	piercing:     2.4,
	freezing:     1.5,
	infection:    2.15,
}

var charList = [6]Char{basic, mage, laser, melee, pointer, swarm}

var seenSeeds = make([]bool, 4294967296)

var characterSet = []string{
	"0", "1", "2", "2", "3", "4", "5", "6", "7", "8", "9",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
} // can remove any of these, windowkill will not accept capital letters or any others not from these

const (
	basic Char = iota
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

var shouldStop = false

func bruteForce(id int, wg *sync.WaitGroup, prefix string) {
	if shouldStop {
		return
	}
	if seedsChecked > seedsToCheck {
		shouldStop = true
		return
	}
	seed := djb2.SumString(prefix)
	seedsChecked++
	if seenSeeds[seed] {
		return
	}
	seenSeeds[seed] = true
	var loadout = Get_results(uint64(seed))
	if loadout.abilityChar == mage && loadout.char == melee && loadout.itemCounts[multiShot] > 10 && loadout.itemCounts[fireRate] > 20 && loadout.itemCounts[speed] > 10 && loadout.abilityLevel > 4 && int(loadout.startTime)%60 > 50 {
		var foundMiasma = false
		var foundOrbArray = false
		var bossOrder = Get_bosses(uint64(seed))
		for i := 0; i < 4; i++ {
			if bossOrder[i] == "BossGermSource" {
				foundMiasma = true
				continue
			}
			if bossOrder[i] == "BossOrb" {
				foundOrbArray = true
				continue
			}
		}
		if foundMiasma && foundOrbArray {
			shouldStop = true
			winningSeed = prefix
		}
	}
	if len(prefix) == 14 {
		return
	}
	for _, char := range characterSet {
		bruteForce(id, wg, prefix+char)
	}
}

var winningSeed string = ""

var seedsChecked = 0
var seedsToCheck = 10294997296
var threads = 8
var prefix = ""

func main() {
	var wg = sync.WaitGroup{}
	wg.Add(threads)

	var start = time.Now()

	for t := 0; t < threads; t++ {
		if threads > len(characterSet) {
			go func() {
				bruteForce(t, &wg, prefix+getCombination(characterSet, t))
				wg.Done()
			}()
			continue
		}
		go func() {
			bruteForce(t, &wg, prefix+characterSet[t])
			wg.Done()
		}()
	}
	wg.Wait()
	if winningSeed != prefix {
		fmt.Println("Average runtime:", time.Since(start)/time.Duration(seedsChecked))
		fmt.Println("Runtime:", time.Since(start))
		fmt.Println("Seeds checked:", seedsChecked)
		Print_results(Get_results(uint64(djb2.SumString(winningSeed))))
		fmt.Println("Boss order:", Get_bosses(uint64(djb2.SumString(winningSeed))))
	} else {
		fmt.Println("Seed not found!")
	}

	// Print_results(Get_results(uint64(3823837572363)))
	/* 	test seed:

	   	seed: 3823837572363
	   	char: laser (2)
	   	abilityChar: mage (1)
	   	abilityLevel: 1
	   	itemCounts: map[fireRate:6 freezing:26 infection:7 multiShot:3 piercing:9 speed:0 splashDamage:0 wallPunch:0] (map[0:0 1:6 2:3 3:0 4:0 5:9 6:26 7:7])
	   	startTime: 641.089106798172
	   	colorState: 1
	   	color: 1 0.75686276 0.75686276 1
	*/
}

func Print_results(loadout loadout) {
	fmt.Println("Seed: ", winningSeed)
	switch loadout.char {
	case basic:
		fmt.Println("Character: epsilon")
	case mage:
		fmt.Println("Character: nyx")
	case laser:

		fmt.Println("Character: bastion")
	case melee:
		fmt.Println("Character: zephyr")
	case pointer:
		fmt.Println("Character: :)")
	case swarm:
		fmt.Println("Character: mebo")
	}
	switch loadout.abilityChar {
	case basic:
		fmt.Println("Ability: bellow")
	case mage:
		fmt.Println("Ability: halt")
	case laser:
		fmt.Println("Ability: torrent")
	case melee:
		fmt.Println("Ability: endure")
	case pointer:
		fmt.Println("Ability: detach")
	case swarm:
		fmt.Println("Ability: propagate")
	}
	fmt.Println("Ability level:", loadout.abilityLevel)
	for i := 0; i <= 8; i++ {
		switch i {
		case 0:
			fmt.Println("Level of speed:", loadout.itemCounts[upgrade(i)])
		case 1:
			fmt.Println("Level of fire rate:", loadout.itemCounts[upgrade(i)])
		case 2:
			fmt.Println("Level of multishot:", loadout.itemCounts[upgrade(i)])
		case 3:
			fmt.Println("Level of wall punch:", loadout.itemCounts[upgrade(i)])
		case 4:
			fmt.Println("Level of splash damage:", loadout.itemCounts[upgrade(i)])
		case 5:
			fmt.Println("Level of piercing:", loadout.itemCounts[upgrade(i)])
		case 6:
			fmt.Println("Level of freezing:", loadout.itemCounts[upgrade(i)])
		case 7:
			fmt.Println("Level of infection:", loadout.itemCounts[upgrade(i)])
		}
	}
	fmt.Println("Starting time:", time.Second*time.Duration(loadout.startTime))
	switch loadout.colorState {
	case 0:
		fmt.Println("Color mode: outline")
	case 1:
		fmt.Println("Color mode: outline, white filling")
	case 2:
		fmt.Println("Color mode: filling, white outline")
	}
}

func Get_bosses(seed uint64) []string {
	var rng RandomNumberGenerator
	rng.Set_seed(seed)
	var bossQueue = []string{}
	var germBuildup = rng.Randf_range(-1.0, 2.0)
	var germsSpawned = 0
	for i := 0; i < 10; i++ {
		var addQueue = []string{"BossSpike", "BossSnake", "BossSlime", "BossSpike", "BossSnake", "BossSlime", "BossVirus"}
		if rng.Randf() < 0.33 {
			addQueue = append(addQueue, "BossOrb")
		}
		germBuildup += 0.5 * float64(len(addQueue))
		if germBuildup > 5.0*(1.0+1.0*float64(germsSpawned)) {
			germBuildup = rng.Randf_range(-2.0, 2.0)
			germsSpawned += 1
			addQueue = append(addQueue, "BossGermSource")
		}
		rng.shuffleString(addQueue)
		bossQueue = append(bossQueue, addQueue...)
	}
	return bossQueue
}

func Get_results(seed uint64) loadout {
	var rng RandomNumberGenerator
	var globalRng RandomNumberGenerator
	var itemCategories = make([]upgrade, len(itemCats))
	var itemCounts = make(map[upgrade]int)
	copy(itemCategories, itemCats)
	rng.Initialise()
	globalRng.Initialise()

	rng.Set_seed(seed)

	// intensity determines basis for other rolls
	var intensity = rng.Randf_range(0.20, 1.0)

	var char = charList[int(rng.Randi())%6]
	var abilityChar = charList[int(rng.Randi())%6]
	var abilityLevel = 1.0 + math.Round(run(rng.Randf(), 1.5/(1.0+intensity), 1.0, 0.0)*6)

	var itemCount = float64(len(itemCategories))
	// points determine item layout
	var points = 0.66 * itemCount * rng.Randf_range(0.5, 1.5) * (1.0 + 4.0*math.Pow(intensity, 1.5))

	var itemDistSteepness = rng.Randf_range(-0.5, 2.0)
	var itemDistArea = 1.0 / (1.0 + math.Pow(2, 0.98*itemDistSteepness))

	globalRng.Set_seed(rng.Get_seed())
	globalRng.shuffle(itemCategories)

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

	itemCounts = make(map[upgrade]int)
	var catMax = 7.0
	var total = 0
	for i := 0; i < 8; i++ {
		var item = itemCategories[i]
		var catT = float64(i) / catMax
		var cost = itemCosts[item]
		cost = 1.0 + ((cost - 1.0) / 2.5)
		baseAmount := 0.0

		var special = 0.0
		if i == 7 {
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

	// var rInt, gInt, bInt, _ = colorconv.HSVToRGB(rng.Randf(), rng.Randf(), float64(1.0)) // im fairly certain this is not accurate in the slightest
	// var r, g, b = float32(rInt) / 255, float32(gInt) / 255, float32(bInt) / 255
	rng.Randf()
	rng.Randf()
	var colorState = rng.Randi_range(0, 2)
	return (loadout{char, abilityChar, abilityLevel, itemCounts, startTime, colorState, 0, 0, 0})
}

// var colorState int32
// var r, g, b float32

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

func (rng2 RandomNumberGenerator) shuffle(arr []upgrade) {
	n := len(arr)
	if n <= 1 {
		return
	}
	for i := n - 1; i > 0; i-- {
		j := rng2.randbound(uint32(i + 1))
		arr[i], arr[j] = arr[j], arr[i]
	}
}

func getCombination(characterSet []string, index int) string {
	var base = len(characterSet)
	var combination = ""
	for index > 0 {
		combination = characterSet[index%base] + combination
		index /= base
	}
	return combination
}

func (rng2 RandomNumberGenerator) shuffleString(arr []string) {
	n := len(arr)
	if n <= 1 {
		return
	}
	for i := n - 1; i > 0; i-- {
		j := rng2.randbound(uint32(i + 1))
		arr[i], arr[j] = arr[j], arr[i]
	}
}
