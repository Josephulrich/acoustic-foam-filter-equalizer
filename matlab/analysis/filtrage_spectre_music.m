% --- Lecture manuelle des fichiers CSV avec séparateurs décimaux français ---
% Lecture du premier fichier (spectre original)
fileID = fopen('spectre_perfect_edsheraan.csv', 'r');
header = fgetl(fileID);
frequencies = [];
levels_original = [];

while ~feof(fileID)
    line = fgetl(fileID);
    parts = strsplit(line, '\t');
    if length(parts) >= 2
        freq = str2double(strrep(parts{1}, ',', '.'));
        level = str2double(strrep(parts{2}, ',', '.'));
        if ~isnan(freq) && ~isnan(level)
            frequencies = [frequencies; freq];
            levels_original = [levels_original; level];
        end
    end
end
fclose(fileID);

% Lecture du second fichier (spectre avec membrane)
fileID = fopen('spectre_perfect_edsheraan_membrane.csv', 'r');
header = fgetl(fileID);
frequencies_mem = [];
levels_membrane = [];

while ~feof(fileID)
    line = fgetl(fileID);
    parts = strsplit(line, '\t');
    if length(parts) >= 2
        freq = str2double(strrep(parts{1}, ',', '.'));
        level = str2double(strrep(parts{2}, ',', '.'));
        if ~isnan(freq) && ~isnan(level)
            frequencies_mem = [frequencies_mem; freq];
            levels_membrane = [levels_membrane; level];
        end
    end
end
fclose(fileID);

% Créer les tables
original = table(frequencies, levels_original, 'VariableNames', {'Frequency', 'Level_Original'});
membrane = table(frequencies_mem, levels_membrane, 'VariableNames', {'Frequency', 'Level_Membrane'});

% Fusionner les deux jeux de données sur la fréquence
data = innerjoin(original, membrane, 'Keys', 'Frequency');

% Calcul de l'atténuation (en dB)
data.Attenuation = data.Level_Original - data.Level_Membrane;

% Tracer la courbe d'atténuation
figure;
semilogx(data.Frequency, data.Attenuation, 'b', 'LineWidth', 1.5);
xlabel('Fréquence (Hz)');
ylabel('Atténuation (dB)');
title('Atténuation causée par la mousse');
grid on;
xlim([20 20000]);
legend('Mousse');

% --- Création d’un filtre FIR correcteur ---
Fs = 44100; % fréquence d’échantillonnage
N = 65;     % ⚠️ nombre impair => filtre d'ordre pair (N-1) et stable à Nyquist

% Trier les données
data = sortrows(data, 'Frequency');

% Normaliser la fréquence (0 à 1)
f_norm = data.Frequency / (Fs/2);
f_norm = max(0, min(1, f_norm));

% Gain de correction (en linéaire)
g_db = data.Attenuation;
g_lin = 10.^(g_db / 20);

% Ajouter extrémités pour interpolation stable
f_norm_ext = [0; f_norm; 1];
g_lin_ext = [g_lin(1); g_lin; g_lin(end)];

% Interpolation
f_interp = linspace(0, 1, N);
g_interp = interp1(f_norm_ext, g_lin_ext, f_interp, 'pchip', 'extrap');

% Conception du filtre FIR
n_order = N - 1;                          % ordre du filtre (pair)
window = hamming(N);                     % fenêtre de taille N = n_order + 1
b = fir2(n_order, f_interp, g_interp, window);  % filtre corrigé

% Tracer la réponse du filtre
fvtool(b, 1);

% Sauvegarder les coefficients
writematrix(b', 'fir_coeffs_sigma.txt', 'Delimiter', 'tab');
disp('✅ Fichier "fir_coeffs_sigma.txt" prêt à être importé dans SigmaStudio.');

% Vérification de la réponse fréquentielle du filtre
figure;
[h, w] = freqz(b, 1, 1024, Fs);
mag = 20*log10(abs(h));
semilogx(w, mag, 'r', 'LineWidth', 1.5);
hold on;
semilogx(data.Frequency, g_db, 'b--', 'LineWidth', 1);
xlabel('Fréquence (Hz)');
ylabel('Gain (dB)');
title('Réponse du filtre vs atténuation cible');
grid on;
xlim([20 20000]);
legend('Réponse du filtre', 'Atténuation mesurée');

