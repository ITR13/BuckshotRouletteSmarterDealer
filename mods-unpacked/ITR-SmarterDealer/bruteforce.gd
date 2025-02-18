extends Node

# Constants
const HANDCUFF_NONE = 0
const HANDCUFF_FREENEXT = 1
const HANDCUFF_CUFFED = 2

const MAGNIFYING_NONE = 0
const MAGNIFYING_LIVE = 1
const MAGNIFYING_BLANK = 2

const OPTION_DEALER_RANDOM = -2
const OPTION_NO_DEALER_CHOICE = -1
const OPTION_NONE = 0
const OPTION_SHOOT_SELF = 1
const OPTION_SHOOT_OTHER = 2
const OPTION_MAGNIFY = 3
const OPTION_CIGARETTES = 4
const OPTION_BEER = 5
const OPTION_HANDCUFFS = 6
const OPTION_HANDSAW = 7
const OPTION_MEDICINE = 8
const OPTION_INVERTER = 9
const OPTION_BURNER = 10
const OPTION_ADRENALINE = 11

const FREESLOTS_INDEX = 12

const ROUNDTYPE_NORMAL = 0
const ROUNDTYPE_WIRECUT = 1
const ROUNDTYPE_DOUBLEORNOTHING = 2

const itemScoreArray = [
	[], [], [], # Skip none, shoot self, shoot other
	# 0    1    2    3     4     5     6     7    8
	[ 0.0, 1.5, 3.0, 4.0 , 4.5 , 5.0 , 6.5 , 6.8, 7.0  ], # Magnify
	[ 0.0, 0.5, 1.0, 1.2 , 1.2 , 1.2 , 1.2 , 1.2, 1.2  ], # Cigarette
	[ 0.0, 1.0, 2.0, 3.0 , 3.5 , 4.0 , 4.25, 4.5, 4.75 ], # Beer
	[ 0.0, 1.2, 2.0, 2.5 , 2.6 , 2.7 , 2.8 , 2.9, 3.0  ], # Handcuff
	[ 0.0, 1.5, 2.6, 3.1 , 3.5 , 3.6 , 3.7 , 3.8, 3.9  ], # Handsaw
	[ 0.0, 0.3, 0.6, 0.7 , 0.8 , 0.9 , 0.95, 1.0, 1.05 ], # Expired Medicine
	[ 0.0, 1.2, 2.4, 3.3 , 3.7 , 4.1 , 4.5 , 4.9, 5.4  ], # Inverter
	[ 0.0, 1.4, 2.8, 2.75, 2.7 , 2.65, 2.6 , 2.5, 2.4  ], # Burner Phone
	[ 0.0, 2.0, 4.0, 5.5 , 7.0 , 8.0 , 9.0 , 9.5, 10.0 ], # Adrenaline
	[ 0.0, 1.0, 2.0, 2.75, 3.25, 3.5 , 3.5 , 3.5, 3.5, ], # FreeSlots
]

class Result:
	var option: int
	var deathChance: Array[float]
	var healthScore: Array[float]
	var itemScore: Array[float]
	var depth: float # Expected number of actions taken before the round ends.

	@warning_ignore("shadowed_variable")
	func _init(option: int, deathChance, healthScore, itemScore, depth: float = 0.0):
		self.option = option
		self.deathChance.assign(deathChance)
		self.healthScore.assign(healthScore)
		self.itemScore.assign(itemScore)
		self.depth = depth

	func mult(multiplier: float):
		return Result.new(
			self.option,
			[multiplier*self.deathChance[0], multiplier*self.deathChance[1]],
			[multiplier*self.healthScore[0], multiplier*self.healthScore[1]],
			[multiplier*self.itemScore[0], multiplier*self.itemScore[1]],
			multiplier*self.depth
		)

	func mutAdd(other: Result):
		self.deathChance[0] += other.deathChance[0]
		self.deathChance[1] += other.deathChance[1]
		self.healthScore[0] += other.healthScore[0]
		self.healthScore[1] += other.healthScore[1]
		self.itemScore[0] += other.itemScore[0]
		self.itemScore[1] += other.itemScore[1]
		self.depth += other.depth

	func clone()->Result:
		return self.mult(1)

	func _to_string():
		return "Option %s %s %s %s %s" % [
			self.option, self.deathChance, self.healthScore, self.itemScore, self.depth
		]

# Player class
class BruteforcePlayer:
	var player_index: int

	var max_health: int
	var health: int

	var max_magnify: int
	var max_cigarettes: int
	var max_beer: int
	var max_handcuffs: int
	var max_handsaw: int
	var max_medicine: int
	var max_inverter: int
	var max_burner: int
	var max_adrenaline: int

	var magnify: int
	var cigarettes: int
	var beer: int
	var handcuffs: int
	var handsaw: int
	var medicine: int
	var inverter: int
	var burner: int
	var adrenaline: int

	@warning_ignore("shadowed_variable")
	func _init(player_index: int, max_health: int, max_magnify: int, max_cigarettes: int, max_beer: int, max_handcuffs: int, max_handsaw: int, max_medicine: int, max_inverter: int, max_burner: int, max_adrenaline: int):
		self.player_index = player_index

		self.max_health = max_health
		self.health = max_health

		self.max_magnify = max_magnify
		self.max_cigarettes = max_cigarettes
		self.max_beer = max_beer
		self.max_handcuffs = max_handcuffs
		self.max_handsaw = max_handsaw
		self.max_medicine = max_medicine
		self.max_inverter = max_inverter
		self.max_burner = max_burner
		self.max_adrenaline = max_adrenaline

		self.magnify = max_magnify
		self.cigarettes = max_cigarettes
		self.beer = max_beer
		self.handcuffs = max_handcuffs
		self.handsaw = max_handsaw
		self.medicine = max_medicine
		self.inverter = max_inverter
		self.burner = max_burner
		self.adrenaline = max_adrenaline

	func do_hash(num: int)->int:
		num *= 2
		num += self.player_index

		num *= (self.max_health+1)
		num += self.health

		num *= (self.max_magnify+1)
		num += self.magnify

		num *= (self.max_cigarettes+1)
		num += self.cigarettes

		num *= (self.max_beer+1)
		num += self.beer

		num *= (self.max_handcuffs+1)
		num += self.handcuffs

		num *= (self.max_handsaw+1)
		num += self.handsaw

		num *= (self.max_medicine+1)
		num += self.medicine

		num *= (self.max_inverter+1)
		num += self.inverter

		num *= (self.max_burner+1)
		num += self.burner

		num *= (self.max_adrenaline+1)
		num += self.adrenaline

		return num

	func use(item, count=1)->BruteforcePlayer:
		var new_player = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine, self.max_inverter, self.max_burner, self.max_adrenaline)

		# Copy attributes to the new instance
		var found = false
		for attribute in self.get_property_list():
			if not found and attribute["name"] == item:
				found = true
				new_player.set(attribute["name"], self.get(attribute["name"]) - count)
			else:
				new_player.set(attribute["name"], self.get(attribute["name"]))

		if not found and item:
			print("Invalid item:", item)

		return new_player

	func createSubplayer(other: BruteforcePlayer)->BruteforcePlayer:
		if other.player_index != self.player_index:
			return null
		if other.max_health != self.max_health:
			return null
		if other.magnify > self.max_magnify or other.cigarettes > self.max_cigarettes or other.beer > self.max_beer or other.handcuffs > self.max_handcuffs or other.handsaw > self.max_handsaw or other.medicine > self.max_medicine or other.inverter > self.max_inverter or other.burner > self.max_burner or other.max_adrenaline > self.max_adrenaline:
			return null

		var copy = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine, self.max_inverter, self.max_burner, self.max_adrenaline)
		copy.health = other.health
		copy.magnify = other.magnify
		copy.cigarettes = other.cigarettes
		copy.beer = other.beer
		copy.handcuffs = other.handcuffs
		copy.handsaw = other.handsaw
		copy.medicine = other.medicine
		copy.inverter = other.inverter
		copy.burner = other.burner
		copy.adrenaline = other.adrenaline
		return copy

	func sum_items()->float:
		var totalItems = self.count_items()
		var freeSlots = 8 - totalItems

		var score: float = 0
		score += itemScoreArray[OPTION_MAGNIFY][self.magnify]
		score += itemScoreArray[OPTION_BEER][self.beer]
		score += itemScoreArray[OPTION_CIGARETTES][self.cigarettes]
		score += itemScoreArray[OPTION_HANDSAW][self.handsaw]
		score += itemScoreArray[OPTION_HANDCUFFS][self.handcuffs]
		score += itemScoreArray[OPTION_MEDICINE][self.medicine]
		score += itemScoreArray[OPTION_INVERTER][self.inverter]
		score += itemScoreArray[OPTION_BURNER][self.burner]
		score += itemScoreArray[OPTION_ADRENALINE][self.adrenaline]
		score += itemScoreArray[FREESLOTS_INDEX][freeSlots]

		return score

	func count_items()->int:
		return self.magnify + self.beer + self.cigarettes + self.handsaw + self.handcuffs + self.medicine + self.inverter + self.burner + self.adrenaline

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		var dict = {
			"player_index": self.player_index,
			"health": self.health,
			"max_health": self.max_health,
			"magnify": self.magnify,
			"max_magnify": self.max_magnify,
			"cigarettes": self.cigarettes,
			"max_cigarettes": self.max_cigarettes,
			"beer": self.beer,
			"max_beer": self.max_beer,
			"handcuffs": self.handcuffs,
			"max_handcuffs": self.max_handcuffs,
			"handsaw": self.handsaw,
			"max_handsaw": self.max_handsaw,
			"medicine": self.medicine,
			"max_medicine": self.max_medicine,
			"inverter": self.inverter,
			"max_inverter": self.max_inverter,
			"burner": self.burner,
			"max_burner": self.max_burner,
			"adrenaline": self.adrenaline,
			"max_adrenaline": self.max_adrenaline
		}
		for key in dict.keys():
			if dict[key] == 0:
				dict.erase(key)
		return dict

class BruteforceGame:
	var liveCount: int
	var blankCount: int
	var player: BruteforcePlayer
	var opponent: BruteforcePlayer

	@warning_ignore("shadowed_variable")
	func _init(liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer):
		self.liveCount = liveCount
		self.blankCount = blankCount
		self.player = player
		self.opponent = opponent

	@warning_ignore("shadowed_variable")
	func CreateSubPlayers(liveCount, blankCount, player, opponent):
		if liveCount > self.liveCount or blankCount > self.blankCount:
			return null
		if player.player_index == self.player.player_index:
			player = self.player.createSubplayer(player)
			opponent = self.opponent.createSubplayer(opponent)
		else:
			player = self.opponent.createSubplayer(player)
			opponent = self.player.createSubplayer(opponent)

		if player == null or opponent == null:
			return null

		return [player, opponent]

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		return {
			"LiveCount": self.liveCount,
			"BlankCount": self.blankCount,
			"Player": self.player._to_dict(),
			"Dealer": self.opponent._to_dict()
		}

class TempStates:
	var handcuffState := HANDCUFF_NONE
	var magnifyingGlassResult := MAGNIFYING_NONE
	var usedHandsaw := false
	var inverted := false
	var adrenaline := false
	var futureLive := 0
	var futureBlank := 0

	func clone()->TempStates:
		var other: TempStates = TempStates.new()
		other.handcuffState = self.handcuffState
		other.magnifyingGlassResult = self.magnifyingGlassResult
		other.usedHandsaw = self.usedHandsaw
		other.inverted = self.inverted
		other.adrenaline = self.adrenaline
		other.futureLive = self.futureLive
		other.futureBlank = self.futureBlank
		return other

	func Cuff()->TempStates:
		var other: TempStates = self.clone()
		other.handcuffState = HANDCUFF_CUFFED
		other.adrenaline = false
		return other

	func Magnify(result)->TempStates:
		var other: TempStates = self.clone()
		other.magnifyingGlassResult = result
		other.adrenaline = false
		return other

	func Saw()->TempStates:
		var other: TempStates = self.clone()
		other.usedHandsaw = true
		other.adrenaline = false
		return other

	func Adrenaline()->TempStates:
		var other: TempStates = self.clone()
		other.adrenaline = true
		return other

	func Invert()->TempStates:
		var other: TempStates = self.clone()
		other.inverted = not other.inverted
		if self.magnifyingGlassResult == MAGNIFYING_LIVE:
			other.magnifyingGlassResult = MAGNIFYING_BLANK
		elif self.magnifyingGlassResult == MAGNIFYING_BLANK:
			other.magnifyingGlassResult = MAGNIFYING_LIVE
		other.adrenaline = false
		return other

	func SkipBullet()->TempStates:
		var other: TempStates = self.clone()
		other.inverted = false
		other.magnifyingGlassResult = MAGNIFYING_NONE
		other.adrenaline = false
		other.futureLive = 0
		other.futureBlank = 0
		return other

	func Future(live, blank)->TempStates:
		var other: TempStates = self.clone()
		other.futureLive += live
		other.futureBlank += blank
		other.adrenaline = false
		return other

	func Cigarettes()->TempStates:
		var other: TempStates = self.clone()
		other.adrenaline = false
		return other

	func Medicine()->TempStates:
		var other: TempStates = self.clone()
		other.adrenaline = false
		return other


	func do_hash(num: int, liveCount_max: int)->int:
		num = ((num * 3 + self.handcuffState) * 3 + self.magnifyingGlassResult) * 8
		if self.usedHandsaw:
			num += 4
		if self.inverted:
			num += 2
		if self.adrenaline:
			num += 1
		num *= (liveCount_max+1)
		num += self.futureLive
		num *= (liveCount_max+2)
		num += self.futureBlank

		return num

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		return {
			"HandcuffState": self.handcuffState,
			"MagnifyingGlassResult": self.magnifyingGlassResult,
			"UsedHandsaw": self.usedHandsaw,
			"Inverted": self.inverted,
			"Adrenaline": self.adrenaline,
			"Future Live": self.futureLive,
			"Future Blank": self.futureBlank,
		}

# liveCount and blankCount both contain the count of bullets without considering the effect of active inverters.
# tempStates.magnifyingGlassResult does consider the effect of active inverters.
static var printOptions = true
static var enableDebugTrace = false
static var cachedGame: BruteforceGame = null
static var cache = {}
static var cacheHits = 0
static var cacheMisses = 0
static func GetBestChoiceAndDamage(roundType: int, liveCount: int, blankCount: int, player: BruteforcePlayer, opponent: BruteforcePlayer, tempStates: TempStates):
	var liveCountMax := liveCount
	if cachedGame != null:
		var subPlayers = cachedGame.CreateSubPlayers(liveCount, blankCount, player, opponent)
		if subPlayers != null:
			player = subPlayers[0]
			opponent = subPlayers[1]
			liveCountMax = cachedGame.liveCount
		else:
			cachedGame = null

	if cachedGame == null:
		cache = {}
		cachedGame = BruteforceGame.new(liveCount, blankCount, player, opponent)

	var roundString
	if roundType == ROUNDTYPE_NORMAL:
		roundString = "Normal"
	elif roundType == ROUNDTYPE_WIRECUT:
		roundString = "WireCut"
	else:
		roundString = "DoN"

	ModLoaderLog.info("[%s] %s Live, %s Blank\n%s\n%s\n%s" % [roundString, liveCount, blankCount, player, opponent, tempStates], "ITR-SmarterDealer")

	cacheHits = 0
	cacheMisses = 0
	var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCountMax, player, opponent, tempStates, true)
	ModLoaderLog.info("Cache Hits: %s\nCache Misses: %s\nCache Size: %s" % [cacheHits, cacheMisses, cache.size()], "ITR-SmarterDealer")
	return result

const EPSILON = 0.00000000000001
static func Compare(a: float, b: float)->int:
	if abs(a-b) < EPSILON:
		return 0
	return -1 if a < b else 1

static func sum_array(array)->float:
	var sum := 0.0
	for element in array:
		sum += element
	return sum

static func GetBestChoiceAndDamage_Internal(roundType: int, liveCount: int, blankCount: int, liveCount_max: int, player: BruteforcePlayer, opponent: BruteforcePlayer, tempStates: TempStates, isTopLayer:=false)->Result:
	if player.health <= 0 or opponent.health <= 0:
		var deadPlayerIs0 = (player.player_index if player.health <= 0 else opponent.player_index) == 0

		var deathScore := [1.0, 0.0] if deadPlayerIs0 else [0.0, 1.0]

		# Leftover health doesn't matter when a player dies. Set it to 0 here so CompareCurrent only compares health totals for the fraction of cases that don't end in a death.
		var healthScore: Array[float] = [0.0, 0.0]

		var itemScore: Array[float] = [0.0, 0.0]
		# The only time leftover items matter after a death is if the dealer dies in a double-or-nothing round.
		if not deadPlayerIs0 and roundType == ROUNDTYPE_DOUBLEORNOTHING:
			itemScore[player.player_index] = player.sum_items()
			itemScore[opponent.player_index] = opponent.sum_items()

		return Result.new(OPTION_NONE, deathScore, healthScore, itemScore)

	# On wirecut rounds you can no longer smoke, and your health is set to 1
	if roundType == ROUNDTYPE_WIRECUT:
		if player.health == 2 or (player.health <= 2 and player.cigarettes > 0):
			player = player.use("cigarettes", player.cigarettes)
			player.health = 1
		if opponent.health == 2 or (opponent.health <= 2 and opponent.cigarettes > 0):
			opponent = opponent.use("cigarettes", opponent.cigarettes)
			opponent.health = 1

	var ahash: int = blankCount * (liveCount_max+1) + liveCount
	ahash = player.do_hash(ahash)
	ahash = opponent.do_hash(ahash)
	ahash = tempStates.do_hash(ahash, liveCount_max)

	if cache.has(ahash) and not isTopLayer:
		cacheHits += 1
		return cache[ahash].clone()
	else:
		cacheMisses += 1

	if liveCount == 0 and blankCount == 0:
		var deathChance: Array[float] = [0.0, 0.0]

		var health: Array[float] = [0.0, 0.0]
		health[player.player_index] = player.health
		health[opponent.player_index] = opponent.health

		var itemScore: Array[float] = [0.0, 0.0]
		itemScore[player.player_index] = player.sum_items()
		itemScore[opponent.player_index] = opponent.sum_items()

		# The player can always smoke at the beginning of the next round if they don't die this round.
		# (The same isn't true for the dealer, who could be killed before he can take a turn.)
		# Count the health and item scores for the player using their cigarettes at the beginning of the next round, but
		# don't give them the extra FreeSlots value. (The cigarettes are still occupying a slot during item distribution.)
		var startingPlayer = player if player.player_index == 0 else opponent
		var smokeAmount: int = min(startingPlayer.cigarettes, startingPlayer.max_health - startingPlayer.health)
		health[0] += smokeAmount
		itemScore[0] -= itemScoreArray[OPTION_CIGARETTES][startingPlayer.cigarettes]
		itemScore[0] += itemScoreArray[OPTION_CIGARETTES][startingPlayer.cigarettes - smokeAmount]

		var result = Result.new(OPTION_NONE, deathChance, health, itemScore)
		cache[ahash] = result
		return result.clone()


	var liveChance := 0.0
	var blankChance := 0.0

	if tempStates.magnifyingGlassResult == MAGNIFYING_BLANK:
		liveChance = 0.0
		blankChance = 1.0
	elif tempStates.magnifyingGlassResult == MAGNIFYING_LIVE:
		liveChance = 1.0
		blankChance = 0.0
	else:
		var total := float(liveCount + blankCount - tempStates.futureLive - tempStates.futureBlank)
		liveChance = (liveCount-tempStates.futureLive) / total
		blankChance = (blankCount-tempStates.futureBlank) / total

	var originalRemove := 1
	var invertedRemove := 0
	if tempStates.inverted:
		originalRemove = 0
		invertedRemove = 1
		if tempStates.magnifyingGlassResult == MAGNIFYING_NONE:
			var temp = liveChance
			liveChance = blankChance
			blankChance = temp

	# Some hard-coded kills to speed up:
	if player.player_index == 1:
		if opponent.health == 1 or (opponent.health == 2 and (tempStates.usedHandsaw or player.handsaw > 0 or (opponent.handsaw > 0 and player.adrenaline > 0))):
			var toSteal = 0
			if opponent.health == 2 and not tempStates.usedHandsaw and player.handsaw == 0:
				toSteal = 1

			if liveChance >= 1:
				if opponent.health == 2 and not tempStates.usedHandsaw:
					if player.handsaw == 0 and opponent.handsaw > 0 and player.adrenaline > 0 and not tempStates.adrenaline:
						var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
						result.option = OPTION_ADRENALINE
						result.depth += 1
						cache[ahash] = result
						return result.clone()
					var a = player
					var b = opponent
					if tempStates.adrenaline:
						b = b.use("handsaw")
					else:
						a = a.use("handsaw")
					var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Saw())
					result.option = OPTION_HANDSAW
					result.depth += 1
					cache[ahash] = result
					return result.clone()

				var result = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent.use("health", opponent.health), player, TempStates.new())
				result = result.clone()
				result.option = OPTION_SHOOT_OTHER
				result.depth += 1
				cache[ahash] = result
				return result.clone()
			elif blankChance >= 1:
				if player.inverter > 0 or (opponent.inverter > 0 and tempStates.adrenaline):
					var a = player
					var b = opponent
					if tempStates.adrenaline:
						b = b.use("inverter")
					else:
						a = a.use("inverter")
					var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Invert())
					result.option = OPTION_INVERTER
					result.depth += 1
					cache[ahash] = result
					return result.clone()
				elif opponent.inverter > 0 and player.adrenaline > toSteal:
					var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
					result.option = OPTION_ADRENALINE
					result.depth += 1
					cache[ahash] = result
					return result.clone()
			elif (player.magnify > 0 or (tempStates.adrenaline and opponent.magnify > 0)) and (player.inverter > 0 or (opponent.inverter > 0 and player.adrenaline > toSteal)):
				var a = player
				var b = opponent
				if tempStates.adrenaline:
					b = b.use("magnify")
				else:
					a = a.use("magnify")
				var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_BLANK))
				var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_LIVE))
				var result = blankResult.mult(blankChance)
				result.mutAdd(liveResult.mult(liveChance))
				result.option = OPTION_MAGNIFY
				result.depth += 1
				cache[ahash] = result
				return result.clone()
			elif (opponent.magnify > 0 and player.inverter > 0 and player.adrenaline > toSteal) or (opponent.magnify > 0 and opponent.inverter > 0 and player.adrenaline >= toSteal+2):
				var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
				result.option = OPTION_ADRENALINE
				result.depth += 1
				cache[ahash] = result
				return result.clone()

	var options: Dictionary = {}

	var itemFrom = opponent if tempStates.adrenaline else player

	if tempStates.handcuffState <= HANDCUFF_NONE and itemFrom.handcuffs > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("handcuffs")
		else:
			a = a.use("handcuffs")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Cuff())
		options[OPTION_HANDCUFFS] = result

	if itemFrom.cigarettes > 0:
		var healedPlayer := player.use("cigarettes", 0 if tempStates.adrenaline else 1)
		var healedOpponent := opponent.use("cigarettes", 1 if tempStates.adrenaline else 0)
		if healedPlayer.health < healedPlayer.max_health:
			healedPlayer.health += 1
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, healedPlayer, healedOpponent, tempStates.Cigarettes())
		options[OPTION_CIGARETTES] = result

	if itemFrom.beer > 0:
		var beerPlayer = player
		var beerOpponent = opponent
		if tempStates.adrenaline:
			beerOpponent = beerOpponent.use("beer")
		else:
			beerPlayer = beerPlayer.use("beer")

		options[OPTION_BEER] = Result.new(OPTION_BEER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
		if liveChance > 0:
			var liveBeerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, beerPlayer, beerOpponent, tempStates.SkipBullet())
			options[OPTION_BEER].mutAdd(liveBeerResult.mult(liveChance))
		if blankChance > 0:
			var blankBeerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, beerPlayer, beerOpponent, tempStates.SkipBullet())
			options[OPTION_BEER].mutAdd(blankBeerResult.mult(blankChance))

	if itemFrom.medicine > 0:
		var medicinePlayer := player.use("medicine", 0 if tempStates.adrenaline else 1)
		var medicineOpponent := opponent.use("medicine", 1 if tempStates.adrenaline else 0)

		var goodMedicine := medicinePlayer.use("health", -2)
		if goodMedicine.health > goodMedicine.max_health:
			goodMedicine.health = goodMedicine.max_health
		var badMedicine := medicinePlayer.use("health", 1)
		var goodResult := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, goodMedicine, medicineOpponent, tempStates.Medicine())
		var badResult := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, badMedicine, medicineOpponent, tempStates.Medicine())
		goodResult.mutAdd(badResult)
		options[OPTION_MEDICINE] = goodResult.mult(0.5)

	if itemFrom.inverter > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("inverter")
		else:
			a = a.use("inverter")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Invert())
		options[OPTION_INVERTER] = result


	if not tempStates.usedHandsaw and itemFrom.handsaw > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("handsaw")
		else:
			a = a.use("handsaw")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Saw())
		options[OPTION_HANDSAW] = result

	if not tempStates.adrenaline and player.adrenaline > 0:
		var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
		options[OPTION_ADRENALINE] = result

	if itemFrom.magnify > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("magnify")
		else:
			a = a.use("magnify")

		options[OPTION_MAGNIFY] = Result.new(OPTION_MAGNIFY, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
		if liveChance > 0:
			var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_LIVE))
			options[OPTION_MAGNIFY].mutAdd(liveResult.mult(liveChance))
		if blankChance > 0:
			var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_BLANK))
			options[OPTION_MAGNIFY].mutAdd(blankResult.mult(blankChance))


	if itemFrom.burner > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("burner")
		else:
			a = a.use("burner")

		# There are 4 possible scenarios:
		# Hit an unseen live (expectedFutureLive - knownFutureLive) / futureShells
		# Hit an unseen blank (expectedFutureBlank - knownFutureBlank) / futureShells
		# Hit an already seen live (knownFutureLive / futureShells)
		# Hit an already seen blank (knownFutureBlank / futureShells)

		var futureShellCount := float(blankCount+liveCount-1)
		var uninvertedFirstLiveChance := liveChance if not tempStates.inverted else blankChance

		var bMissChance
		var bLiveChance
		var bBlankChance
		if futureShellCount == 0:
			# Using a burner with no future shells is guaranteed to not give information.
			bMissChance = 1.0
			bLiveChance = 0.0
			bBlankChance = 0.0
		else:
			bMissChance = (tempStates.futureBlank+tempStates.futureLive) / futureShellCount
			bLiveChance = (liveCount - uninvertedFirstLiveChance - tempStates.futureLive) / futureShellCount
			bBlankChance = (blankCount - (1-uninvertedFirstLiveChance) - tempStates.futureBlank) / futureShellCount

		options[OPTION_BURNER] = Result.new(OPTION_BURNER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

		if bMissChance > 0:
			var missResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Future(0, 0))
			options[OPTION_BURNER].mutAdd(missResult.mult(bMissChance))
		if bLiveChance > 0:
			var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Future(1, 0))
			options[OPTION_BURNER].mutAdd(liveResult.mult(bLiveChance))
		if bBlankChance > 0:
			var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Future(0, 1))
			options[OPTION_BURNER].mutAdd(blankResult.mult(bBlankChance))

	var damageToDeal := 2 if tempStates.usedHandsaw else 1

	options[OPTION_SHOOT_OTHER] = Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
	options[OPTION_SHOOT_SELF] = Result.new(OPTION_SHOOT_SELF, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	if liveChance > 0:
		var resultIfShootLive := Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
		var resultIfSelfShootLive := Result.new(OPTION_SHOOT_SELF, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
		if tempStates.handcuffState <= HANDCUFF_FREENEXT:
			resultIfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent.use("health", damageToDeal), player, TempStates.new())
			resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent, player.use("health", damageToDeal), TempStates.new())
		else:
			var newTempState := TempStates.new()
			newTempState.handcuffState = HANDCUFF_FREENEXT
			resultIfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, player, opponent.use("health", damageToDeal), newTempState.clone())
			resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, player.use("health", damageToDeal), opponent, newTempState)

		options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootLive.mult(liveChance))
		options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootLive.mult(liveChance))

	if blankChance > 0:
		var selfShootState := tempStates.SkipBullet()
		selfShootState.usedHandsaw = false
		var resultIfSelfShootBlank := GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, player, opponent, selfShootState)

		var resultIfShootBlank := Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])
		if tempStates.handcuffState <= HANDCUFF_FREENEXT:
			resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, opponent, player, TempStates.new())
		else:
			var newTempState := TempStates.new()
			newTempState.handcuffState = HANDCUFF_FREENEXT
			resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, player, opponent, newTempState)

		options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))
		options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootBlank.mult(blankChance))


	if (printOptions and isTopLayer) or enableDebugTrace:
		print(options, " (", ahash, ")")
	if enableDebugTrace:
		print("%s Live, %s Blank\n%s\n%s\n%s" % [liveCount, blankCount, player, opponent, tempStates])

	var current: Result = null
	var results: Array[Result] = []

	for key in options:
		var option = options[key].clone()
		option.option = key

		if current == null:
			current = option
			results = [current]
			continue

		var comparison = CompareCurrent(player.player_index == 0, current, option)
		if comparison == 0:
			results.append(option)
			continue

		if comparison < 0:
			continue

		current = option
		results = [current]

	if results.size() > 1:
		results.shuffle()

	results[0].depth += 1
	cache[ahash] = results[0]
	return results[0].clone()

# -1 means current is better than other
static func CompareCurrent(isPlayer0: bool, current: Result, other: Result):
	if isPlayer0:
		# The player's first priority is staying alive, followed by killing the dealer.
		# This is because the player has a strong advantage in new rounds because they go first.

		# Lower is better
		var surviveComparison = Compare(
			current.deathChance[0],
			other.deathChance[0]
		)
		if surviveComparison != 0:
			return surviveComparison

		# Higher is better
		var killComparison = Compare(
			other.deathChance[1],
			current.deathChance[1]
		)
		if killComparison != 0:
			return killComparison
	else:
		# The dealer's first priority is killing the player, followed by staying alive.
		# This is because the player has a strong advantage in new rounds because they go first, and the dealer only has to kill the player once.

		# Higher is better
		var killComparison = Compare(
			other.deathChance[0],
			current.deathChance[0]
		)
		if killComparison != 0:
			return killComparison

		# Lower is better
		var surviveComparison = Compare(
			current.deathChance[1],
			other.deathChance[1]
		)
		if surviveComparison != 0:
			return surviveComparison

	var myIndex = 0 if isPlayer0 else 1
	var otherIndex = 1 if isPlayer0 else 0

	var healthDiff = current.healthScore[myIndex] - current.healthScore[otherIndex]
	var otherHealthDiff = other.healthScore[myIndex] - other.healthScore[otherIndex]

	# Higher is better
	var healthComparison := Compare(otherHealthDiff, healthDiff)
	if healthComparison != 0:
		return healthComparison

	var itemDiff = current.itemScore[myIndex] - current.itemScore[otherIndex]
	var otherItemDiff = other.itemScore[myIndex] - other.itemScore[otherIndex]

	# Higher is better
	var itemComparison := Compare(otherItemDiff, itemDiff)
	if itemComparison != 0:
		return itemComparison

	# All else being equal, don't waste time.
	# Lower is better
	return Compare(current.depth, other.depth)
