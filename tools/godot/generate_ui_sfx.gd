## One-off generator for the placeholder UI interaction blips (border
## vocabulary, ui-style-guide.md §14). Synthesizes the three square-wave ticks
## the HTML mockup used — hover ~2.4 kHz / 25 ms, press ~900 Hz + a bright
## transient, deny = low double-knock — and writes them to res://audio/ui/.
## The shape is the spec (sharp attack, dead-fast decay, mid-band, RE1/Deus Ex
## crispy); Lawrence replaces the files with real samples later, same names.
##
## Run:  godot-4 --headless --path . -s tools/godot/generate_ui_sfx.gd
extends SceneTree

const MIX_RATE: int = 44100
const OUTPUT_DIRECTORY: String = "res://audio/ui"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	_write("blip_hover.wav", _mix([_square(2400.0, 0.025, 0.18, 0.0)]))
	_write("blip_press.wav", _mix([
		_square(900.0, 0.055, 0.30, 0.0),
		_square(2200.0, 0.014, 0.14, 0.0),
	]))
	_write("blip_deny.wav", _mix([
		_square(300.0, 0.05, 0.28, 0.0),
		_square(240.0, 0.07, 0.28, 0.07),
	]))
	print("generate_ui_sfx: wrote 3 blips to %s" % OUTPUT_DIRECTORY)
	quit()


## A square-wave burst with exponential decay, starting `delay` seconds in.
## Returns per-sample floats (mono, MIX_RATE).
func _square(frequency: float, duration: float, gain: float, delay: float) -> PackedFloat32Array:
	var total := int((delay + duration) * MIX_RATE)
	var start := int(delay * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(total)
	for i: int in range(start, total):
		var t := float(i - start) / MIX_RATE
		var envelope := gain * exp(-t / (duration * 0.35))
		var phase := fmod(t * frequency, 1.0)
		samples[i] = envelope * (1.0 if phase < 0.5 else -1.0)
	return samples


func _mix(layers: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var length := 0
	for layer: PackedFloat32Array in layers:
		length = maxi(length, layer.size())
	var mixed := PackedFloat32Array()
	mixed.resize(length)
	for layer: PackedFloat32Array in layers:
		for i: int in layer.size():
			mixed[i] = clampf(mixed[i] + layer[i], -1.0, 1.0)
	return mixed


func _write(file_name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(samples[i] * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	var path := "%s/%s" % [OUTPUT_DIRECTORY, file_name]
	var err := stream.save_to_wav(path)
	if err != OK:
		push_error("generate_ui_sfx: failed to write %s (error %d)" % [path, err])
