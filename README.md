# Simulador de Sistemas de Comunicaciones Digitales (M-PAM, M-PSK, M-QAM)

Aplicación desarrollada en **MATLAB App Designer** para el modelado, simulación y evaluación de desempeño de sistemas de transmisión digital en banda base y pasabanda bajo canal AWGN.

---

## 📌 Características Principales

### 1. Parámetros de Entrada Flexibles y Validados (RNF1)
- **Esquema de Modulación**: Selección interactiva entre **M-PAM**, **M-PSK** y **M-QAM**.
- **Orden de Modulación ($M$)**: Acepta cualquier potencia de 2 ($M = 2, 4, 8, 16, 64, \dots$) y potencias pares para M-QAM cuadrada ($M = 4, 16, 64, 256, 1024$).
- **Factor de Roll-off ($\alpha$)**: Rango $[0, 1]$ para el filtro conformador de pulso.
- **Tasa de Símbolo ($R_s$)** y **Frecuencia de Portadora ($f_c$)**.
- Validación robusta de entradas mediante alertas visuales (`uialert`).

### 2. Cumplimiento Estricto de Restricciones (RNF2 - Sin Toolboxes de Comunicaciones)
Todo el procesamiento digital se implementa desde fundamentos matemáticos con funciones base de MATLAB:
- **Mapeo y De-mapeo digital**: Constelaciones teóricas y cálculo de distancias euclídeas mínimas para detección por Máxima Verosimilitud (ML) sin funciones de caja negra (`pammod`, `pskmod`, `qammod`).
- **Conformación de pulsos (SRRC)**: Pulso de Coseno Alzado con Raíz Cuadrada implementado con ecuación explícita y normalización de energía unitaria (sin `rcosdesign` ni `upfirdn`).
- **Modulación analógica / Upconversion**: Modulador y demodulador I/Q en cuadratura mediante portadoras sinusoidales.
- **Canal AWGN**: Generación manual de ruido gaussiano blanco proporcional a la relación señal a ruido $E_b/N_0$ deseada (sin `awgn`).
- **Estimación espectral (PSD)**: Periodograma manual mediante FFT de 2048 puntos con ventaneo Hanning (sin `periodogram`).
- **Desempeño teórico**: Evaluación de BER teórica mediante la función de error complementaria nativa `erfc` y `erfcinv` (sin `qfunc` ni `bercoding`).

### 3. Visualización Completa (RF3)
La interfaz presenta 5 gráficas en tiempo real:
1. **Diagrama del Ojo en Recepción**: Evaluación de Interferencia Intersimbólica (ISI).
2. **Diagrama de Constelación en Recepción**: Comparación de símbolos recibidos frente a puntos ideales.
3. **Curva de Desempeño ($BER$ vs $E_b/N_0$)**: Curva teórica del esquema activo.
4. **Espectro de la Señal en Banda Base (Tx)**: Densidad espectral de potencia en transmisión.
5. **Espectro de la Señal en Pasabanda (Rx)**: Espectro modulado en torno a $f_c$.

### 4. Métricas del Sistema (RF4)
- **Eficiencia Espectral ($\eta$)** [bits/s/Hz]
- **Ancho de Banda de Transmisión ($BW$)** [Hz / kHz]
- **Energía de Símbolo ($E_s$)**
- **Potencia de la Señal Modulada ($P$)**

### 5. Módulo de Comparación Dinámica de Desempeño (Punto 4)
Al presionar el botón **Tablas**, se despliega una ventana emergente con:
- Tabla comparativa de diferencias de $E_b/N_0$ requeridas para BERs entre $10^{-2}$ y $10^{-7}$ para cada par de modulación ($[M]\text{PAM}-[M]\text{QAM}$, $[M]\text{PSK}-[M]\text{QAM}$, $[M]\text{QAM}-[M]\text{PAM}$).
- Gráfica comparativa simultánea de las curvas teóricas para $M$-PAM, $M$-QAM y $M$-PSK adaptadas al orden $M$ seleccionado.

---

## 🚀 Cómo Ejecutar la Aplicación

1. Abrir MATLAB (versión R2021a o superior recomendada).
2. Abrir la carpeta del proyecto en MATLAB o agregarla al `Path`.
3. Ejecutar en la ventana de comandos:
   ```matlab
   pedroapp4
   ```
   o bien, hacer doble clic sobre `pedroapp4.mlapp` para abrirla en App Designer y presionar **Run**.
4. Ingresar los parámetros deseados y presionar **Comenzar** para simular, o **Tablas** para el análisis comparativo.

---

## 📁 Estructura del Repositorio

- `pedroapp4.mlapp`: Archivo principal de la aplicación en MATLAB App Designer.
- `pedroapp4.m`: Código fuente exportado de la aplicación en texto plano para fácil lectura y control de versiones.
- `pedroapp3.mlapp` / `pedroapp3.m`: Versiones de desarrollo previas.
- `REQUERIMIENTOS PROYECTO II.pdf`: Documento de especificación de requerimientos del proyecto.
