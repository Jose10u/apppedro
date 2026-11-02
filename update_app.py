import zipfile
import re
import os

# 1. Read pedroapp3_backup.mlapp
with zipfile.ZipFile(r'C:\Users\A515-45-R5HM\Downloads\App\pedroapp3_backup.mlapp', 'r') as z_in:
    doc_xml = z_in.read('matlab/document.xml').decode('utf-8', errors='ignore')

# 2. Extract original code
m = re.search(r'<!\[CDATA\[(.*?)\]\]>', doc_xml, re.DOTALL)
orig_code = m.group(1)

# 3. Add vertablasbutton to properties matching user's exact name
prop_pattern = r'(ComenzarButton\s+matlab\.ui\.control\.Button)'
new_prop = r'\1\n        vertablasbutton                 matlab.ui.control.Button'
orig_code = re.sub(prop_pattern, new_prop, orig_code)

# 4. New Callbacks
callbacks_code = """        % Button pushed function: ComenzarButton
        function ComenzarButtonPushed(app, ~)

            % =========================================================================
            % 1. LECTURA Y VALIDACION DE PARAMETROS (RNF1)
            % =========================================================================
            esquema = app.EsquemadeModulacionDropDown.Value;
            alpha   = app.FactordeRolloffEditField.Value;
            Rs      = app.TasadeSimboloEditField.Value;
            fc      = app.FrecuenciadePortadoraEditField.Value;
            M       = app.OrdendeModulacinEditField.Value;

            % Validacion: Valores no vacios ni NaN
            if isempty(alpha) || isnan(alpha) || isempty(Rs) || isnan(Rs) || ...
               isempty(fc) || isnan(fc) || isempty(M) || isnan(M)
                uialert(app.UIFigure, 'Todos los campos de entrada deben tener un valor numerico valido.', 'Error de Parametro');
                return;
            end

            % Validacion: Factor de Roll-off (0 <= alpha <= 1)
            if alpha < 0 || alpha > 1
                uialert(app.UIFigure, 'El factor de Roll-off debe estar en el intervalo [0, 1].', 'Error de Parametro');
                return;
            end

            % Validacion: Tasa de Simbolo y Frecuencia de Portadora
            if Rs <= 0
                uialert(app.UIFigure, 'La Tasa de Simbolo (Rs) debe ser estrictamente mayor a 0.', 'Error de Parametro');
                return;
            end
            if fc < 0
                uialert(app.UIFigure, 'La Frecuencia de Portadora (fc) debe ser mayor o igual a 0.', 'Error de Parametro');
                return;
            end

            % Validacion: Orden de Modulacion M entero >= 2
            if M < 2 || mod(M, 1) ~= 0
                uialert(app.UIFigure, 'El orden de modulacion M debe ser un numero entero >= 2.', 'Error de Parametro');
                return;
            end

            k = log2(M); % Bits por simbolo
            if mod(k, 1) ~= 0
                uialert(app.UIFigure, 'El orden M debe ser una potencia de 2 (ej. 2, 4, 8, 16, 64).', 'Error de Parametro');
                return;
            end

            if strcmp(esquema, 'M-QAM')
                sqrtM = sqrt(M);
                if mod(sqrtM, 1) ~= 0
                    uialert(app.UIFigure, 'Para modulacion M-QAM cuadrada, el orden M debe tener raiz entera (ej. 4, 16, 64, 256).', 'Error de Parametro');
                    return;
                end
            end

            % =========================================================================
            % 2. PARAMETROS DE SIMULACION Y CONTROL DE ALIASING (RNF3)
            % =========================================================================
            rng(42);                % Reproducibilidad de resultados (RNF3)
            numSymbols = 3000;      % Cantidad de simbolos a simular
            span = 8;               % Duracion del filtro SRRC en simbolos

            % Muestras por simbolo dinamicas para satisfacer Nyquist en pasa banda
            BW_aprox = Rs * (1 + alpha);
            Fs_min = max(16 * Rs, 4 * (fc + BW_aprox / 2));
            sps = min(64, max(16, ceil(Fs_min / Rs)));
            Fs  = Rs * sps;         % Frecuencia de muestreo global

            snr_dB = 18;            % Relacion Senal a Ruido (dB) simulada en canal

            % =========================================================================
            % 3. MAPEO DIGITAL MANUAL (SIN pammod, pskmod, qammod - CUMPLE RNF2)
            % =========================================================================
            dataBits = randi([0, M - 1], numSymbols, 1);

            switch esquema
                case 'M-PAM'
                    % Constelacion 1D centrada
                    C = 2 * (0 : M - 1) - (M - 1);
                    Es_teorica = (M^2 - 1) / 3;
                    symbols = 2 * dataBits - (M - 1);

                case 'M-PSK'
                    % Constelacion 2D circular de radio unitario
                    fases = 2 * pi * (0 : M - 1) / M + (pi / M);
                    C = cos(fases) + 1i * sin(fases);
                    Es_teorica = 1;
                    theta = 2 * pi * dataBits / M + (pi / M);
                    symbols = cos(theta) + 1i * sin(theta);

                case 'M-QAM'
                    % Constelacion 2D rectangular (M_pam x M_pam)
                    M_pam = round(sqrt(M));
                    Es_teorica = 2 * (M - 1) / 3;

                    data_I = mod(dataBits, M_pam);
                    data_Q = floor(dataBits / M_pam);
                    I = 2 * data_I - (M_pam - 1);
                    Q = 2 * data_Q - (M_pam - 1);
                    symbols = I + 1i * Q;

                    % Constelacion teorica ordenada de m = 0 : M-1
                    m_vec = (0 : M - 1).';
                    c_I = 2 * mod(m_vec, M_pam) - (M_pam - 1);
                    c_Q = 2 * floor(m_vec / M_pam) - (M_pam - 1);
                    C = (c_I + 1i * c_Q).';
            end

            % =========================================================================
            % 4. CONFORMACION DE PULSOS: SRRC MANUAL (SIN rcosdesign ni upfirdn)
            % =========================================================================
            t_filtro = (-span * sps / 2 : span * sps / 2)' / sps;
            h = zeros(size(t_filtro));
            for i = 1:length(t_filtro)
                tau = t_filtro(i);
                if tau == 0
                    h(i) = 1 - alpha + (4 * alpha / pi);
                elseif alpha > 0 && abs(abs(tau) - 1 / (4 * alpha)) < 1e-5
                    h(i) = (alpha / sqrt(2)) * ((1 + 2/pi) * sin(pi / (4 * alpha)) + (1 - 2/pi) * cos(pi / (4 * alpha)));
                else
                    den = pi * tau * (1 - (4 * alpha * tau)^2);
                    if abs(den) < 1e-10
                        h(i) = (alpha / sqrt(2)) * ((1 + 2/pi) * sin(pi / (4 * alpha)) + (1 - 2/pi) * cos(pi / (4 * alpha)));
                    else
                        num = sin(pi * tau * (1 - alpha)) + 4 * alpha * tau * cos(pi * tau * (1 + alpha));
                        h(i) = num / den;
                    end
                end
            end
            h = h / sqrt(sum(h.^2)); % Normalizacion de energia unitaria

            % Sobremuestreo insertando ceros (equivalente a upsample)
            upsampled = zeros(numSymbols * sps, 1);
            upsampled(1 : sps : end) = symbols;

            % Filtrado conformador en transmision (Banda Base)
            txSignalBB = conv(upsampled, h, 'same');

            % =========================================================================
            % 5. MODULACION ANALOGICA A PASABANDA Y CANAL AWGN (SIN awgn())
            % =========================================================================
            t = (0 : length(txSignalBB) - 1)' / Fs;

            if fc > 0
                % Modulador I/Q pasabanda
                txSignalPB = real(txSignalBB) .* (sqrt(2) * cos(2 * pi * fc * t)) - ...
                             imag(txSignalBB) .* (sqrt(2) * sin(2 * pi * fc * t));
            else
                txSignalPB = real(txSignalBB);
            end

            potenciaModulada = mean(txSignalPB.^2);

            % Canal Gaussiano termico manual (AWGN)
            snr_lin = 10^(snr_dB / 10);
            potenciaRuido = potenciaModulada / snr_lin;
            ruido = sqrt(potenciaRuido) * randn(size(txSignalPB));

            rxSignalPB = txSignalPB + ruido;

            % =========================================================================
            % 6. DEMODULACION ANALOGICA, FILTRADO ADAPTADO Y DECISOR (OBJETIVO 2)
            % =========================================================================
            if fc > 0
                rx_I_raw = rxSignalPB .* (sqrt(2) * cos(2 * pi * fc * t));
                rx_Q_raw = -rxSignalPB .* (sqrt(2) * sin(2 * pi * fc * t));
                rxBB_raw = rx_I_raw + 1i * rx_Q_raw;
            else
                rxBB_raw = rxSignalPB;
            end

            % Filtrado adaptado en recepcion (elimina armonicos 2*fc y completa RC)
            rxSignalBB = conv(rxBB_raw, h, 'same');

            % Muestreo en instante optimo de decision (centro de cada simbolo)
            k_start = span + 1;
            k_end = numSymbols - span;
            idxValidos = ((k_start - 1) * sps + 1) : sps : ((k_end - 1) * sps + 1);
            rxSymbols = rxSignalBB(idxValidos);

            % Decisor de Minima Distancia Euclidea (Detector ML - Objetivo 2)
            distancias = abs(rxSymbols(:) - C(:).').^2;
            [~, idxMin] = min(distancias, [], 2);
            simbolosDecididos = idxMin - 1;

            % Validacion del decisor: Tasa de Error de Simbolo (SER) simulada
            txDataValidos = dataBits(k_start : k_end);
            serSimulada = mean(simbolosDecididos(:) ~= txDataValidos(:));
            fprintf('Simulacion finalizada con exito. SER medida = %.4e\\n', serSimulada);

            % =========================================================================
            % 7. METRICAS DEL SISTEMA (RF4)
            % =========================================================================
            eficiencia = k / (1 + alpha);
            anchoBanda  = Rs * (1 + alpha);

            app.EficienciaEspectralEditField.Value        = round(eficiencia, 4);
            app.AnchodeBandaEditField.Value               = round(anchoBanda, 2);
            app.EnergiadeSimboloEditField.Value           = round(Es_teorica, 4);
            app.PotenciadelaSealModuladaEditField.Value   = round(potenciaModulada, 4);

            % =========================================================================
            % 8. RENDERIZADO DE LAS 5 GRAFICAS (RF3)
            % =========================================================================

            % --- a. Diagrama del Ojo en RECEPCION (RF3.a) ---
            rxEyeSignal = real(rxSignalBB(span * sps + 1 : end - span * sps));
            samplesPerTrace = 2 * sps;
            numTraces = min(150, floor(length(rxEyeSignal) / samplesPerTrace) - 1);
            eyeMatrix = zeros(samplesPerTrace, numTraces);
            for i = 1:numTraces
                idx = (i - 1) * sps + (1 : samplesPerTrace);
                eyeMatrix(:, i) = rxEyeSignal(idx);
            end
            t_eye = ((0 : samplesPerTrace - 1)' / Fs) * 1000; % ms

            cla(app.UIAxesOjo);
            plot(app.UIAxesOjo, t_eye, eyeMatrix, 'Color', [0 0.447 0.741 0.25], 'LineWidth', 0.8);
            grid(app.UIAxesOjo, 'on');
            title(app.UIAxesOjo, 'Diagrama del Ojo en Recepcion');
            xlabel(app.UIAxesOjo, 'Tiempo (ms)');
            ylabel(app.UIAxesOjo, 'Amplitud');

            % --- b. Diagrama de Constelacion en Recepcion (RF3.b) ---
            cla(app.UIAxesConstelacion);
            hold(app.UIAxesConstelacion, 'on');
            plot(app.UIAxesConstelacion, real(rxSymbols), imag(rxSymbols), '.', 'Color', [0 0.447 0.741], 'MarkerSize', 6);
            plot(app.UIAxesConstelacion, real(C), imag(C), 'rx', 'MarkerSize', 10, 'LineWidth', 2);
            hold(app.UIAxesConstelacion, 'off');
            grid(app.UIAxesConstelacion, 'on');
            title(app.UIAxesConstelacion, 'Diagrama de Constelacion en Recepcion');
            xlabel(app.UIAxesConstelacion, 'En Fase (I)');
            ylabel(app.UIAxesConstelacion, 'Cuadratura (Q)');
            legend(app.UIAxesConstelacion, {'Simbolos Recibidos', 'Puntos Ideales'}, 'Location', 'best');

            % --- c. Curva de Desempeno BER vs Eb/N0 (RF3.c) (SIN qfunc) ---
            ebnoVec = 0:1:14;
            ebnoLin = 10.^(ebnoVec / 10);
            q_fun = @(x) 0.5 * erfc(x / sqrt(2)); % Funcion Q nativa con erfc

            switch esquema
                case 'M-PAM'
                    berTeorica = (2 * (M - 1) / (M * k)) * q_fun(sqrt((6 * k / (M^2 - 1)) * ebnoLin));
                case 'M-PSK'
                    if M == 2 || M == 4
                        berTeorica = q_fun(sqrt(2 * ebnoLin));
                    else
                        berTeorica = (2 / k) * q_fun(sqrt(2 * k * ebnoLin) * sin(pi / M));
                    end
                case 'M-QAM'
                    berTeorica = (4 / k) * (1 - 1 / sqrt(M)) * q_fun(sqrt((3 * k / (M - 1)) * ebnoLin));
            end

            cla(app.UIAxesDesempeno);
            semilogy(app.UIAxesDesempeno, ebnoVec, berTeorica, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            grid(app.UIAxesDesempeno, 'on');
            title(app.UIAxesDesempeno, 'Curva de Desempeno (BER vs E_b/N_0)');
            xlabel(app.UIAxesDesempeno, 'E_b/N_0 (dB)');
            ylabel(app.UIAxesDesempeno, 'BER Teorica');
            ylim(app.UIAxesDesempeno, [1e-7, 1]);

            % --- d. Espectro Banda Base Transmisor (RF3.d) (SIN periodogram) ---
            Nfft = 2048;
            L = min(Nfft, length(txSignalBB));
            w = 0.5 * (1 - cos(2 * pi * (0 : L - 1)' / (L - 1))); % Ventana de Hanning manual

            X_BB = fft(txSignalBB(1:L) .* w, Nfft);
            psd_BB = (abs(fftshift(X_BB)).^2) / (Fs * sum(w.^2));
            f_BB = linspace(-Fs / 2, Fs / 2, Nfft);

            cla(app.UIAxesBandaTransmisor);
            plot(app.UIAxesBandaTransmisor, f_BB / 1000, 10 * log10(psd_BB + eps), 'b', 'LineWidth', 1.2);
            grid(app.UIAxesBandaTransmisor, 'on');
            title(app.UIAxesBandaTransmisor, 'Espectro Banda Base Tx');
            xlabel(app.UIAxesBandaTransmisor, 'Frecuencia (kHz)');
            ylabel(app.UIAxesBandaTransmisor, 'PSD (dB/Hz)');

            % --- e. Espectro Pasa Banda Recepcion (RF3.d) (SIN periodogram) ---
            X_PB = fft(rxSignalPB(1:L) .* w, Nfft);
            psd_PB = (abs(fftshift(X_PB)).^2) / (Fs * sum(w.^2));
            f_PB = linspace(-Fs / 2, Fs / 2, Nfft);

            cla(app.UIAxesBandaRecepcion);
            plot(app.UIAxesBandaRecepcion, f_PB / 1000, 10 * log10(psd_PB + eps), 'm', 'LineWidth', 1.2);
            grid(app.UIAxesBandaRecepcion, 'on');
            title(app.UIAxesBandaRecepcion, 'Espectro Pasa Banda Rx');
            xlabel(app.UIAxesBandaRecepcion, 'Frecuencia (kHz)');
            ylabel(app.UIAxesBandaRecepcion, 'PSD (dB/Hz)');

        end

        % Button pushed function: vertablasbutton
        function vertablasbuttonButtonPushed(~, ~)

            % Crear ventana modal/emergente para la tabla y el analisis
            figTabla = uifigure('Name', 'Analisis y Resultados: Tabla Eb/N0 vs BER (Punto 4)', ...
                                'Position', [150 150 900 440], ...
                                'Color', [0.94 0.94 0.96]);

            % Titulo superior
            uilabel(figTabla, ...
                'Text', 'Diferencia de valores Eb/N0 para cada par de esquemas (4-PAM, 4-QAM, 4-PSK)', ...
                'FontSize', 15, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Position', [20 395 860 30]);

            % Calculo teorico exacto con erfcinv nativo (cumple RNF2 sin toolboxes)
            bers = [1e-2; 1e-3; 1e-4; 1e-5; 1e-6; 1e-7];
            ber_labels = {'10^-2'; '10^-3'; '10^-4'; '10^-5'; '10^-6'; '10^-7'};

            % 4-PSK y 4-QAM:
            ebno_qam_lin = (erfcinv(2 * bers)).^2;
            ebno_qam_db  = 10 * log10(ebno_qam_lin);

            % 4-PAM:
            ebno_pam_lin = 2.5 * (erfcinv((8/3) * bers)).^2;
            ebno_pam_db  = 10 * log10(ebno_pam_lin);

            diff_pam_qam = ebno_pam_db - ebno_qam_db;
            diff_psk_qam = zeros(size(bers));
            diff_qam_pam = ebno_qam_db - ebno_pam_db;

            % Formatear datos de la tabla
            tableData = cell(length(bers), 6);
            for idx = 1:length(bers)
                tableData{idx, 1} = ber_labels{idx};
                tableData{idx, 2} = sprintf('%.2f dB', ebno_pam_db(idx));
                tableData{idx, 3} = sprintf('%.2f dB', ebno_qam_db(idx));
                tableData{idx, 4} = sprintf('%+.2f dB', diff_pam_qam(idx));
                tableData{idx, 5} = sprintf('%+.2f dB', diff_psk_qam(idx));
                tableData{idx, 6} = sprintf('%+.2f dB', diff_qam_pam(idx));
            end

            colNames = {'BER', '4-PAM', '4-QAM / 4-PSK', '4PAM - 4QAM', '4PSK - 4QAM', '4QAM - 4PAM'};

            % Crear la uitable solicitada en el Punto 4 de Condiciones de Entrega
            uitable(figTabla, ...
                'Data', tableData, ...
                'ColumnName', colNames, ...
                'Position', [25 45 520 335], ...
                'FontSize', 12, ...
                'RowName', []);

            % Ejes para visualizar las curvas comparativas solicitadas en el PDF
            axComp = uiaxes(figTabla);
            axComp.Position = [565 55 310 325];
            grid(axComp, 'on');

            ebnoVec = 0:0.25:16;
            ebnoLin = 10.^(ebnoVec / 10);
            q_fun = @(x) 0.5 * erfc(x / sqrt(2));

            ber_4pam_curve = (3/4) * q_fun(sqrt(0.8 * ebnoLin));
            ber_4qam_curve = q_fun(sqrt(2 * ebnoLin));

            semilogy(axComp, ebnoVec, ber_4pam_curve, 'b-', 'LineWidth', 1.8, 'DisplayName', '4-PAM');
            hold(axComp, 'on');
            semilogy(axComp, ebnoVec, ber_4qam_curve, 'r--', 'LineWidth', 1.8, 'DisplayName', '4-QAM / 4-PSK');
            hold(axComp, 'off');

            title(axComp, 'Curvas Comparativas BER vs Eb/N0');
            xlabel(axComp, 'E_b/N_0 (dB)');
            ylabel(axComp, 'BER');
            ylim(axComp, [1e-7, 1]);
            xlim(axComp, [0, 16]);
            legend(axComp, 'Location', 'southwest');

        end"""

# 5. Replace callback in code
pattern = r'(\s*% Button pushed function: ComenzarButton\s+function ComenzarButtonPushed\(app, .*?\).*?end\s+)(end\s+% Component initialization)'
new_code = re.sub(pattern, lambda m: '\n' + callbacks_code + '\n    ' + m.group(2), orig_code, flags=re.DOTALL)

# 6. Add vertablasbutton creation to createComponents
btn_creation_pattern = r'(app\.ComenzarButton\.Text = \'Comenzar\';)'
new_btn_creation = r"""\1

            % Create vertablasbutton
            app.vertablasbutton = uibutton(app.UIFigure, 'push');
            app.vertablasbutton.ButtonPushedFcn = createCallbackFcn(app, @vertablasbuttonButtonPushed, true);
            app.vertablasbutton.Position = [101 332 100 22];
            app.vertablasbutton.Text = 'Tablas';"""

new_code = re.sub(btn_creation_pattern, new_btn_creation, new_code)

# 7. Clean special characters in createComponents
new_code = new_code.replace("Diagrama del ojo en Recepcionepción", "Diagrama del ojo en Recepcion")
new_code = new_code.replace("Diagrama del ojo en Recepcionepcin", "Diagrama del ojo en Recepcion")

# Clean all non-ascii characters
replacements = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
    'ñ': 'n', 'Ñ': 'N'
}
for k, v in replacements.items():
    new_code = new_code.replace(k, v)

# Ensure pure ascii
new_code = ''.join(c if ord(c) < 128 else '' for c in new_code)

# 8. Save standalone pedroapp3.m
with open(r'C:\Users\A515-45-R5HM\Downloads\App\pedroapp3.m', 'w', encoding='ascii') as f:
    f.write(new_code)

# 9. Update document.xml and write pedroapp3.mlapp
cdata_start = doc_xml.find('<![CDATA[') + len('<![CDATA[')
cdata_end = doc_xml.find(']]>', cdata_start)
new_doc_xml = doc_xml[:cdata_start] + new_code + doc_xml[cdata_end:]

with zipfile.ZipFile(r'C:\Users\A515-45-R5HM\Downloads\App\pedroapp3_backup.mlapp', 'r') as z_in:
    with zipfile.ZipFile(r'C:\Users\A515-45-R5HM\Downloads\App\pedroapp3.mlapp', 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
        for item in z_in.infolist():
            if item.filename == 'matlab/document.xml':
                z_out.writestr(item, new_doc_xml.encode('ascii'))
            else:
                z_out.writestr(item, z_in.read(item.filename))

print("Build complete: updated with vertablasbuttonButtonPushed!")
