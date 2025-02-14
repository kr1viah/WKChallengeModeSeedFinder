package main

import (
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

var charset = []byte("abcdefghijklmnopqrstuvwxyz012345")

func tableFiller() {
	fmt.Println(len(charset))
	var stringMap [4294967296][8]byte
	makeTable()
	file, err := os.OpenFile("table.bin", os.O_RDWR, 0644)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	fmt.Println("Filling table...")
	var start = time.Now()
	var wg sync.WaitGroup
	for i := 1; i <= threads; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			tableFillerWorker(i, &stringMap)
			fmt.Println("yeah im done", i)
		}()
	}
	wg.Wait()
	time.Sleep(time.Millisecond * 100)
	fmt.Println("Done! Took:", time.Since(start))
	fmt.Println("Writing to file...")
	start = time.Now()
	writeToFile(&stringMap)
	fmt.Println("Done! Took:", time.Since(start))
}

func writeToFile(stringMap *[4294967296][8]byte) {
	file, err := os.OpenFile("table.bin", os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		fmt.Println(err)
		os.Exit(-1)
	}
	i := 0
	var value [8]byte
	for i, value = range stringMap {
		file.WriteAt(value[:], int64(i*8))
	}
}

func tableFillerWorker(id int, stringMap *[4294967296][8]byte) {
	i := 0
	for i = id; i < 2821109907455; i = i + 1*threads {
		var toHash = generateCombinations(i)
		var hash = hash(toHash)

		stringMap[hash] = toHash
	}
	fmt.Println("Doneeeeee", i)
}
func generateCombinations(n int) [8]byte {
	var combination [8]byte

	for i := 8 - 1; i >= 0; i-- {
		combination[i] = charset[n&31]
		n >>= 5
	}

	return combination
}

// address being that entry in the table, starting from 0
//
// assumes len(whatToWrite) = 8

func makeTable() {
	file, err := os.Create("table.bin")
	check(err)
	defer file.Close()
	err = file.Truncate(34359738368) // 2^32 (amount of hashes) * 8 (bytes per string)
	check(err)
}

func check(err error) {
	if err != nil {
		panic(err)
	}
}

func hash(input [8]byte) uint32 {
	hash := uint32(5381)
	for _, b := range input {
		hash = ((hash << 5) + hash) + uint32(b) // hash * 33 + b
	}
	return hash
}
