% Test manuel (jetable) de dailyIrrigationRecommendation — un premier
% appel (psi_old vide) suivi d'un second qui reutilise l'etat retourne
% par le premier, pour verifier le cycle complet incluant la persistance
% de l'etat entre deux appels.

addpath(genpath(fileparts(mfilename('fullpath'))));

culture = 'mais';
lat = 9.3;
lon = 2.6;
JourJulien = 220; % milieu de saison, arbitraire pour ce test

tic;
[should_irrigate, duration_s, volume, soil_moisture, severe_stress, psi_new, theta_infiltre_new] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien, [], []);
elapsed1 = toc;

fprintf('\n=== Appel 1 (etat initial) ===\n');
fprintf('Temps: %.2fs\n', elapsed1);
fprintf('should_irrigate=%d duration_s=%.2f volume=%.2f soil_moisture=%.4f severe_stress=%d\n', ...
    should_irrigate, duration_s, volume, soil_moisture, severe_stress);

tic;
[should_irrigate2, duration_s2, volume2, soil_moisture2, severe_stress2, psi_new2, theta_infiltre_new2] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien + 1, psi_new, theta_infiltre_new);
elapsed2 = toc;

fprintf('\n=== Appel 2 (etat reutilise) ===\n');
fprintf('Temps: %.2fs\n', elapsed2);
fprintf('should_irrigate=%d duration_s=%.2f volume=%.2f soil_moisture=%.4f severe_stress=%d\n', ...
    should_irrigate2, duration_s2, volume2, soil_moisture2, severe_stress2);

fprintf('\nTEST OK — temps total: %.2fs\n', elapsed1 + elapsed2);
