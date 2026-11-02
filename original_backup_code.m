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
        function ComenzarButtonPushed(app, event)

        % 1. LECTURA DE PARÁMETROS DESDE LA INTERFAZ
        esquema = app.EsquemadeModulacionDropDown.Value;
        alpha = app.FactordeRolloffEditField.Value;
        Rs = app.TasadeSimboloEditField.Value;
        fc = app.FrecuenciadePortadoraEditField.Value;
        M = app.OrdendeModulacinEditField.Value; 
        
        % Validaciones básicas de seguridad
        if alpha < 0 || alpha > 1
            uialert(app.UIFigure, 'El factor de Roll-off debe estar entre 0 y 1.', 'Error de Parámetro');
            return;
        end
        if Rs <= 0 || M <= 1 || fc < 0
            uialert(app.UIFigure, 'Por favor ingrese valores válidos mayores a cero para Tasa, Frecuencia y un Orden M > 1.', 'Error de Parámetro');
            return;
        end
        
        k = log2(M); % Bits por símbolo
        if mod(k, 1) ~= 0 && strcmp(esquema, 'M-QAM')
            uialert(app.UIFigure, 'Para M-QAM, el orden M debe ser una potencia de 2 (ej. 4, 16, 64).', 'Aviso');
            return;
        end
        
        % Parámetros internos de simulación
        Ts = 1 / Rs;
        sps = 16;               % Muestras por símbolo (Samples per symbol)
        Fs = Rs * sps;          % Frecuencia de muestreo
        numSymbols = 2000;      % Cantidad de símbolos a simular
        
        % 2. GENERACIÓN DE DATOS Y MODULACIÓN DIGITAL
        dataBits = randi([0 M-1], numSymbols, 1);
        
        switch esquema
            case 'M-PAM'
                modData = pammod(dataBits, M);
            case 'M-PSK'
                modData = pskmod(dataBits, M, 0, 'gray');
            case 'M-QAM'
                modData = qammod(dataBits, M, 'UnitAveragePower', true);
        end
        
        % 3. FILTRADO CON RAÍZ DE COSENO ALZADO (SRRC)
        span = 10; % Duración del filtro en símbolos
        rCosFilter = rcosdesign(alpha, span, sps, 'sqrt'); 
        
        % Sobremuestreo y filtrado en Transmisión (Banda Base)
        txSignalBB = upfirdn(modData, rCosFilter, sps);
        
        % 4. MODULACIÓN EN PASA BANDA Y CANAL (AWGN)
        t = (0:length(txSignalBB)-1)' / Fs;
        snr = 15; % Relación Señal a Ruido (dB) simulada en el canal
        
        % Traslación a Pasa Banda
        txSignalPB = real(txSignalBB .* exp(1i * 2 * pi * fc * t));
        rxSignalPB = awgn(txSignalPB, snr, 'measured');
        
        % Demodulación / Filtrado Adaptado en Recepción
        rxSignalBB_raw = rxSignalPB .* exp(-1i * 2 * pi * fc * t) * 2;
        rxSignalBB = upfirdn(rxSignalBB_raw, rCosFilter, 1, sps); 
        
        % 5. CÁLCULO DE MÉTRICAS TEÓRICAS Y NUMÉRICAS
        eficiencia = k / (1 + alpha);
        anchoBanda = Rs * (1 + alpha);
        
        % Energía de símbolo promedio según el esquema
        switch esquema
            case 'M-PAM'
                Es = (M^2 - 1) / 3;
            case 'M-PSK'
                Es = 1;
            case 'M-QAM'
                Es = 1; 
        end
        
        potenciaModulada = mean(abs(txSignalPB).^2);
        
        % Escribir resultados en los Edit Fields de la UI
        app.EficienciaEspectralEditField.Value = round(eficiencia, 4);
        app.AnchodeBandaEditField.Value = round(anchoBanda, 2);
        app.EnergiadeSimboloEditField.Value = round(Es, 4);
        app.PotenciadelaSealModuladaEditField.Value = round(potenciaModulada, 4);
        
        % 6. RENDERIZADO DE LAS 5 GRÁFICAS EN TUS UIAXES
        
        
        % --- Gráfica 1: Diagrama del Ojo (Manual en UIAxesOjo) ---
         rxEyeSignal = real(txSignalBB(span*sps+1 : end-span*sps));
    
        % Configurar parámetros para las trazas (2 símbolos por traza)
         samplesPerTrace = 2 * sps;
         numTraces = floor(length(rxEyeSignal) / samplesPerTrace) - 1;
         eyeMatrix = zeros(samplesPerTrace, numTraces);
    
        for i = 1:numTraces
            idx = (i-1)*sps + (1:samplesPerTrace);
            eyeMatrix(:, i) = rxEyeSignal(idx);
        end
    
        t_eye = ((0:samplesPerTrace-1)' / Fs) * 1000; % Tiempo en milisegundos
    
    % Graficar con un poco de transparencia para el efecto de densidad visual
    plot(app.UIAxesOjo, t_eye, eyeMatrix, 'Color', [0 0.447 0.741 0.3], 'LineWidth', 0.6);
    grid(app.UIAxesOjo, 'on');
    title(app.UIAxesOjo, 'Diagrama del Ojo');
    xlabel(app.UIAxesOjo, 'Tiempo (ms)');
    ylabel(app.UIAxesOjo, 'Amplitud');
        % --- Gráfica 2: Diagrama de Constelación ---
        rxSymbols = rxSignalBB(span+1 : end-span);
        plot(app.UIAxesConstelacion, real(rxSymbols), imag(rxSymbols), 'b.', 'MarkerSize', 6);
        grid(app.UIAxesConstelacion, 'on');
        title(app.UIAxesConstelacion, 'Constelación');
        xlabel(app.UIAxesConstelacion, 'I');
        ylabel(app.UIAxesConstelacion, 'Q');
        
        % --- Gráfica 3: Curva de Desempeño ---
        ebnoVec = 0:1:15; 
        ebnoLin = 10.^(ebnoVec/10);
        
        switch esquema
            case 'M-PAM'
                berTeorica = (2*(M-1)/(M*k)) * qfunc(sqrt((6*k/(M^2-1)) * ebnoLin));
            case 'M-PSK'
                berTeorica = (2/k) * qfunc(sqrt(2*k*ebnoLin) * sin(pi/M));
            case 'M-QAM'
                berTeorica = (4/k)*(1 - 1/sqrt(M)) * qfunc(sqrt((3*k/(M-1)) * ebnoLin));
        end
        
        semilogy(app.UIAxesDesempeno, ebnoVec, berTeorica, 'r-o', 'LineWidth', 1.5);
        grid(app.UIAxesDesempeno, 'on');
        title(app.UIAxesDesempeno, 'Curva de Desempeño (BER)');
        xlabel(app.UIAxesDesempeno, 'E_b/N_0 (dB)');
        ylabel(app.UIAxesDesempeno, 'BER');
        
        % --- Gráfica 4: Espectro Banda Base Transmisor ---
        [psdBB, fBB] = periodogram(txSignalBB, [], 1024, Fs, 'centered');
        plot(app.UIAxesBandaTransmisor, fBB/1000, 10*log10(psdBB), 'b', 'LineWidth', 1.2);
        grid(app.UIAxesBandaTransmisor, 'on');
        title(app.UIAxesBandaTransmisor, 'Espectro Banda Base Tx');
        xlabel(app.UIAxesBandaTransmisor, 'Frecuencia (kHz)');
        ylabel(app.UIAxesBandaTransmisor, 'PSD (dB/Hz)');
        
        % --- Gráfica 5: Espectro Pasa Banda Recepción ---
        [psdPB, fPB] = periodogram(rxSignalPB, [], 1024, Fs, 'centered');
        plot(app.UIAxesBandaRecepcion, fPB/1000, 10*log10(psdPB), 'm', 'LineWidth', 1.2);
        grid(app.UIAxesBandaRecepcion, 'on');
        title(app.UIAxesBandaRecepcion, 'Espectro Pasa Banda Rx');
        xlabel(app.UIAxesBandaRecepcion, 'Frecuencia (kHz)');
        ylabel(app.UIAxesBandaRecepcion, 'PSD (dB/Hz)');
    
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
            title(app.UIAxesOjo, 'Diagrama del ojo en Recepcionepción')
            xlabel(app.UIAxesOjo, 'X')
            ylabel(app.UIAxesOjo, 'Y')
            zlabel(app.UIAxesOjo, 'Z')
            app.UIAxesOjo.Position = [299 547 300 185];

            % Create UIAxesConstelacion
            app.UIAxesConstelacion = uiaxes(app.UIFigure);
            title(app.UIAxesConstelacion, 'Diagrama de Constelación en Recepción')
            xlabel(app.UIAxesConstelacion, 'X')
            ylabel(app.UIAxesConstelacion, 'Y')
            zlabel(app.UIAxesConstelacion, 'Z')
            app.UIAxesConstelacion.Position = [625 547 300 185];

            % Create UIAxesDesempeno
            app.UIAxesDesempeno = uiaxes(app.UIFigure);
            title(app.UIAxesDesempeno, 'Curva de Desempeño')
            xlabel(app.UIAxesDesempeno, 'X')
            ylabel(app.UIAxesDesempeno, 'Y')
            zlabel(app.UIAxesDesempeno, 'Z')
            app.UIAxesDesempeno.Position = [299 293 300 185];

            % Create UIAxesBandaTransmisor
            app.UIAxesBandaTransmisor = uiaxes(app.UIFigure);
            title(app.UIAxesBandaTransmisor, 'Espectro de la señal en Banda Base Transmisor')
            xlabel(app.UIAxesBandaTransmisor, 'X')
            ylabel(app.UIAxesBandaTransmisor, 'Y')
            zlabel(app.UIAxesBandaTransmisor, 'Z')
            app.UIAxesBandaTransmisor.Position = [625 293 300 185];

            % Create UIAxesBandaRecepcion
            app.UIAxesBandaRecepcion = uiaxes(app.UIFigure);
            title(app.UIAxesBandaRecepcion, 'Espectro de la señal en Pasa Banda Recepción')
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
            app.PotenciadelaSealModuladaEditFieldLabel.Text = {'Potencia de la'; 'Señal Modulada'};

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
            app.OrdendeModulacinEditFieldLabel.Text = {'Orden de'; 'Modulación '};

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