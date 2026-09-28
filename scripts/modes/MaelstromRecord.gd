class_name MaelstromRecord extends RefCounted

## Purpose: the Maelstrom's persistent best-run record (M26 Requirement 6.4).
## Responsibilities: {best_seconds, best_level, runs} with the project's
##   get_save_data()/load_save_data() pair. SaveManager owns where it is stored.

var best_seconds: float = 0.0
var best_level: int = 0
var runs: int = 0


func merge_run(seconds: float, level: int) -> void:
	runs += 1
	best_seconds = maxf(best_seconds, seconds)
	best_level = maxi(best_level, level)


func merge_record(other: Dictionary) -> void:
	## Folds in a DISJOINT set of runs (the pending file's, which only ever
	## exists while there is no campaign save to hold them).
	runs += int(other.get("runs", 0))
	best_seconds = maxf(best_seconds, float(other.get("best_seconds", 0.0)))
	best_level = maxi(best_level, int(other.get("best_level", 0)))


func is_empty() -> bool:
	return runs <= 0


func get_save_data() -> Dictionary:
	return {"best_seconds": best_seconds, "best_level": best_level, "runs": runs}


func load_save_data(data: Dictionary) -> void:
	best_seconds = float(data.get("best_seconds", 0.0))
	best_level = int(data.get("best_level", 0))
	runs = int(data.get("runs", 0))
