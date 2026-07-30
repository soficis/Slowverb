"""
Verify SoX Reverb Parameter Math
=================================
Four claims about the Freeverb-derived reverb in SoX.
"""
import math

FS = 44100.0          # sample rate
L_AVG = 1378.0        # average comb-filter delay length (samples)

print("=" * 72)
print("CLAIM 1: Freeverb feedback from reverberance")
print("=" * 72)
print()
print("feedback(reverberance) = 1 - exp((reverberance + 10.032) / -28.123)")
print()

reverberances = [0, 50, 65, 75, 90, 100]
print(f"{'Reverb':>10}  {'Feedback':>10}  {'RT60 (s)':>10}  {'RT60 (ms)':>10}")
print("-" * 48)
for r in reverberances:
    fb = 1.0 - math.exp((r + 10.032) / -28.123)
    # RT60 = -3 * L_avg / (fs * log10(feedback))
    rt60 = -3.0 * L_AVG / (FS * math.log10(fb))
    print(f"{r:>10}  {fb:>10.6f}  {rt60:>10.3f}  {rt60*1000:>10.1f}")
print()
print(f"Notes:")
print(f"  L_avg (average comb delay)  = {L_AVG:.0f} samples")
print(f"  Sample rate                 = {FS:.0f} Hz")
print(f"  RT60 formula                = -3 * L_avg / (fs * log10(feedback))")
print()

# ----------------------------------------------------------------------
print("=" * 72)
print("CLAIM 2: HF-damping coefficient and cutoff frequency")
print("=" * 72)
print()
print("g = hf_damping/100 * 0.3 + 0.2")
print("cutoff(fs) = arccos((4g - 1 - g^2) / (2g)) * fs / (2*pi)")
print()

hf_values = [0, 25, 50, 75, 100]
print(f"{'HF-damp':>10}  {'g':>10}  {'cutoff (Hz)':>12}  {'cutoff (kHz)':>12}")
print("-" * 48)
for hf in hf_values:
    g = hf / 100.0 * 0.3 + 0.2
    # arccos((4g - 1 - g^2) / (2g))
    arg = (4.0 * g - 1.0 - g * g) / (2.0 * g)
    # Clamp to [-1, 1] for numerical safety
    arg = max(-1.0, min(1.0, arg))
    cutoff = math.acos(arg) * FS / (2.0 * math.pi)
    print(f"{hf:>10}  {g:>10.6f}  {cutoff:>12.1f}  {cutoff/1000:>12.3f}")
print()

# ----------------------------------------------------------------------
print("=" * 72)
print("CLAIM 3: Wet-gain scaling (fixed -36.5 dB scaler)")
print("=" * 72)
print()
print("gain_linear = 10^(wet_gain_dB / 20) * 0.015")
print("gain_dB     = 20 * log10(gain_linear)")
print()

wet_dbs = [-10, -5, 0, 5, 10]
print(f"{'Wet dB':>10}  {'linear(dB)':>12}  {'* 0.015':>12}  {'actual dB':>12}  {'offset':>12}")
print("-" * 60)
SCALER = 0.015
SCALER_DB = 20.0 * math.log10(SCALER)  # -36.478
for w in wet_dbs:
    lin = 10.0 ** (w / 20.0)
    scaled = lin * SCALER
    actual_db = 20.0 * math.log10(scaled) if scaled > 0 else float("-inf")
    offset = actual_db - w
    print(f"{w:>10}  {lin:>12.6f}  {scaled:>12.8f}  {actual_db:>12.2f}  {offset:>12.2f}")
print()
print(f"Fixed scaler value     = {SCALER}")
print(f"Fixed scaler in dB     = {SCALER_DB:.3f} dB  (published: -36.5 dB)")
print(f"Effective gain         = wet_gain(dB) + {SCALER_DB:.3f} dB")
print()

# ----------------------------------------------------------------------
print("=" * 72)
print("CLAIM 4: SLOWED_REVERB preset RT60")
print("=" * 72)
print()
print("Preset: speed=0.8, reverb=65 50 100 100 0 0")
print("  reverberance=65, hf-damping=50, room-scale=100, stereo-depth=100, pre-delay=0, wet-gain=0")
print()

# At speed 0.8, the effective sample rate changes:
# The audio is resampled to 0.8 * 44100 = 35280 Hz, then reverbed, then resampled back
# The comb filter delays are in samples, so at the lower internal rate the
# effective L_avg changes: L_avg_scaled = L_avg / speed
speed = 0.8
reverberance = 65.0
hf_damping = 50.0
wet_gain = 0.0  # dB

fs_eff = FS * speed  # internal sample rate
L_avg_eff = L_AVG / speed  # delays scale inversely with speed

fb = 1.0 - math.exp((reverberance + 10.032) / -28.123)
rt60_eff = -3.0 * L_avg_eff / (fs_eff * math.log10(fb))

print(f"  Original fs             = {FS:.0f} Hz")
print(f"  Speed                   = {speed}")
print(f"  Effective fs            = {fs_eff:.0f} Hz")
print(f"  L_avg (original)        = {L_AVG:.0f} samples")
print(f"  L_avg (scaled by speed) = {L_avg_eff:.0f} samples")
print(f"  Feedback (reverb=65)    = {fb:.6f}")
print(f"  RT60 (effective)        = {rt60_eff:.3f} s")
print(f"  RT60 (effective)        = {rt60_eff*1000:.1f} ms")
print()
print(f"  => The SLOWED_REVERB preset produces a {rt60_eff:.1f} second decay at 44.1 kHz.")
print()

# ----------------------------------------------------------------------
print("=" * 72)
print("SUMMARY TABLE: feedback & RT60 for all common reverberance values")
print("=" * 72)
print()
print(f"{'Reverb':>8}  {'Feedback':>10}  {'RT60@44.1k':>12}  {'RT60@32k':>12}  {'RT60@22k':>12}  {'RT60@16k':>12}")
print("-" * 60)
for r in range(0, 101, 5):
    fb = 1.0 - math.exp((r + 10.032) / -28.123)
    rt60_44 = -3.0 * L_AVG / (FS * math.log10(fb))
    rt60_32 = -3.0 * L_AVG / (32000.0 * math.log10(fb))
    rt60_22 = -3.0 * L_AVG / (22050.0 * math.log10(fb))
    rt60_16 = -3.0 * L_AVG / (16000.0 * math.log10(fb))
    print(f"{r:>8}  {fb:>10.6f}  {rt60_44:>12.3f}  {rt60_32:>12.3f}  {rt60_22:>12.3f}  {rt60_16:>12.3f}")
