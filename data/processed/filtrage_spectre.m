% === Charger les données depuis Excel ===
data = readtable('data_matlab.xlsx', 'Sheet', 'Mesure matlab');
% Colonnes (correction de la syntaxe d'accès aux colonnes)
frequences = data.Freq_Hz_; 
mesure = data.Mesuree;

% === Définir les bandes logarithmiques (octave) ===

bands = [32 64 128 256 512 1024 2048 4096 8192 16384];
% Préparer tableaux
nb = length(bands) - 1;
gain_dB = zeros(nb,1);
centers = zeros(nb,1);

% === Calcul du gain moyen par bande ===
for i = 1:nb
    fmin = bands(i);
    fmax = bands(i+1);
    centers(i) = sqrt(fmin*fmax); % fréquence centrale
    % Sélection des indices dans la bande
    idx = frequences >= fmin & frequences < fmax;
    if any(idx)
        % Valeurs mesurées dans cette bande
        selected_freqs = frequences(idx);
        selected_measurements = mesure(idx);
        
        % Calcul du rapport moyen entre la mesure et la référence
        % La référence est la valeur idéale (qui devrait être la fréquence elle-même)
        ratios = selected_measurements ./ selected_freqs;
        mean_ratio = mean(ratios);
        
        % Calcul du gain correctif en dB
        gain_dB(i) = 20 * log10(1/mean_ratio); % Correction: inverse du ratio pour compenser
    else
        gain_dB(i) = 0; % pas de données, pas de correction
    end
end

% === Afficher les résultats ===
T = table(bands(1:end-1)', bands(2:end)', centers, gain_dB, ...
    'VariableNames', {'Fmin', 'Fmax', 'CenterHz', 'Gain_dB'});
disp('=== Tableau des gains correcteurs par bande ===');
disp(T);

% === Tracer le gain correcteur à appliquer ===
figure;
semilogx(centers, gain_dB, '-o', 'LineWidth', 2);
grid on;
xlabel('Fréquence centrale (Hz)');
ylabel('Gain correctif (dB)');
title('Égaliseur compensateur (log)');
xlim([30 20000]);