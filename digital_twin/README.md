# Digital Twin Engine for Landslide Early-Warning
**Target Region:** Dibang Valley, Arunachal Pradesh, India  
**Purpose:** Analyst-Side Next Emergent Risk Prediction & Hydro-Mechanical Simulation

---

## 📌 Executive Summary
This Digital Twin engine provides a **physics-informed, scenario-based computational framework** to predict the **Next Emergent Prone Zone** surrounding an active landslide or critical risk zone in Dibang Valley.

Unlike generic proximity models, this engine simulates the **hydro-mechanical coupled response** (rainfall infiltration → soil moisture elevation → pore-water pressure buildup → effective stress reduction → shear strength degradation → displacement acceleration → instability evolution) for surrounding candidate terrain zones over temporal horizons ($t_0, t_{+1h}, t_{+3h}, t_{+6h}, t_{+12h}, t_{+24h}$).

---

## 🔬 Scientific Foundation & Research References
- **Primary Reference:** *Digital Twin Modeling for Landslide Risk Scenarios in Mountainous Regions*, **Sensors 2026, 26, 421**.
- **Coupling Mechanism:** Integrates steady-state and transient pore-fluid consolidation, Mohr-Coulomb failure criteria, and discrete physical field coupling.
- **Displacement Mutation Zone:** Reflects research findings regarding critical strain concentration near the slope toe (~0.1H height range).

---

## ⚠️ Important Scientific & Validation Disclaimer
> [!IMPORTANT]
> **Status:** `PROTOTYPE SIMULATION / NOT YET CALIBRATED WITH LOCAL FIELD OBSERVATIONS`  
> 
> The monitoring parameters and environmental inputs in this prototype module are generated from **synthetic field datasets** representing Dibang Valley conditions. This engine presents a **traceable physics-based calculation methodology**, but its prediction outputs must NOT be cited as field-validated real-world accuracy until calibrated against long-term in-situ telemetry and geotechnical borehole sampling.

---

## 📂 Module Architecture
```
digital_twin/
├── README.md
├── methodology/               # Research methodology, equations, assumptions, validation docs
│   ├── digital_twin_methodology.md
│   ├── equations.md
│   ├── assumptions.md
│   └── validation.md
├── data/                      # Synthetic input & processed datasets
│   ├── input/
│   ├── synthetic/
│   │   └── dibang_valley_zones.json
│   └── processed/
├── models/                    # Physics domain models
│   ├── terrain_state/         # Slope geometry & elevation
│   ├── rainfall/              # Intensity, duration & forecast scenarios
│   ├── hydrology/             # Infiltration, soil moisture & pore-water pressure
│   ├── geotechnical/          # Effective stress & Mohr-Coulomb shear strength
│   ├── displacement/          # Velocity, acceleration & movement trends
│   ├── instability/           # Factor of Safety & Risk Index calculation
│   └── spatial_prediction/    # Candidate search & spatial propagation
├── simulation/                # Time-series simulation engine
│   ├── scenarios/             # Scenario definitions (Baseline, Heavy Rain, etc.)
│   ├── timestep_engine/       # Temporal step-forward solver (t0 to +24h)
│   └── simulator/             # Core Digital Twin simulator orchestrator
├── prediction/                # Candidate selection, ranking & audit trail
│   ├── candidate_zones/       # Spatial neighborhood identification
│   ├── ranking/               # Emerging risk score & delta-risk ranker
│   └── traceability/          # Step-by-step physical explanation generator
├── gis/                       # Spatial GeoJSON export module
│   └── geojson/               # GeoJSON feature collection builders
├── api/                       # REST API schemas & FastAPI routes
├── validation/                # Observed vs predicted validation module
├── tests/                     # Unit & scenario integration test suite
└── outputs/                   # Generated simulation JSONs, GeoJSONs & reports
```

---

## 🚀 Quickstart Command-Line Execution
Run the standalone simulation demonstration script:
```powershell
python digital_twin/run_simulation_demo.py
```
Or run the unit tests:
```powershell
python -m unittest discover -s digital_twin/tests
```
