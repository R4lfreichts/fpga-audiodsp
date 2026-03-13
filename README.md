# Wichtig für GitHub:

- git status
- (git add .)
- git add hw/rtl/i2s_playback.vhd
- git add hw/rtl/i2s_transceiver.vhd
- git add hw/constraints/cons.xdc
- git add hw/scripts/create_project.tcl
- git add hw/scripts/create_clk_wiz.tcl
- git add .gitignore
- git add README.
- falls zu viel geadded (zum Beispiel mit . oder *): git restore --staged .
- git commit -m "Kurz und konkret beschreiben, was du geändert hast"
- git push
=> der Vorgang des pushens geht wesentlich leichter, wenn man den bitstream / die Daten an einem abgesonderten Ort abspeichert und dann die erzeugten Ordner im scripts-Verzeichnis löscht 

# Vivado-Projekt starten
Um das Vivado-Projekt aus dem GitHub-Repository zu erzeugen, müssen mit Hilfe 
der Vivado-Tcl-Konsole folgende Schritte ausgeführt werden:

Change Directory in den Ordner mit den Tcl-Skripten
- cd C:/Users/Ralf/Documents/audiodsp/hw/scripts

Testen mit print-working-directory, ob man isch im richtigen Ordner befindet
- pwd

Starten des Skriptes um das Projekt in Vivado aufzubauen
- source create_project.tcl

Um später den Ordner mit einem Commit auf GitHub pushen zu können, muss mit close_project die Konsole das Projekt verlassen
- close_project

Das create-project.tcl Skript muss mit dem fortschritt des Projektes um dessen Dateinen erweitert werden
=> regelmäßig warten!!


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

## Projektstruktur

```
fpga-audiodsp/
│
├── docs/                Dokumentation und Projektbericht
│
├── hw/                  Hardware
│   ├── rtl/             Register Transfer Level
│   │   ├── i2s/         I2S Sender / Empfänger
│   │   ├── signal_gen/  Sinusgenerator
│   │   ├── wav_player/  WAV Wiedergabe
│   │   ├── bypass/      ADC → DAC Bypass
│   │   └── effects/     DSP Effekte
│   │
│   ├── constraints/     Board Constraints (XDC)
│   ├── tb/              Testbenches
│   ├── scripts/         Vivado TCL Skripte
│   └── bitstreams/      working bitsream-files for quick loading
│
├── sw/                  Software für das Processing System
│
├── audio/               Test-Audiodateien
│
└── measurements/        Messergebnisse und Tests
```

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
