# Digital Twin Validation Methodology
**Module:** Digital Twin Engine (Dibang Valley Landslide EWS)  

---

## 1. Validation Status Tag `[NOT YET VALIDATED]`
> [!WARNING]  
> **Status:** `NOT YET VALIDATED WITH LOCAL FIELD OBSERVATIONS`  
> 
> The calculations, hydro-mechanical formulas, and state evolution algorithms in this Digital Twin engine are derived from peer-reviewed physical literature (*Sensors 2026, 26, 421*). However, the engine has **not yet been validated against multi-year local field observations in Dibang Valley, Arunachal Pradesh**.

---

## 2. Validation Metrics Framework `[PROJECT IMPLEMENTATION]`
When field telemetry (piezometers, borehole inclinometers, rain gauges) becomes connected, the engine provides built-in metrics evaluation:

1. **Predicted vs Observed Instability Timing ($\Delta t_{fail}$):**
   $$\text{MAE}_{time} = \frac{1}{N} \sum_{i=1}^N |t_{pred, i} - t_{obs, i}|$$
2. **Pore Pressure Simulation RMSE ($RMSE_u$):**
   $$\text{RMSE}_u = \sqrt{ \frac{1}{M} \sum_{j=1}^M \left(u_{sim}(t_j) - u_{field}(t_j)\right)^2 }$$
3. **Displacement Vector Offset ($\Delta d$):**
   Evaluation of slip boundary shape similarity ($>80\%$ target per Sensors 2026 Figure 11).

---

## 3. Calibration Requirements for Field Deployment `[PROJECT IMPLEMENTATION]`
To transition from `PROTOTYPE SIMULATION` to `FIELD-VALIDATED`:
- Ingest real-time rainfall data from India Meteorological Department (IMD) / AWS stations in Dibang Valley.
- Calibrate soil cohesion $c'$ and friction angle $\phi'$ using local borehole core samples.
- Integrate GNSS deformation monitoring points along Anini-Etalin highway sections.
