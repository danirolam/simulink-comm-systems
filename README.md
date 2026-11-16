# Communication systems in Simulink

MATLAB scripts that build Simulink models of analog and digital communication
links, from the labs of ECSE 308 (Communication Systems and Networks) at McGill
University, Fall 2026.

Each script draws its model from code (blocks, wiring and parameters), so the
model can be rebuilt from scratch and every setting is written down in one
place.

## What is here

| Folder | Script | What it builds |
| --- | --- | --- |
| `lab1-signals` | `p2_source.m` | Swaps the source of a test circuit: sine, triangle, square waves, a sum of three sines |
| `lab2-analog-modulation` | `build_L2T2.m` | AM with carrier (DSB-LC): modulator and receiver |
| | `build_L2T2_sc.m` | AM with suppressed carrier (DSB-SC) |
| | `build_L2T2_p2.m` | FM, with a second model that shows FM is not linear |
| | `build_L2T2_p3.m` | FM through noise. Can sweep the frequency deviation and print carrier level, sidebands, 99% bandwidth and Carson's bandwidth |
| `lab3-digital-modulation` | `build_L3T3_p1.m` | Sampling and quantization, then baseband transmission over a noisy channel with a bit error rate sweep |
| | `build_L3T3_p2.m` | Binary ASK, PSK and FSK, and 4-QAM |
| | `build_L3T3_p3.m` | 16, 64 and 256-QAM over a noisy channel with a bit error rate sweep |

The two CSV files in `lab3-digital-modulation` are the bit error rates the
sweeps measured, next to the theoretical values.

## Running

In MATLAB with Simulink, from the script's folder:

```
build_L3T3_p1
build_L3T3_p1 sweep
```

The comment at the top of each script lists its options.
