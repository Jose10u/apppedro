classdef pedroapp3 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        OrdendeModulacinEditField       matlab.ui.control.NumericEditField
        OrdendeModulacinEditFieldLabel  matlab.ui.control.Label
        FrecuenciadePortadoraEditField  matlab.ui.control.NumericEditField
        FrecuenciadePortadoraLabel      matlab.ui.control.Label
        TasadeSimboloEditField          matlab.ui.control.NumericEditField
        TasadeSimboloLabel              matlab.ui.control.Label
        ComenzarButton                  matlab.ui.control.Button
        vertablasbutton                 matlab.ui.control.Button
        PotenciadelaSealModuladaEditField  matlab.ui.control.NumericEditField
        PotenciadelaSealModuladaEditFieldLabel  matlab.ui.control.Label
        AnchodeBandaEditField           matlab.ui.control.NumericEditField
        AnchodeBandaEditFieldLabel      matlab.ui.control.Label
        EnergiadeSimboloEditField       matlab.ui.control.NumericEditField
        EnergiadeSimboloLabel           matlab.ui.control.Label
        EficienciaEspectralEditField    matlab.ui.control.NumericEditField
        EficienciaEspectralLabel        matlab.ui.control.Label
        FactordeRolloffEditFieldLabel   matlab.ui.control.Label
        FactordeRolloffEditField        matlab.ui.control.NumericEditField
        EsquemadeModulacionDropDown     matlab.ui.control.DropDown
        EsquemadeModulacionLabel        matlab.ui.control.Label
        UIAxesBandaRecepcion            matlab.ui.control.UIAxes
        UIAxesBandaTransmisor           matlab.ui.control.UIAxes
        UIAxesDesempeno                 matlab.ui.control.UIAxes
        UIAxesConstelacion              matlab.ui.control.UIAxes
        UIAxesOjo                       matlab.ui.control.UIAxes
    end

    % Callbacks that handle component events
    methods (Access = private)
        % Button pushed function: ComenzarButton
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
            fprintf('Simulacion finalizada con exito. SER medida = %.4e\n', serSimulada);

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
        function vertablasbuttonButtonPushed(app, ~)

            % 1. Leer el orden de modulacion M configurado en la app
            M = app.OrdendeModulacinEditField.Value;

            % Si el usuario aun no ingresa un valor valido, se toma M = 4 por defecto (como en la guia)
            if isempty(M) || isnan(M) || M < 4 || mod(sqrt(M), 1) ~= 0
                M = 4;
            end

            k = log2(M);

            % 2. Crear ventana emergente de analisis
            figTabla = uifigure('Name', sprintf('Analisis y Resultados (Punto 4 - M = %d)', M), ...
                                'Position', [150 150 900 440], ...
                                'Color', [0.94 0.94 0.96]);

            % Titulo superior dinamico
            uilabel(figTabla, ...
                'Text', sprintf('Diferencia de los valores EbNo para cada par de esquemas de modulacion (M = %d)', M), ...
                'FontSize', 15, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Position', [20 395 860 30]);

            % 3. Calculo teorico exacto con erfcinv nativo (cumple RNF2 sin toolboxes)
            bers = [1e-2; 1e-3; 1e-4; 1e-5; 1e-6; 1e-7];
            ber_labels = {'10^-2'; '10^-3'; '10^-4'; '10^-5'; '10^-6'; '10^-7'};

            % M-PAM:
            arg_pam = bers * M * k / (M - 1);
            ebno_pam_lin = ((M^2 - 1) / (3 * k)) * (erfcinv(arg_pam)).^2;
            ebno_pam_db  = 10 * log10(ebno_pam_lin);

            % M-QAM:
            arg_qam = bers * k / (2 * (1 - 1/sqrt(M)));
            ebno_qam_lin = ((2 * (M - 1)) / (3 * k)) * (erfcinv(arg_qam)).^2;
            ebno_qam_db  = 10 * log10(ebno_qam_lin);

            % M-PSK:
            if M == 2 || M == 4
                arg_psk = 2 * bers;
                ebno_psk_lin = (erfcinv(arg_psk)).^2;
            else
                arg_psk = bers * k;
                ebno_psk_lin = (1 / (k * (sin(pi / M))^2)) * (erfcinv(arg_psk)).^2;
            end
            ebno_psk_db = 10 * log10(ebno_psk_lin);

            % Diferencias de desempeno solicitadas en la guia (Punto 4)
            diff_pam_qam = ebno_pam_db - ebno_qam_db;
            diff_psk_qam = ebno_psk_db - ebno_qam_db;
            diff_qam_pam = ebno_qam_db - ebno_pam_db;

            % Nombres de columnas dinamicos segun el M actual
            strPAM_QAM = sprintf('%dPAM-%dQAM', M, M);
            strPSK_QAM = sprintf('%dPSK-%dQAM', M, M);
            strQAM_PAM = sprintf('%dQAM-%dPAM', M, M);
            colNames   = {'BER', strPAM_QAM, strPSK_QAM, strQAM_PAM};

            % Formatear datos de la tabla con signos claros
            tableData = cell(length(bers), 4);
            for idx = 1:length(bers)
                tableData{idx, 1} = ber_labels{idx};
                tableData{idx, 2} = sprintf('%+.2f dB', diff_pam_qam(idx));
                tableData{idx, 3} = sprintf('%+.2f dB', diff_psk_qam(idx));
                tableData{idx, 4} = sprintf('%+.2f dB', diff_qam_pam(idx));
            end

            % Crear la uitable
            uitable(figTabla, ...
                'Data', tableData, ...
                'ColumnName', colNames, ...
                'Position', [30 55 450 325], ...
                'FontSize', 12, ...
                'RowName', []);

            % 4. Grafica comparativa de curvas BER vs Eb/N0
            axComp = uiaxes(figTabla);
            axComp.Position = [510 55 360 325];
            grid(axComp, 'on');

            max_db = max(16, ceil(max(ebno_pam_db) + 2));
            ebnoVec = 0:0.25:max_db;
            ebnoLin = 10.^(ebnoVec / 10);
            q_fun   = @(x) 0.5 * erfc(x / sqrt(2));

            ber_pam_curve = (2 * (M - 1) / (M * k)) * q_fun(sqrt((6 * k / (M^2 - 1)) * ebnoLin));
            ber_qam_curve = (4 / k) * (1 - 1 / sqrt(M)) * q_fun(sqrt((3 * k / (M - 1)) * ebnoLin));
            if M == 2 || M == 4
                ber_psk_curve = q_fun(sqrt(2 * ebnoLin));
            else
                ber_psk_curve = (2 / k) * q_fun(sqrt(2 * k * ebnoLin) * sin(pi / M));
            end

            cla(axComp);
            semilogy(axComp, ebnoVec, ber_pam_curve, 'b-', 'LineWidth', 1.8, 'DisplayName', sprintf('%d-PAM', M));
            hold(axComp, 'on');
            semilogy(axComp, ebnoVec, ber_qam_curve, 'r--', 'LineWidth', 1.8, 'DisplayName', sprintf('%d-QAM', M));
            if M == 4
                semilogy(axComp, ebnoVec, ber_psk_curve, 'g:', 'LineWidth', 1.8, 'DisplayName', sprintf('%d-PSK (Superpuesto)', M));
            else
                semilogy(axComp, ebnoVec, ber_psk_curve, 'g-.', 'LineWidth', 1.8, 'DisplayName', sprintf('%d-PSK', M));
            end
            hold(axComp, 'off');

            title(axComp, sprintf('BER vs Eb/N0 (%d-PAM, %d-QAM, %d-PSK)', M, M, M));
            xlabel(axComp, 'E_b/N_0 (dB)');
            ylabel(axComp, 'BER');
            ylim(axComp, [1e-7, 1]);
            xlim(axComp, [0, max_db]);
            legend(axComp, 'Location', 'southwest');

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.949 0.7569 0.3059];
            app.UIFigure.Position = [100 100 1003 770];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxesOjo
            app.UIAxesOjo = uiaxes(app.UIFigure);
            title(app.UIAxesOjo, 'Diagrama del ojo en Recepcion')
            xlabel(app.UIAxesOjo, 'X')
            ylabel(app.UIAxesOjo, 'Y')
            zlabel(app.UIAxesOjo, 'Z')
            app.UIAxesOjo.Position = [299 547 300 185];

            % Create UIAxesConstelacion
            app.UIAxesConstelacion = uiaxes(app.UIFigure);
            title(app.UIAxesConstelacion, 'Diagrama de Constelacion en Recepcion')
            xlabel(app.UIAxesConstelacion, 'X')
            ylabel(app.UIAxesConstelacion, 'Y')
            zlabel(app.UIAxesConstelacion, 'Z')
            app.UIAxesConstelacion.Position = [625 547 300 185];

            % Create UIAxesDesempeno
            app.UIAxesDesempeno = uiaxes(app.UIFigure);
            title(app.UIAxesDesempeno, 'Curva de Desempeno')
            xlabel(app.UIAxesDesempeno, 'X')
            ylabel(app.UIAxesDesempeno, 'Y')
            zlabel(app.UIAxesDesempeno, 'Z')
            app.UIAxesDesempeno.Position = [299 293 300 185];

            % Create UIAxesBandaTransmisor
            app.UIAxesBandaTransmisor = uiaxes(app.UIFigure);
            title(app.UIAxesBandaTransmisor, 'Espectro de la senal en Banda Base Transmisor')
            xlabel(app.UIAxesBandaTransmisor, 'X')
            ylabel(app.UIAxesBandaTransmisor, 'Y')
            zlabel(app.UIAxesBandaTransmisor, 'Z')
            app.UIAxesBandaTransmisor.Position = [625 293 300 185];

            % Create UIAxesBandaRecepcion
            app.UIAxesBandaRecepcion = uiaxes(app.UIFigure);
            title(app.UIAxesBandaRecepcion, 'Espectro de la senal en Pasa Banda Recepcion')
            xlabel(app.UIAxesBandaRecepcion, 'X')
            ylabel(app.UIAxesBandaRecepcion, 'Y')
            zlabel(app.UIAxesBandaRecepcion, 'Z')
            app.UIAxesBandaRecepcion.Position = [477 57 300 185];

            % Create EsquemadeModulacionLabel
            app.EsquemadeModulacionLabel = uilabel(app.UIFigure);
            app.EsquemadeModulacionLabel.HorizontalAlignment = 'center';
            app.EsquemadeModulacionLabel.FontSize = 14;
            app.EsquemadeModulacionLabel.FontWeight = 'bold';
            app.EsquemadeModulacionLabel.Position = [43 684 91 34];
            app.EsquemadeModulacionLabel.Text = {'Esquema de '; 'Modulacion'};

            % Create EsquemadeModulacionDropDown
            app.EsquemadeModulacionDropDown = uidropdown(app.UIFigure);
            app.EsquemadeModulacionDropDown.Items = {'M-PAM', 'M-QAM', 'M-PSK'};
            app.EsquemadeModulacionDropDown.FontSize = 14;
            app.EsquemadeModulacionDropDown.FontWeight = 'bold';
            app.EsquemadeModulacionDropDown.Position = [167 690 100 22];
            app.EsquemadeModulacionDropDown.Value = 'M-PAM';

            % Create FactordeRolloffEditField
            app.FactordeRolloffEditField = uieditfield(app.UIFigure, 'numeric');
            app.FactordeRolloffEditField.HorizontalAlignment = 'center';
            app.FactordeRolloffEditField.FontSize = 14;
            app.FactordeRolloffEditField.FontWeight = 'bold';
            app.FactordeRolloffEditField.Position = [163 457 100 22];

            % Create FactordeRolloffEditFieldLabel
            app.FactordeRolloffEditFieldLabel = uilabel(app.UIFigure);
            app.FactordeRolloffEditFieldLabel.HorizontalAlignment = 'center';
            app.FactordeRolloffEditFieldLabel.FontSize = 14;
            app.FactordeRolloffEditFieldLabel.FontWeight = 'bold';
            app.FactordeRolloffEditFieldLabel.Position = [39 453 72 34];
            app.FactordeRolloffEditFieldLabel.Text = {'Factor de '; 'Roll-off'};

            % Create EficienciaEspectralLabel
            app.EficienciaEspectralLabel = uilabel(app.UIFigure);
            app.EficienciaEspectralLabel.HorizontalAlignment = 'right';
            app.EficienciaEspectralLabel.FontSize = 14;
            app.EficienciaEspectralLabel.FontWeight = 'bold';
            app.EficienciaEspectralLabel.Position = [33 258 70 34];
            app.EficienciaEspectralLabel.Text = {'Eficiencia'; 'Espectral'};

            % Create EficienciaEspectralEditField
            app.EficienciaEspectralEditField = uieditfield(app.UIFigure, 'numeric');
            app.EficienciaEspectralEditField.HorizontalAlignment = 'center';
            app.EficienciaEspectralEditField.FontSize = 14;
            app.EficienciaEspectralEditField.FontWeight = 'bold';
            app.EficienciaEspectralEditField.Position = [164 278 100 22];

            % Create EnergiadeSimboloLabel
            app.EnergiadeSimboloLabel = uilabel(app.UIFigure);
            app.EnergiadeSimboloLabel.HorizontalAlignment = 'center';
            app.EnergiadeSimboloLabel.FontSize = 14;
            app.EnergiadeSimboloLabel.FontWeight = 'bold';
            app.EnergiadeSimboloLabel.Position = [33 193 77 34];
            app.EnergiadeSimboloLabel.Text = {'Energia de'; 'Simbolo'};

            % Create EnergiadeSimboloEditField
            app.EnergiadeSimboloEditField = uieditfield(app.UIFigure, 'numeric');
            app.EnergiadeSimboloEditField.HorizontalAlignment = 'center';
            app.EnergiadeSimboloEditField.FontSize = 14;
            app.EnergiadeSimboloEditField.FontWeight = 'bold';
            app.EnergiadeSimboloEditField.Position = [164 203 100 22];

            % Create AnchodeBandaEditFieldLabel
            app.AnchodeBandaEditFieldLabel = uilabel(app.UIFigure);
            app.AnchodeBandaEditFieldLabel.HorizontalAlignment = 'center';
            app.AnchodeBandaEditFieldLabel.FontSize = 14;
            app.AnchodeBandaEditFieldLabel.FontWeight = 'bold';
            app.AnchodeBandaEditFieldLabel.Position = [33 119 69 34];
            app.AnchodeBandaEditFieldLabel.Text = {'Ancho de'; 'Banda'};

            % Create AnchodeBandaEditField
            app.AnchodeBandaEditField = uieditfield(app.UIFigure, 'numeric');
            app.AnchodeBandaEditField.HorizontalAlignment = 'center';
            app.AnchodeBandaEditField.FontSize = 14;
            app.AnchodeBandaEditField.FontWeight = 'bold';
            app.AnchodeBandaEditField.Position = [164 125 100 22];

            % Create PotenciadelaSealModuladaEditFieldLabel
            app.PotenciadelaSealModuladaEditFieldLabel = uilabel(app.UIFigure);
            app.PotenciadelaSealModuladaEditFieldLabel.HorizontalAlignment = 'center';
            app.PotenciadelaSealModuladaEditFieldLabel.FontSize = 14;
            app.PotenciadelaSealModuladaEditFieldLabel.FontWeight = 'bold';
            app.PotenciadelaSealModuladaEditFieldLabel.Position = [33 50 112 34];
            app.PotenciadelaSealModuladaEditFieldLabel.Text = {'Potencia de la'; 'Senal Modulada'};

            % Create PotenciadelaSealModuladaEditField
            app.PotenciadelaSealModuladaEditField = uieditfield(app.UIFigure, 'numeric');
            app.PotenciadelaSealModuladaEditField.HorizontalAlignment = 'center';
            app.PotenciadelaSealModuladaEditField.FontSize = 14;
            app.PotenciadelaSealModuladaEditField.FontWeight = 'bold';
            app.PotenciadelaSealModuladaEditField.Position = [165 62 100 22];

            % Create ComenzarButton
            app.ComenzarButton = uibutton(app.UIFigure, 'push');
            app.ComenzarButton.ButtonPushedFcn = createCallbackFcn(app, @ComenzarButtonPushed, true);
            app.ComenzarButton.FontSize = 14;
            app.ComenzarButton.Position = [105 373 100 25];
            app.ComenzarButton.Text = 'Comenzar';

            % Create vertablasbutton
            app.vertablasbutton = uibutton(app.UIFigure, 'push');
            app.vertablasbutton.ButtonPushedFcn = createCallbackFcn(app, @vertablasbuttonButtonPushed, true);
            app.vertablasbutton.Position = [101 332 100 22];
            app.vertablasbutton.Text = 'Tablas';

            % Create TasadeSimboloLabel
            app.TasadeSimboloLabel = uilabel(app.UIFigure);
            app.TasadeSimboloLabel.HorizontalAlignment = 'right';
            app.TasadeSimboloLabel.FontSize = 14;
            app.TasadeSimboloLabel.FontWeight = 'bold';
            app.TasadeSimboloLabel.Position = [38 562 60 34];
            app.TasadeSimboloLabel.Text = {'Tasa de '; 'Simbolo'};

            % Create TasadeSimboloEditField
            app.TasadeSimboloEditField = uieditfield(app.UIFigure, 'numeric');
            app.TasadeSimboloEditField.HorizontalAlignment = 'center';
            app.TasadeSimboloEditField.FontSize = 14;
            app.TasadeSimboloEditField.FontWeight = 'bold';
            app.TasadeSimboloEditField.Position = [166 574 100 22];

            % Create FrecuenciadePortadoraLabel
            app.FrecuenciadePortadoraLabel = uilabel(app.UIFigure);
            app.FrecuenciadePortadoraLabel.HorizontalAlignment = 'center';
            app.FrecuenciadePortadoraLabel.FontSize = 14;
            app.FrecuenciadePortadoraLabel.FontWeight = 'bold';
            app.FrecuenciadePortadoraLabel.Position = [41 510 99 34];
            app.FrecuenciadePortadoraLabel.Text = {'Frecuencia de'; 'Portadora'};

            % Create FrecuenciadePortadoraEditField
            app.FrecuenciadePortadoraEditField = uieditfield(app.UIFigure, 'numeric');
            app.FrecuenciadePortadoraEditField.HorizontalAlignment = 'center';
            app.FrecuenciadePortadoraEditField.FontSize = 14;
            app.FrecuenciadePortadoraEditField.FontWeight = 'bold';
            app.FrecuenciadePortadoraEditField.Position = [164 522 100 22];

            % Create OrdendeModulacinEditFieldLabel
            app.OrdendeModulacinEditFieldLabel = uilabel(app.UIFigure);
            app.OrdendeModulacinEditFieldLabel.HorizontalAlignment = 'center';
            app.OrdendeModulacinEditFieldLabel.FontSize = 14;
            app.OrdendeModulacinEditFieldLabel.FontWeight = 'bold';
            app.OrdendeModulacinEditFieldLabel.Position = [36 623 87 34];
            app.OrdendeModulacinEditFieldLabel.Text = {'Orden de'; 'Modulacion '};

            % Create OrdendeModulacinEditField
            app.OrdendeModulacinEditField = uieditfield(app.UIFigure, 'numeric');
            app.OrdendeModulacinEditField.HorizontalAlignment = 'center';
            app.OrdendeModulacinEditField.FontSize = 14;
            app.OrdendeModulacinEditField.FontWeight = 'bold';
            app.OrdendeModulacinEditField.Position = [168 635 100 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = pedroapp3

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end