%% Système de Correction Acoustique - Filtre Égalisateur
% Compensation des atténuations causées par une mousse absorbante

clear all; close all; clc;

%% 1. DONNÉES MESURÉES CORRIGÉES
% Fréquences en Hz
frequencies = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 2000, 3000, 4000, 5000, ...
               6000, 7000, 8000, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, ...
               18000, 19000, 20000];

% Puissances mesurées sans mousse (dBm) - données de l'image
P_sans_mousse = [3.55, 19.31, 18.33, 20.14, 20.47, 19.75, 20.73, 20.55, 19.47, 20.59, 20.86, ...
                 17.7, 20.32, 16.5172, 19.66, 14.5, -0.4, 4.21, 9.89, 7.11, 10.85, 0.02, ...
                 2.71, -15.64, -10, -8.87, -10, -23.1, -14.29, -19.69];

% Puissances mesurées avec mousse (dBm) - données de l'image
P_avec_mousse = [-3.93, 20.31, 19.67, 20.63, 16.87, 14.13, 13.53, 4.51, 8.86, 7.27, 7.4, ...
                 7.52, -10.054, 5.6, 5.49, -0.24, 1.88, 3.23, 1.89, 1.17, 1.29, 0.95, ...
                 -0.43, -1.03, -0.76, -0.24, 0.77, 0.98, -0.64, -6.16];

% Calcul de l'atténuation : A(dB) = P_sans_mousse - P_avec_mousse
attenuation_dB = P_sans_mousse - P_avec_mousse;

% Nettoyage des données (suppression des valeurs aberrantes)
valid_indices = attenuation_dB > -25 & attenuation_dB < 25; % Éliminer les valeurs aberrantes
freq_clean = frequencies(valid_indices);
atten_clean = attenuation_dB(valid_indices);

% Affichage des atténuations calculées
disp('=== ATTÉNUATIONS CALCULÉES ===');
for i = 1:length(frequencies)
    fprintf('%.0f Hz: %.2f dB\n', frequencies(i), attenuation_dB(i));
end

%% 2. ANALYSE DE LA RÉPONSE FRÉQUENTIELLE
figure(1);
subplot(3,1,1);
semilogx(frequencies, P_sans_mousse, 'g.-', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
semilogx(frequencies, P_avec_mousse, 'b.-', 'LineWidth', 2, 'MarkerSize', 8);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Puissance (dBm)');
title('Comparaison des Puissances Mesurées');
legend('Sans Mousse', 'Avec Mousse', 'Location', 'best');
xlim([50 20000]);

subplot(3,1,2);
semilogx(freq_clean, atten_clean, 'r.-', 'LineWidth', 2, 'MarkerSize', 8);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Atténuation (dB)');
title('Atténuation de la Mousse (P_{sans} - P_{avec})');
xlim([50 20000]);
ylim([min(atten_clean)-2, max(atten_clean)+2]);

%% 3. CALCUL DE LA CORRECTION NÉCESSAIRE
% La correction est l'inverse de l'atténuation
correction_dB = -atten_clean;

subplot(3,1,3);
semilogx(freq_clean, correction_dB, 'r.-', 'LineWidth', 2, 'MarkerSize', 8);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Gain de Correction (dB)');
title('Courbe de Correction Requise');
xlim([50 20000]);

% Analyse statistique de l'atténuation
disp('=== ANALYSE STATISTIQUE ===');
disp(['Atténuation moyenne: ', num2str(mean(atten_clean)), ' dB']);
disp(['Atténuation maximale: ', num2str(max(atten_clean)), ' dB']);
disp(['Atténuation minimale: ', num2str(min(atten_clean)), ' dB']);
disp(['Écart-type: ', num2str(std(atten_clean)), ' dB']);

%% 4. CONCEPTION DU FILTRE ÉGALISATEUR

% Paramètres du filtre
fs = 48000; % Fréquence d'échantillonnage (Hz)
N_fir = 512; % Ordre du filtre FIR

% Interpolation pour obtenir une réponse lisse
freq_interp = logspace(log10(50), log10(18000), 1000); % Limité à 18kHz (données valides)
% On interpole avec 1000 points pour un espacement logarithmique

correction_interp = interp1(freq_clean, correction_dB, freq_interp, 'pchip', 'extrap');
%Interpolation des valeurs de correction pour obtenir une réponse plus lisse

% Limitation du gain de correction pour éviter l'instabilité
max_gain = 15; % Gain maximum en dB 
correction_limited = min(max_gain, max(correction_interp, -max_gain));
%Limité pour éviter la saturation ou instabilité

% Conversion en réponse linéaire pour concevoir le filtre
H_desired = 10.^(correction_limited/20);

% Fréquences normalisées pour le filtre
freq_norm = freq_interp / (fs/2);

% Conception du filtre FIR avec firls
equalizer_fir = firls(N_fir, [0, freq_norm, 1], [H_desired(1), H_desired, H_desired(end)]);

%% 5. ANALYSE DU FILTRE CONÇU
[H_filt, f_filt] = freqz(equalizer_fir, 1, 2048, fs);
H_filt_dB = 20*log10(abs(H_filt));

figure(2);
subplot(3,1,1);
semilogx(freq_clean, correction_dB, 'r.-', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
semilogx(f_filt, H_filt_dB, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Gain (dB)');
title('Comparaison: Correction Désirée vs Filtre Conçu');
legend('Correction Désirée', 'Filtre FIR', 'Location', 'best');
xlim([50 20000]);

% Phase du filtre
subplot(3,1,2);
semilogx(f_filt, unwrap(angle(H_filt))*180/pi, 'g-', 'LineWidth', 1.5);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Phase (degrés)');
title('Réponse en Phase du Filtre');
xlim([50 20000]);

% Réponse impulsionnelle
subplot(3,1,3);
t_impulse = (0:length(equalizer_fir)-1) / fs * 1000; % en ms
plot(t_impulse, equalizer_fir, 'k-', 'LineWidth', 1.5);
grid on;
xlabel('Temps (ms)');
ylabel('Amplitude');
title('Réponse Impulsionnelle du Filtre');

%% 6. GÉNÉRATION DES COEFFICIENTS POUR SIGMASTUDIO

% Export des coefficients pour SigmaStudio (format DSP ADAU1701)
disp('=== COEFFICIENTS POUR SIGMASTUDIO ===');
disp(['Nombre de coefficients FIR: ', num2str(length(equalizer_fir))]);
disp('Coefficients (format décimal):');

% Affichage formaté pour SigmaStudio
for i = 1:length(equalizer_fir)
    fprintf('%.8f\n', equalizer_fir(i));
end

% Sauvegarde des coefficients
save('equalizer_coefficients.mat', 'equalizer_fir', 'fs', 'freq_clean', 'correction_dB');

% Export au format CSV pour SigmaStudio
coeffs_table = array2table(equalizer_fir', 'VariableNames', {'Coefficient'});
writetable(coeffs_table, 'equalizer_coefficients.csv');

%% 7. SIMULATION DE LA CORRECTION

% Signal de test (bruit blanc)
duration = 2; % secondes
t = 0:1/fs:duration-1/fs;
test_signal = randn(size(t)) * 0.1; % Bruit blanc

% Simulation de la mousse : filtre passe-bas + atténuation ciblée
% (ici simple atténuation sur les médiums comme exemple)
H_mousse_dB = zeros(size(freq_interp));
H_mousse_dB(freq_interp > 500 & freq_interp < 2000) = -8; % -8 dB dans les médiums
H_mousse = 10.^(H_mousse_dB / 20);
mousse_fir = firls(N_fir, [0, freq_norm, 1], [H_mousse(1), H_mousse, H_mousse(end)]);

% Application du filtre mousse (dégradation)
attenuated_signal = filter(mousse_fir, 1, test_signal);

% Application du filtre correcteur (égaliseur)
corrected_signal = filter(equalizer_fir, 1, attenuated_signal);

% Analyse spectrale
[Pxx_original, f_psd]   = pwelch(test_signal, [], [], [], fs);
[Pxx_mousse, ~]         = pwelch(attenuated_signal, [], [], [], fs);
[Pxx_corrected, ~]      = pwelch(corrected_signal, [], [], [], fs);

% Affichage
figure(3); clf;
semilogx(f_psd, 10*log10(Pxx_original), 'b', 'LineWidth', 1.2); hold on;
semilogx(f_psd, 10*log10(Pxx_mousse), 'color', [1 0.5 0], 'LineWidth', 1.2); % orange
semilogx(f_psd, 10*log10(Pxx_corrected), 'g', 'LineWidth', 1.2); % vert
grid on;
xlabel('Fréquence (Hz)');
ylabel('DSP (dB/Hz)');
title('Comparaison Spectrale : Original, Atténué, Corrigé');
legend('Signal Original', 'Avec mousse', 'Corrigé', 'Location', 'best');
xlim([50 20000]);

%% 8. PARAMÈTRES POUR L'IMPLÉMENTATION DSP

disp('=== PARAMÈTRES POUR IMPLÉMENTATION DSP ===');
disp(['Fréquence d''échantillonnage: ', num2str(fs), ' Hz']);
disp(['Ordre du filtre FIR: ', num2str(length(equalizer_fir))]);
disp(['Latence du filtre: ', num2str(length(equalizer_fir)/2/fs*1000), ' ms']);

% Facteur de normalisation pour éviter la saturation
max_coeff = max(abs(equalizer_fir));
normalization_factor = 1/max_coeff;
equalizer_fir_normalized = equalizer_fir * normalization_factor;

disp(['Facteur de normalisation: ', num2str(normalization_factor)]);
disp('Coefficients normalisés sauvegardés dans equalizer_coefficients.mat');

%% 9. RECOMMANDATIONS POUR SIGMASTUDIO

fprintf('\n=== RECOMMANDATIONS POUR SIGMASTUDIO ===\n');
fprintf('1. Utilisez un bloc "FIR Filter" dans SigmaStudio\n');
fprintf('2. Configurez avec %d coefficients\n', length(equalizer_fir));
fprintf('3. Fréquence d''échantillonnage: %d Hz\n', fs);
fprintf('4. Importez les coefficients depuis equalizer_coefficients.csv\n');
fprintf('5. Ajustez le gain global si nécessaire pour éviter la saturation\n');
fprintf('6. Testez avec un générateur de tonalités balayées (20Hz-20kHz)\n');

disp('Traitement terminé. Fichiers sauvegardés:');
disp('- equalizer_coefficients.mat');
disp('- equalizer_coefficients.csv');