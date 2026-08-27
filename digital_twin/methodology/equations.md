# Hydro-Mechanical Equations & Formulations
**Module:** Digital Twin Engine (Dibang Valley Landslide EWS)  
**Scientific Reference:** *Sensors 2026, 26, 421*  

---

## 1. Surface Infiltration Rate `[RESEARCH-DERIVED]`
In accordance with slope boundary conditions in Sensors 2026, rainfall infiltration rate $q$ acting on a slope face of inclination angle $\beta$ under rainfall intensity $I$ (m/h) is given by:
$$q = I \cdot \cos(\beta)$$

---

## 2. Soil Saturation & Moisture Evolution `[PROJECT IMPLEMENTATION]`
The degree of saturation $S_w(t) \in [0.0, 1.0]$ evolves over timestep $\Delta t$ based on infiltration rate $q$ and saturated soil permeability $k_{sat}$ ($0.018\text{ m/h}$ per Sensors 2026 Table 1):
$$\Delta S_w = \frac{q}{n \cdot z_{depth}} \cdot \left(1 - S_w(t)\right) \cdot \Delta t$$
where $n$ is initial soil void ratio ($n \approx 0.5$ derived from void ratio $e=1.0$) and $z_{depth}$ is representative soil mantle depth (m).

---

## 3. Pore-Water Pressure Formulation `[RESEARCH-DERIVED]`
Hydrostatic & seepage-induced pore-water pressure $u(t)$ (kPa) increases with saturation $S_w(t)$:
$$u(t) = u_0 + \rho_w \cdot g \cdot (S_w(t) - S_{w,0}) \cdot z_{depth} \cdot \cos^2(\beta)$$
where $\rho_w = 1.0\text{ g/cm}^3 = 1000\text{ kg/m}^3$ and $g = 9.81\text{ m/s}^2$.

---

## 4. Total Normal Stress `[RESEARCH-DERIVED]`
Total normal stress $\sigma$ on the potential failure plane at depth $z_{depth}$ under slope inclination $\beta$:
$$\sigma = \left[ \gamma_{dry} + S_w(t) \cdot n \cdot \rho_w g \right] \cdot z_{depth} \cdot \cos^2(\beta)$$
where $\gamma_{dry} = 1.3\text{ g/cm}^3 = 12.75\text{ kN/m}^3$ (Sensors 2026 Table 1).

---

## 5. Effective Normal Stress (Terzaghi Principle) `[RESEARCH-DERIVED]`
$$\sigma'(t) = \sigma(t) - u(t)$$

---

## 6. Mohr-Coulomb Shear Strength Degradation `[RESEARCH-DERIVED]`
The available shear strength $\tau_{available}$ (kPa) on the potential slip surface is:
$$\tau_{available}(t) = c' + \sigma'(t) \cdot \tan(\phi')$$
where:
- $c'$ = Effective cohesion (15–40 kPa depending on slope angle per Sensors 2026 Table 1)
- $\phi'$ = Effective internal friction angle ($30^\circ$ per Sensors 2026 Table 1)

---

## 7. Downward Driving Shear Stress `[RESEARCH-DERIVED]`
$$\tau_{driving}(t) = \left[ \gamma_{dry} + S_w(t) \cdot n \cdot \rho_w g \right] \cdot z_{depth} \cdot \sin(\beta) \cdot \cos(\beta) + F_{seepage}$$
where seepage force per unit volume $F_{seepage} = \gamma_w \cdot i \cdot \sin(\beta)$.

---

## 8. Factor of Safety ($F_s$) `[PROJECT IMPLEMENTATION]`
$$F_s(t) = \frac{\tau_{available}(t)}{\tau_{driving}(t)} = \frac{c' + (\sigma(t) - u(t)) \tan(\phi')}{\tau_{driving}(t)}$$

---

## 9. Displacement Kinematics & Velocity/Acceleration `[PROJECT IMPLEMENTATION]`
Given displacement time series $\delta(t)$ (mm):
$$v_{disp}(t) = \frac{\delta(t) - \delta(t-\Delta t)}{\Delta t} \quad (\text{mm/h})$$
$$a_{disp}(t) = \frac{v_{disp}(t) - v_{disp}(t-\Delta t)}{\Delta t} \quad (\text{mm/h}^2)$$

Movement Trend Classification:
- **STABLE:** $a_{disp} \le 0.0$
- **INCREASING:** $0.0 < a_{disp} \le 0.5\text{ mm/h}^2$
- **ACCELERATING:** $0.5 < a_{disp} \le 2.0\text{ mm/h}^2$
- **RAPIDLY_ACCELERATING:** $a_{disp} > 2.0\text{ mm/h}^2$

---

## 10. Dynamic Risk Score Index `[PROJECT IMPLEMENTATION]`
The unified risk score $Risk(t) \in [0.0, 1.0]$ combines factor of safety degradation, displacement acceleration, saturation level, and antecedent rainfall ratio:

$$Risk(t) = w_1 \cdot \text{Risk}_{Fs}(F_s) + w_2 \cdot \text{Risk}_{accel}(a_{disp}) + w_3 \cdot S_w(t) + w_4 \cdot \text{Rainfall\_Factor}$$

where:
$$\text{Risk}_{Fs}(F_s) = \begin{cases} 1.0 & F_s \le 1.0 \\ 1.0 - \frac{F_s - 1.0}{0.8} & 1.0 < F_s \le 1.8 \\ 0.0 & F_s > 1.8 \end{cases}$$

Risk Level Categorization:
- `0.00 – 0.25`: **LOW**
- `0.25 – 0.50`: **MODERATE**
- `0.50 – 0.75`: **HIGH**
- `0.75 – 1.00`: **CRITICAL**
