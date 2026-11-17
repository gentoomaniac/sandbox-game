class_name AnimalSearches
extends RefCounted
## What the searches of the animals (flood fills of the ground round one, for water, feed or a
## coop; see Livestock) keep: how many an `update` may still make, how many have been made (for
## the tests), and the roosts a skip has used up.

var left := 0
var made := 0
## The roosts of each coop (by its origin) that hens settled in this skip have used up and are not
## in now, because the skip ended in the morning. Only for the length of one catch-up.
var roost_taken := {}
