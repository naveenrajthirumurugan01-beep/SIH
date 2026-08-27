# Digital Twin Simulation Assumptions
**Module:** Digital Twin Engine (Dibang Valley Landslide EWS)  

---

## 1. Topographic & Spatial Assumptions `[SIMULATION ASSUMPTION]`
- **Spatial Resolution:** Zone coordinates represent representative centroid locations across Dibang Valley (Anini, Etalin, Mathunli, Dambuk, Dri River Slope).
- **Slope Morphology:** Slope heights range from $20\text{ m}$ to $50\text{ m}$ with steep slope angles $\beta \in [35^\circ, 65^\circ]$.
- **Search Radius:** Spatial candidate candidate evaluation uses a $5.0\text{ km}$ spatial search radius around the active incident zone.

---

## 2. Soil & Geotechnical Parameter Standardization `[RESEARCH-DERIVED]`
Parameters adopt baseline values established in Sensors 2026 Table 1:
- Dry Density ($\gamma_{dry}$): $1.3\text{ g/cm}^3$
- Initial Void Ratio ($e$): $1.0$ (Void ratio fraction $n = e/(1+e) = 0.5$)
- Deformation Modulus ($E$): $30\text{ MPa}$
- Poisson's Ratio ($\nu$): $0.30$
- Saturated Permeability ($k_{sat}$): $0.018\text{ m/h}$
- Internal Friction Angle ($\phi'$): $30^\circ$
- Effective Cohesion ($c'$): $15\text{ kPa}$ (slopes $<50^\circ$), $30\text{ kPa}$ ($50^\circ–65^\circ$), $40\text{ kPa}$ ($>65^\circ$)

---

## 3. Hydrological & Meteorological Assumptions `[SIMULATION ASSUMPTION]`
- Extreme rainstorm benchmark intensity: $0.02\text{ m/h} = 20\text{ mm/h}$ (Sensors 2026 Section 2.2.2).
- Antecedent rainfall is calculated over 72 hours prior to forecast window.
- Infiltration is assumed uniform across the upper soil mantle with no immediate preferential macro-pore piping unless specified by scenario.

---

## 4. Model Limitations `[PROJECT IMPLEMENTATION]`
- **Homogeneous Layering:** The prototype assumes isotropic single-layer plastic soil conditions across individual zones.
- **2D-to-3D Projection:** Discrete element particle forces map planar geotechnical equilibrium onto candidate centroids.
- **Uncalibrated Telemetry:** Sensors and telemetry data in `/data/synthetic/` serve as prototype inputs and require field calibration with local GSI/NESAC monitoring telemetry.
