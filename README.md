# Wichtig für GitHub:

- git status
- git add .
- git commit -m "Kurz und konkret beschreiben, was du geändert hast"
- git push


# FPGA Audio DSP

Dieses Projekt beschäftigt sich mit der Entwicklung einer digitalen Audiokette
auf Basis eines Zynq-SoC (Digilent Cora Z7). Ziel ist es, eine vollständige
Audiopipeline zu implementieren, die digitale Audiodaten über eine
I²S-Schnittstelle an einen externen DAC überträgt und später um
DSP-Funktionen erweitert wird.

Das Projekt wird im Rahmen der Veranstaltung **Hardware/Software-Codesign**
an der OTH Regensburg durchgeführt.

---

# Hardware

Verwendete Komponenten:

- Digilent **Cora Z7-07S**
- **Pmod I2S2** Audio DAC/ADC
- Lautsprecher oder Kopfhörer
- optional Line-In Quelle (z. B. Smartphone)

---

# Projektziele

Die Entwicklung erfolgt schrittweise:

1. **Sinus-Testsignal**
   - Generierung eines Sinussignals im FPGA
   - Ausgabe über I²S zum DAC
   - Verifikation der Audiokette

2. **WAV-Wiedergabe**
   - Audiodatei wird im Processing System gespeichert
   - PCM-Samples werden an die Programmable Logic übertragen
   - Ausgabe über I²S

3. **Audioformat-Vergleich**
   - Vergleich verschiedener Abtastraten (z. B. 48 kHz, 96 kHz)
   - Vergleich unterschiedlicher Bitauflösungen
   - Bewertung von Audioqualität und Systemlast

4. **Bypass-Modus**
   - Eingangssignal vom ADC
   - Weiterleitung zum DAC in Echtzeit

5. **DSP-Effekte**
   - Lautstärkeregelung
   - einfache Filter
   - mögliche Erweiterungen (Delay, Distortion, EQ)

---

# Projektstruktur

fpga-audiodsp
│
├── docs/ Dokumentation und Projektbericht
├── hw/
│ ├── rtl/ VHDL/Verilog Quellcode
│ ├── constraints/ Board Constraints (XDC)
│ ├── tb/ Testbenches
│ └── scripts/ Vivado TCL Skripte
│
├── sw/ Software für das Processing System
│
├── audio/ Test-Audiodateien
│
└── measurements/ Messergebnisse und Tests

---

# Entwicklungsumgebung

- **Vivado**
- **Vitis**
- VHDL

---

# Status

Aktueller Entwicklungsstand:

- I²S-Sender implementiert
- Sinus-Testsignal erzeugt
- DAC-Ausgabe über Pmod I2S2 erfolgreich getestet

---

# Autor

Ralf Höchtl  
OTH Regensburg  
Elektro- und Informationstechnik
