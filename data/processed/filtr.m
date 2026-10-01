% === 1. Paramètres ===
Fs = 48000;           % Fréquence d'échantillonnage
duration = 5;         % Durée du bruit blanc (secondes)
N = Fs * duration;    % Nombre d’échantillons

% === 2. Générer le bruit blanc ===
x = randn(N, 1);      % Bruit blanc (original)

% === 3. Courbe d'atténuation de la mousse ===
f = [50 100 200 300 400 500 600 700 800 900 1000 2000 3000 4000 5000 6000 ...
     7000 8000 9000 10000 11000 12000 13000 14000 15000 16000 17000 18000 19000 20000];
A_dB = [-3.93 -1 -1.34 -0.49 3.6 5.62 7.2 16.04 10.61 13.32 13.46 10.18 10.374 ...
         30.374 14.17 14.12 -2.28 0.98 8 5.94 9.56 -0.93 -3.14 -14.61 -6.24 -8.63 ...
        -10.77 -24.08 -16.65 -13.53];

% === 4. Préparation des filtres ===
% Ajout des extrémités à la courbe
f_full = [0, f, Fs/2];
A_dB_full = [A_dB(1), A_dB, A_dB(end)];

% Normalisation des fréquences
f_norm = f_full / (Fs/2);

% Courbe d'atténuation (mousse) en linéaire
atten_lin = 10.^(-A_dB_full / 20);  % pour la mousse
gain_lin  = 10.^( A_dB_full / 20);  % pour le filtre égaliseur

% Conception des filtres FIR
N_filt = 256;
h_mousse = fir2(N_filt, f_norm, atten_lin);
h_eq     = fir2(N_filt, f_norm, gain_lin);

% === 5. Application des filtres ===
x_mousse = filter(h_mousse, 1, x);       % Signal atténué (mousse)
x_eq     = filter(h_eq, 1, x_mousse);    % Signal corrigé (égalisé)

% === 6. Normalisation pour éviter le clipping ===
x        = x / max(abs(x));
x_mousse = x_mousse / max(abs(x_mousse));
x_eq     = x_eq / max(abs(x_eq));

% === 7. Sauvegarde audio ===
audiowrite('bruit_original.wav',      x,        Fs);
audiowrite('bruit_avec_mousse.wav',  x_mousse, Fs);
audiowrite('bruit_equalise.wav',     x_eq,     Fs);

% === 8. Affichage temporel (zoom) ===
t = (0:N-1)/Fs;
figure;
plot(t(1:1000), x(1:1000), 'k', 'DisplayName', 'Original');
hold on;
plot(t(1:1000), x_mousse(1:1000), 'r', 'DisplayName', 'Avec mousse');
plot(t(1:1000), x_eq(1:1000), 'b', 'DisplayName', 'Corrigé');
xlabel('Temps (s)');
ylabel('Amplitude');
title('Comparaison temporelle des signaux (zoom)');
legend('show');
grid on;

% === 9. Analyse fréquentielle (FFT dB) ===
nfft = 2^14;
[Px, f_fft]        = pwelch(x,        hamming(nfft), [], nfft, Fs);
[Px_mousse, ~]     = pwelch(x_mousse, hamming(nfft), [], nfft, Fs);
[Px_eq, ~]         = pwelch(x_eq,     hamming(nfft), [], nfft, Fs);

% Conversion en dB
Px_dB        = 10*log10(Px);
Px_mousse_dB = 10*log10(Px_mousse);
Px_eq_dB     = 10*log10(Px_eq);

% Affichage spectre
figure;
semilogx(f_fft, Px_dB,        'k', 'DisplayName', 'Original');
hold on;
semilogx(f_fft, Px_mousse_dB, 'r', 'DisplayName', 'Avec mousse');
semilogx(f_fft, Px_eq_dB,     'b', 'DisplayName', 'Corrigé');
xlabel('Fréquence (Hz)');
ylabel('Densité spectrale de puissance (dB/Hz)');
title('Comparaison fréquentielle des signaux');
legend('show');
grid on;
xlim([20 Fs/2]);
