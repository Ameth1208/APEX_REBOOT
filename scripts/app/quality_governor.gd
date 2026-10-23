class_name ApexQualityGovernor
extends RefCounted
## Hysteresis changes only render quality; simulation timing is never adjusted.

const MIN_SCALE: float = 0.70
const TARGET_FRAME_MS: float = 1000.0 / 60.0
var scale: float = 1.0
var average_frame_ms: float = TARGET_FRAME_MS
var average_gpu_ms: float = 0.0
var _warmup: float = 2.0
var _slow_seconds: float = 0.0
var _fast_seconds: float = 0.0
var _cooldown: float = 0.0

func reset() -> void:
	_warmup = 2.0
	_slow_seconds = 0.0
	_fast_seconds = 0.0
	_cooldown = 0.0
	average_frame_ms = TARGET_FRAME_MS
	average_gpu_ms = 0.0

func sample(delta: float, gpu_ms: float = 0.0, active: bool = true) -> bool:
	if not active or not is_finite(delta) or delta <= 0.0:
		return false
	var elapsed: float = minf(delta, 0.25)
	if _warmup > 0.0:
		_warmup -= elapsed
		return false
	var weight: float = 1.0 - exp(-elapsed * 2.0)
	average_frame_ms = lerpf(average_frame_ms, minf(delta * 1000.0, 150.0), weight)
	if is_finite(gpu_ms) and gpu_ms > 0.0:
		average_gpu_ms = lerpf(average_gpu_ms, minf(gpu_ms, 150.0), weight)
	_cooldown = maxf(0.0, _cooldown - elapsed)
	# A loading spike can keep the moving average high after normal frames return.
	# Require current frames to confirm sustained pressure before reducing quality.
	var slow: bool = average_frame_ms > TARGET_FRAME_MS * 1.12 and delta * 1000.0 > TARGET_FRAME_MS * 1.08
	var headroom: bool = average_frame_ms < TARGET_FRAME_MS * 1.035 and (average_gpu_ms <= 0.0 or average_gpu_ms < 12.0)
	_slow_seconds = _slow_seconds + elapsed if slow else maxf(0.0, _slow_seconds - elapsed * 2.0)
	_fast_seconds = _fast_seconds + elapsed if headroom else 0.0
	if _cooldown > 0.0:
		return false
	var next: float = scale
	if _slow_seconds >= 1.5:
		next = maxf(MIN_SCALE, snappedf(scale - 0.10, 0.05))
	elif _fast_seconds >= 12.0:
		next = minf(1.0, snappedf(scale + 0.05, 0.05))
	if is_equal_approx(next, scale):
		return false
	scale = next
	_cooldown = 4.0
	_slow_seconds = 0.0
	_fast_seconds = 0.0
	return true
