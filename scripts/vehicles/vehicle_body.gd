class_name ApexVehicle
extends ApexVehicle3D
## Shared physical body for player and AI. Local forward is -Z; steer > 0 is right.
## Inherits complete real-force physics architecture from ApexVehicle3D:
## - Per-wheel normal loads Fz, longitudinal Fx, lateral Fy, xs, \dot{xs}, kappa, alpha, gamma, T, P, wear
## - Asymmetric dampers (bump cb vs rebound cr), bump stop kb * max(0, x - xb)^n
## - Front & rear anti-roll bars (ARB)
## - Friction ellipse combined slip (Fx / (mu_x * Fz))^2 + (Fy / (mu_y * Fz))^2 <= 1
## - Load sensitivity and strict zero-grip on airborne wheels (Fz == 0)
## - Continuous physics from 0 to 300+ km/h without artificial speed thresholds
