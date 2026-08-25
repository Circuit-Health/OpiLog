# OpiLog

An offline-first, client-side personal health record utility for logging opioid analgesics and calculating historical **oral Morphine Equivalent Daily Dose (oMEDD)** exposure over rolling **1-, 3-, and 7-day** windows.

Built with **Elm 0.19.1**, **TypeScript**, **Vite**, and **Capacitor SQLite**.

---

## Overview

Most medication trackers log raw milligram amounts without standardizing across different opioid potencies. Clinical calculators, on the other hand, only provide static, single-point calculations.

**OpiLog** bridges this gap by functioning as a descriptive exposure log:
* **Bolus & PRN Tracking:** Logs oral and sublingual doses with instant equianalgesic conversion.
* **Continuous Transdermal Delivery:** Accurately attributes hourly release rates for patches (e.g., Buprenorphine, Fentanyl) across active time spans rather than treating them as single lump-sum events.
* **Rolling Window Aggregation:** Computes rolling **24-hour total**, **3-day daily average**, and **7-day daily average** to differentiate acute breakthrough spikes from true baseline dose escalation.
* **Zero Cloud Footprint:** 100% on-device SQLite storage with zero network dependencies, eliminating cloud compliance liabilities.

---

## Calculation Engine & Equianalgesic Standards

Conversions follow standard Faculty of Pain Medicine (ANZCA) equianalgesic guidelines:

### Bolus Conversions (Oral)
$$\text{oMEDD} = \text{Dose (mg)} \times \text{Conversion Factor}$$

| Drug | Route | Factor |
| :--- | :--- | :--- |
| **Oxycodone** | Oral | $\times 1.5$ |
| **Hydromorphone** | Oral | $\times 4.0$ |
| **Tapentadol** | Oral | $\times 0.3$ |
| **Codeine** | Oral | $\times 0.1$ |
| **Tramadol** | Oral | $\times 0.1\text{–}0.2$ |

### Transdermal Patches (Continuous Delivery)
Patches are modeled as active time intervals:

$$\text{oMEDD / hour} = \frac{\text{Rated Rate } (\mu\text{g/hr}) \times \text{Factor}}{24}$$

* **Buprenorphine (Norspan, 7-day):** $\text{Rated } \mu\text{g/hr} \times 2 = \text{mg/day oMEDD}$
* **Fentanyl (Durogesic, 72-hour):** $\text{Rated } \mu\text{g/hr} \times 3 = \text{mg/day oMEDD}$

Exposure within a rolling window $[T_{\text{start}}, T_{\text{end}}]$ is calculated by computing the exact overlapping wear time in hours multiplied by the hourly rate.

---

## Tech Stack

* **Frontend:** [Elm 0.19.1](https://elm-lang.org/) (Strict typing, zero runtime exceptions)
* **Build Tool:** [Vite 5](https://vitejs.dev/) + `vite-plugin-elm`
* **Interop & Bridge:** TypeScript 5
* **Native Runtime:** [Capacitor 6](https://capacitorjs.com/)
* **Persistence:** `@capacitor-community/sqlite` (Native SQLite on iOS/Android; fallback to browser storage during web development)

---

## Project Structure

```text
opilog/
├── capacitor.config.ts        # Capacitor native bridge configuration
├── elm.json                   # Elm dependencies & package setup
├── index.html                 # App shell & base layout styling
├── package.json
├── vite.config.ts             # Vite + Elm plugin bundler setup
└── src/
    ├── Calculations.elm       # Pure functional rolling window & oMEDD math
    ├── Main.elm               # Elm UI, application state, and view logic
    ├── Ports.elm              # Elm-to-JS interop port definitions
    ├── Types.elm              # Domain models (Bolus, Patch, WindowMetrics)
    └── index.ts               # TypeScript entry point & SQLite lifecycle
```

## Disclaimer

This software is designed as a descriptive logging diary and mathematical aggregation tool for patient and clinician reference. It does not provide medical advice, diagnosis, treatment, or clinical decision support. Dose adjustments or opioid tapers must always be managed directly under the supervision of a qualified medical practitioner.

## License

MIT License. See LICENSE for details.