# 天线模型

## 天线索引和位置对应关系

对于 4 * 4 * 2 （行 * 列 * 极化数）的天线阵列，其天线索引（1:32）对应：
```
07(08) 15(16) 23(24) 31(32)
05(06) 13(14) 21(22) 29(30)
03(04) 11(12) 19(20) 27(28)
01(02) 09(10) 17(18) 25(26)
```

## 天线模型可选项

### 3gpp
An antenna with a custom gain in elevation and azimuth. See. 3GPP TR 36.873 V12.7.0 (2017-12),
Table 7.1-1, Page 18
* Ain - Half-Power in azimuth direction (phi_3dB), default = 65 deg
* Bin - Half-Power in elevation direction (theta_3dB), default = 65 deg
* Cin - Side-lobe attenuation in vertical cut (SLA_v), default = 30 dB
* Din - Maximum attenuation (A_m), default = 30 dB
* Ein - Antenna gain in dBi (G_dBi), default = 8 dBi
 
### 3gpp-3d
The antenna model for the 3GPP-3D channel model (TR 36.873, v12.5.0, pp.17).
* Ain - Number of vertical elements (M)
* Bin - Number of horizontal elements (N)
* Cin - The center frequency in [Hz]
* Din - Polarization indicator
    1. K=1, vertical polarization only
    2. K=1, H/V polarized elements
    3. K=1, +/-45 degree polarized elements
    4. K=M, vertical polarization only
    5. K=M, H/V polarized elements
    6. K=M, +/-45 degree polarized elements
* Ein - The electric downtilt angle in [deg] for Din = 4,5,6
* Fin - Element spacing in [λ], Default: 0.5
 
### 3gpp-mmw
Antenna model for the 3GPP-mmWave channel model (TR 38.901, v14.1.0, pp.21). The parameters
"Ain" - "Fin" are identical to the above model for the "3gpp-3d" channel model. Additional
parameters are:
* Gin - Number of nested panels in a column (Mg)
* Hin - Number of nested panels in a row (Ng)
* Iin - Panel spacing in vertical direction (dg,V) in [λ], Default: 0.5 M
* Jin - Panel spacing in horizontal direction (dg,H) in [λ], Default: 0.5 N
