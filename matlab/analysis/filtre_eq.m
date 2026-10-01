%% ANALYSEUR D'ATTÉNUATION ACOUSTIQUE ET CONCEPTION DE FILTRE ÉGALISATEUR
% Auteur: Ingénieur Instrumentation & Traitement du Signal
% Objectif: Caractériser l'atténuation d'une mousse et concevoir un filtre compensateur
% Date: 2021

clear all; close all; clc;

%% PARAMÈTRES DE CONCEPTION
Fs = 48000;          % Fréquence d'échantillonnage (Hz)
N_points = 512;      % Résolution du filtre (points de fréquence)
filter_order = 256;   % Ordre du filtre FIR

%% ÉTAPE 1: LECTURE ET VALIDATION DES DONNÉES
fprintf('=== ÉTAPE 1: LECTURE DES DONNÉES ===\n');

filename = 'data_matlab.xlsx'; 
opts = detectImportOptions(filename);
T = readtable(filename, opts);

freq_measured = T{:, 'Freq_Hz'};
P_sans_mousse = T{:, 'P_sans_mousse_dBm'};
P_avec_mousse = T{:, 'P_avec_mousse_dBm'};

valid_idx = ~isnan(freq_measured) & ~isnan(P_sans_mousse) & ~isnan(P_avec_mousse);
freq_measured = freq_measured(valid_idx);
P_sans_mousse = P_sans_mousse(valid_idx);
P_avec_mousse = P_avec_mousse(valid_idx);

attenuation_dB = P_sans_mousse - P_avec_mousse;

fprintf('Données chargées: %d points de fréquence\n', length(freq_measured));
fprintf('Plage de fréquences: %.0f Hz - %.0f Hz\n', min(freq_measured), max(freq_measured));
fprintf('Atténuation moyenne: %.2f dB\n', mean(attenuation_dB));
fprintf('Atténuation max: %.2f dB à %.0f Hz\n', max(attenuation_dB), freq_measured(attenuation_dB == max(attenuation_dB)));


%% ÉTAPE 2: INTERPOLATION ET PRÉPARATION POUR LA CONCEPTION DU FILTRE
fprintf('\n=== ÉTAPE 2: INTERPOLATION DES DONNÉES ===\n');

f_nyquist = Fs/2;
freq_filter = linspace(0, f_nyquist, N_points);

attenuation_interp = interp1(freq_measured, attenuation_dB, freq_filter, 'pchip', 'extrap');
attenuation_interp(freq_filter < min(freq_measured)) = attenuation_dB(1);
attenuation_interp(freq_filter > max(freq_measured)) = attenuation_dB(end);

fprintf('Interpolation réalisée sur %d points\n', N_points);
fprintf('Bande passante du filtre: 0 - %.0f Hz\n', f_nyquist);

%% ÉTAPE 3: CONCEPTION DU FILTRE ÉGALISATEUR FIR
fprintf('\n=== ÉTAPE 3: CONCEPTION DU FILTRE ÉGALISATEUR ===\n');

gain_dB = -attenuation_interp;
gain_linear = 10.^(gain_dB/20);

freq_norm = freq_filter / f_nyquist;

h_fir = fir2(filter_order, freq_norm, gain_linear);

fprintf('Filtre FIR conçu:\n');
fprintf('- Ordre: %d\n', filter_order);
fprintf('- Méthode: fir2 (interpolation linéaire de la magnitude)\n');
fprintf('- Gain de compensation max: %.2f dB\n', max(gain_dB));
fprintf('- Gain de compensation min: %.2f dB\n', min(gain_dB));

[H_fir, f_response] = freqz(h_fir, 1, N_points, Fs);
H_fir_dB = 20*log10(abs(H_fir));
H_fir_phase = angle(H_fir) * 180/pi;

%% SAUVEGARDE POUR SIGMASTUDIO
fprintf('\n=== EXPORT POUR SIGMASTUDIO ===\n');

% Normalisation (optionnelle mais recommandée)
h_fir_normalized = h_fir / max(abs(h_fir)); 

% Sauvegarde verticale dans un fichier texte
fid = fopen('fir_coeffs_sigma.txt', 'w');
for i = 1:length(h_fir_normalized)
    fprintf(fid, '%.10f\n', h_fir_normalized(i));
end
fclose(fid);

fprintf('Coefficients FIR normalisés sauvegardés ligne par ligne dans "fir_coeffs_sigma.txt"\n');

%% ÉTAPE 4: GÉNÉRATION DE SIGNAUX DE TEST
fprintf('\n=== ÉTAPE 4: GÉNÉRATION DE SIGNAUX DE TEST ===\n');

% Génération d'un signal de test large bande
duration = 2; % secondes
t = 0:1/Fs:duration-1/Fs;
N_samples = length(t);

% Signal de test: utilisation de TOUTES les fréquences mesurées
test_frequencies = freq_measured'; % Utilisation de toutes les fréquences de vos données
signal_test = zeros(size(t));

% Génération du signal multi-fréquences
for i = 1:length(test_frequencies)
    if test_frequencies(i) < f_nyquist && test_frequencies(i) > 0
        signal_test = signal_test + sin(2*pi*test_frequencies(i)*t) / length(test_frequencies);
    end
end

% Simulation de l'atténuation par la mousse
signal_avec_mousse = signal_test;
for i = 1:length(test_frequencies)
    if test_frequencies(i) < f_nyquist && test_frequencies(i) > 0
        % Interpolation de l'atténuation à la fréquence de test
        att_freq = interp1(freq_measured, attenuation_dB, test_frequencies(i), 'linear', 'extrap');
        gain_att = 10^(-att_freq/20);
        
        % Application de l'atténuation à la composante fréquentielle
        component = sin(2*pi*test_frequencies(i)*t) / length(test_frequencies);
        signal_avec_mousse = signal_avec_mousse - component + component * gain_att;
    end
end

% Application du filtre égalisateur
signal_equalise = filter(h_fir, 1, signal_avec_mousse);

fprintf('Signaux de test générés:\n');
fprintf('- Durée: %.1f secondes\n', duration);
fprintf('- Nombre de fréquences de test: %d\n', length(test_frequencies));
fprintf('- Plage de fréquences: %.0f - %.0f Hz\n', min(test_frequencies), max(test_frequencies));
fprintf('- Échantillons: %d\n', N_samples);

%% ÉTAPE 5: VISUALISATION ET ANALYSE
fprintf('\n=== ÉTAPE 5: GÉNÉRATION DES GRAPHIQUES ===\n');

% FIGURE 1: Mesures brutes et atténuation
figure('Name', 'Étape 1 - Mesures Acoustiques et Atténuation', 'Position', [100, 100, 1200, 800]);

subplot(2,2,1)
semilogx(freq_measured, P_sans_mousse, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
hold on;
semilogx(freq_measured, P_avec_mousse, 'r-s', 'LineWidth', 2, 'MarkerSize', 6);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Puissance (dBm)');
title('Mesures de Puissance Acoustique');
legend('Sans mousse', 'Avec mousse', 'Location', 'best');
xlim([50, 20000]);

subplot(2,2,2)
semilogx(freq_measured, attenuation_dB, 'g-^', 'LineWidth', 2, 'MarkerSize', 6);
hold on;
semilogx(freq_filter, attenuation_interp, 'k--', 'LineWidth', 1);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Atténuation (dB)');
title('Atténuation de la Mousse');
legend('Mesurée', 'Interpolée', 'Location', 'best');
xlim([50, 20000]);

subplot(2,2,3)
semilogx(freq_filter, gain_dB, 'm-d', 'LineWidth', 2, 'MarkerSize', 4);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Gain de Compensation (dB)');
title('Gain de Compensation Requis');
xlim([50, 20000]);

subplot(2,2,4)
plot(1:length(h_fir), h_fir, 'b-', 'LineWidth', 2);
grid on;
xlabel('Échantillons');
ylabel('Amplitude');
title('Réponse Impulsionnelle du Filtre FIR');

% FIGURE 2: Réponse fréquentielle du filtre
figure('Name', 'Étape 2 - Réponse Fréquentielle du Filtre Égalisateur', 'Position', [150, 150, 1200, 600]);

subplot(2,1,1)
semilogx(f_response, H_fir_dB, 'b-', 'LineWidth', 2);
hold on;
semilogx(freq_filter, gain_dB, 'r--', 'LineWidth', 2);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Magnitude (dB)');
title('Réponse en Fréquence - Magnitude');
legend('Filtre conçu (fir2)', 'Cible', 'Location', 'best');
xlim([50, 20000]);

subplot(2,1,2)
semilogx(f_response, H_fir_phase, 'g-', 'LineWidth', 2);
grid on;
xlabel('Fréquence (Hz)');
ylabel('Phase (degrés)');
title('Réponse en Fréquence - Phase');
xlim([50, 20000]);

% FIGURE 3: Comparaison temporelle des signaux
figure('Name', 'Étape 3 - Comparaison Temporelle des Signaux', 'Position', [200, 200, 1400, 400]);

plot(t(1:2000), signal_test(1:2000), 'b-', 'LineWidth', 1.5);
hold on;
plot(t(1:2000), signal_avec_mousse(1:2000), 'r-', 'LineWidth', 1.5);
plot(t(1:2000), signal_equalise(1:2000), 'g-', 'LineWidth', 1.5);
grid on;
xlabel('Temps (s)');
ylabel('Amplitude');
title('Comparaison Temporelle des Signaux');
legend('Original (sans mousse)', 'Atténué (avec mousse)', 'Égalisé (compensé)', 'Location', 'best');

% FIGURE 4: Analyse spectrale comparative (dB/Hz vs Hz)
figure('Name', 'Étape 4 - Comparaison Spectrale des Signaux', 'Position', [250, 250, 1200, 600]);

% Calcul des densités spectrales de puissance avec pwelch
[Pxx_orig, f_psd] = pwelch(signal_test, hanning(1024), 512, 2048, Fs);
[Pxx_mousse, ~] = pwelch(signal_avec_mousse, hanning(1024), 512, 2048, Fs);
[Pxx_equal, ~] = pwelch(signal_equalise, hanning(1024), 512, 2048, Fs);

% Conversion en dB/Hz
Pxx_orig_dB = 10*log10(Pxx_orig);
Pxx_mousse_dB = 10*log10(Pxx_mousse);
Pxx_equal_dB = 10*log10(Pxx_equal);

semilogx(f_psd, Pxx_orig_dB, 'b-', 'LineWidth', 2, 'DisplayName', 'Original (sans mousse)');
hold on;
semilogx(f_psd, Pxx_mousse_dB, 'r-', 'LineWidth', 2, 'DisplayName', 'Atténué (avec mousse)');
semilogx(f_psd, Pxx_equal_dB, 'g-', 'LineWidth', 2, 'DisplayName', 'Égalisé (compensé)');
grid on;
xlabel('Fréquence (Hz)');
ylabel('Densité Spectrale de Puissance (dB/Hz)');
title('Analyse Spectrale Comparative - Densité Spectrale de Puissance');
legend('Location', 'best');
xlim([50, 20000]);
ylim([min([Pxx_orig_dB; Pxx_mousse_dB; Pxx_equal_dB])-5, max([Pxx_orig_dB; Pxx_mousse_dB; Pxx_equal_dB])+5]);

%% ÉTAPE 6: ÉVALUATION DES PERFORMANCES
fprintf('\n=== ÉTAPE 6: ÉVALUATION DES PERFORMANCES ===\n');

% Calcul de l'erreur RMS entre la réponse du filtre et la cible
freq_eval = freq_filter(freq_filter >= 50 & freq_filter <= 20000);
target_eval = interp1(freq_filter, gain_dB, freq_eval);
filter_eval = interp1(f_response, H_fir_dB, freq_eval);

rmse = sqrt(mean((target_eval - filter_eval).^2));
correlation = corrcoef(target_eval, filter_eval);

fprintf('Performances du filtre égalisateur:\n');
fprintf('- RMSE: %.2f dB\n', rmse);
fprintf('- Corrélation avec la cible: %.3f\n', correlation(1,2));
fprintf('- Retard de groupe (approximatif): %.2f ms\n', filter_order/(2*Fs)*1000);

% Analyse de stabilité (pour information)
poles = roots([1, zeros(1, length(h_fir)-1)]);  % FIR n'a que des zéros
zeros_fir = roots(h_fir);

fprintf('\nCaractéristiques du filtre FIR:\n');
fprintf('- Nombre de zéros: %d\n', length(zeros_fir));
fprintf('- Stabilité: Inconditionnellement stable (FIR)\n');
fprintf('- Phase linéaire: %s\n', 'Oui (filtre symétrique)');

%% ÉTAPE 7: SAUVEGARDE DES RÉSULTATS
fprintf('\n=== ÉTAPE 7: SAUVEGARDE ===\n');

% Sauvegarde des paramètres et résultats
results.freq_measured = freq_measured;
results.P_sans_mousse = P_sans_mousse;
results.P_avec_mousse = P_avec_mousse;
results.attenuation_dB = attenuation_dB;
results.filter_coefficients = h_fir;
results.freq_response = f_response;
results.H_fir_dB = H_fir_dB;
results.H_fir_phase = H_fir_phase;
results.rmse_performance = rmse;
results.correlation = correlation(1,2);

% Optionnel: Sauvegarde en fichier .mat
% save('acoustic_equalizer_results.mat', 'results');

fprintf('Analyse terminée avec succès!\n');
fprintf('Filtre égalisateur prêt pour implémentation.\n');

%% FONCTIONS UTILITAIRES (si nécessaires)
function display_filter_specs(h, Fs)
    % Affichage des spécifications du filtre
    fprintf('\nSpécifications du filtre:\n');
    fprintf('- Ordre: %d\n', length(h)-1);
    fprintf('- Type: FIR\n');
    fprintf('- Fréquence d''échantillonnage: %d Hz\n', Fs);
    fprintf('- Retard: %.2f ms\n', (length(h)-1)/(2*Fs)*1000);
end