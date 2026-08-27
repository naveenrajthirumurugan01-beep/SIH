# Digital Twin Methodology Document
**Project:** Landslide Early-Warning System (Dibang Valley, Arunachal Pradesh)  
**Reference Study:** *Digital Twin Modeling for Landslide Risk Scenarios in Mountainous Regions*, Sensors 2026, 26, 421  

---

## 1. Problem Definition `[PROJECT IMPLEMENTATION]`
In steep mountainous corridors like Dibang Valley, rainfall-induced slope instability rarely occurs in isolated vacuum. When an active landslide or critical risk zone (e.g. `DV-007`) reaches high stress or failure, surrounding terrain slopes experience hydrological loading, pore-water pressure transfer, and slope-toe stress redistribution. 

The objective of this Digital Twin engine is to answer:
> *"Given an active critical zone (`DV-007`) and current meteorological/geotechnical states, which surrounding terrain zone will exhibit the strongest emergent progression toward failure under temporal scenarios (+1h to +24h)?"*

---

## 2. Research-Paper Foundations `[RESEARCH-DERIVED]`
Our physical formulation adopts key findings and principles from *Sensors 2026, 26, 421*:
1. **Hydro-Mechanical Coupling Chain:**
   $$\text{Rainfall } (I) \longrightarrow \text{Surface Infiltration } (q) \longrightarrow \text{Soil Saturation } (S_w) \longrightarrow \text{Pore Pressure } (u) \longrightarrow \text{Effective Stress } (\sigma') \longrightarrow \text{Shear Strength } (\tau) \longrightarrow \text{Displacement } (\delta, v, a) \longrightarrow \text{Instability Score } (Risk)$$
2. **Stress Redistribution & Sensitivity:**
   - Numerical simulations in the study demonstrate a trapezoidal stress distribution increasing from surface to interior.
   - Toe stress is highly sensitive to slope inclination ($\beta$).
   - A critical strain/displacement mutation-sensitive zone occurs near ~0.1 slope height above the toe (2–4 m for a 20 m slope setup).
3. **Seepage & Unit Weight:**
   - Rainwater infiltration raises material bulk unit weight ($\gamma_{sat}$), increasing downward driving shear force ($\tau_d$) while dissipating matric suction and lowering effective stress ($\sigma'$).

---

## 3. Physical State Evolution Engine `[PROJECT IMPLEMENTATION]`
Each candidate zone maintains a dynamic state vector $\mathbf{S}_z(t)$:
$$\mathbf{S}_z(t) = \left[ \text{Terrain}, \text{Rainfall}(t), S_w(t), u(t), \sigma'(t), \tau(t), \delta(t), a(t), Risk(t) \right]$$

### State Evolution Sequence:
1. **$t_0$ (Initial State):** Ingests antecedent rainfall, current soil moisture ($S_w$), pore pressure ($u_0$), and sensor displacement rate ($v_0$).
2. **$t_{+1h} \dots t_{+24h}$ (Temporal Forward Integration):**
   - Rainfall intensity scenario $I(t)$ infiltrates slope surface at rate $q = I(t) \cdot \cos(\beta)$.
   - Soil saturation $S_w(t)$ increases toward saturation ($S_w \to 1.0$) constrained by soil permeability ($k$).
   - Pore-water pressure $u(t)$ rises proportionally: $\Delta u = \rho_w g \cdot \Delta S_w \cdot z_{water}$.
   - Effective normal stress reduces: $\sigma'(t) = \sigma - u(t)$.
   - Mohr-Coulomb shear strength degrades: $\tau(t) = c' + \sigma'(t) \tan(\phi')$.
   - Factor of Safety ($F_s$) and dynamic Risk Index ($Risk(t)$) are recalculated.
   - Displacement acceleration $a_{disp}(t)$ is integrated to evaluate velocity and movement trends.

---

## 4. Candidate Zone Selection & Emerging Risk Ranking `[SIMULATION ASSUMPTION]`
To prevent naive geographical distance selection, candidate zones within a spatial search radius ($R_{search} = 5.0\text{ km}$) are evaluated using **Emerging Risk Velocity ($\Delta Risk$)** and **Instability Acceleration ($a_{disp}$)**:

$$\Delta Risk = Risk(t_{future}) - Risk(t_0)$$

Candidate zones are ranked by:
$$\text{Rank Score} = w_{risk} \cdot Risk(t_{future}) + w_{\Delta} \cdot \Delta Risk + w_{accel} \cdot \text{norm}(a_{disp}) + w_{topo} \cdot \text{norm}(\beta)$$

The zone with the highest Rank Score that is NOT the source incident zone is selected as `NEXT_EMERGENT_RISK`.

---

## 5. Traceability & Simulation Audit Trail `[PROJECT IMPLEMENTATION]`
Every prediction decision produces an immutable audit record containing:
- Incident zone snapshot
- Candidate physical parameters
- Full hydro-mechanical equation execution breakdown
- Dominant contributing physical factors
- Transparent simulation confidence score (based on telemetry completeness and trend stability).

---

## 6. Validation & Limitations Status `[NOT YET VALIDATED]`
- **Validation Status:** `NOT YET VALIDATED WITH LOCAL FIELD OBSERVATIONS`
- **Prototype Status:** Executes using verified synthetic datasets representing Dibang Valley morphology.
- **Future Field Calibration:** Requires field piezometer arrays, borehole inclinometers, and automated weather stations (AWS) for empirical parameter tuning.
