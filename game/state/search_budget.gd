class_name SearchBudget
extends RefCounted
## How many searches (flood fills of the ground round an animal, see Livestock) one `update` may
## still make, and how many have been made, for the tests.

var left := 0
var made := 0
