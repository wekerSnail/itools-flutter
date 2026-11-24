// Package id makes random identifiers for stored records.
package id

import (
	"crypto/rand"
	"encoding/hex"
)

// New returns a random 128-bit identifier as hex.
func New() string {
	var buffer [16]byte
	if _, err := rand.Read(buffer[:]); err != nil {
		return "00000000000000000000000000000000"
	}
	return hex.EncodeToString(buffer[:])
}
