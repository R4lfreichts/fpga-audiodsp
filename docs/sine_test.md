# I2S Sinus-Test

## Ziel
Erster Funktionstest des Pmod I2S2 DAC über einen in der PL erzeugten Sinuston.

## Aufbau
- Board Digilent Cora Z7-07S
- DACADC Pmod I2S2
- Eingangstakt 125 MHz
- erzeugter MCLK ca. 11.289 MHz

## Implementierung
- I2S-Takterzeugung über `i2s_transceiver`
- Sinus-LUT mit 16 Samples
- Ausgabe identischer Daten auf linken und rechten Kanal

## Erwartete Frequenz
fs = MCLK  256 ≈ 44.1 kHz  
f_ton = fs  16 ≈ 2.756 kHz

## Messung
Mit Smartphone-Spektrumanalyse wurde ein Peak bei ca. 2755.6 Hz gemessen.

## Ergebnis
I2S-Sender, Takterzeugung und DAC-Ansteuerung funktionieren.