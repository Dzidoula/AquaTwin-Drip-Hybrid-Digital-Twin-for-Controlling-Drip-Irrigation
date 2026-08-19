% Spike (jetable) : verifie que le solveur de Richards tourne sous Octave
% et chronometre une seule iteration, avant d'ecrire l'extraction propre
% pour l'API. A supprimer une fois la reponse obtenue.

% Aucun addpath n'existe dans le depot d'origine (le projet est normalement
% ouvert tel quel dans MATLAB, qui indexe tous les sous-dossiers) — on le
% fait nous-memes ici pour Octave.
addpath(genpath(fileparts(mfilename('fullpath'))));

culture = 'mais';
lat = 9.3;
lon = 2.6;
typeSol = classifySoilType(lat, lon);
fprintf('Type de sol : %s\n', typeSol);

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[T,RH,u2,Rs] = DataEvapotranspiration(lat,lon);
fprintf('Meteo tailles: T=%s RH=%s u2=%s Rs=%s\n', mat2str(size(T)), mat2str(size(RH)), mat2str(size(u2)), mat2str(size(Rs)));
fprintf('Meteo (1ere valeur): T=%.2f RH=%.2f u2=%.2f Rs=%.2f\n', T(1), RH(1), u2(1), Rs(1));

[alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s] = vanMualemParametersValor(lat,lon);
fprintf('VG params: alpha=%.4f n=%.4f theta_s=%.4f theta_r=%.4f k_s=%.4f\n', ...
    alpha_vg, n_vg, theta_s, theta_r, k_s);

psi_old = InitialSolution(lat,lon,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
fprintf('psi_old: %d valeurs, min=%.4f max=%.4f\n', length(psi_old), min(psi_old), max(psi_old));

% `datetime` needs Octave's optional 'datatypes' forge package (not
% installed) — datenum/clock are core Octave, so use those instead. Only
% main.m itself (which this spike bypasses) and the unrelated
% OptimalHarvest.m use datetime() in the real pipeline, so this isn't a
% blocker for the API extraction.
c = clock();
JourJulien = floor(datenum(c(1),c(2),c(3)) - datenum(c(1),1,1)) + 1;
tic;
[Tmax,V] = TempsEtVolumeEauNecessaireIrrigation(q_irr,total_dof,JourJulien,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
fprintf('TempsEtVolumeEauNecessaireIrrigation: %.2fs, Tmax max=%.4f\n', toc, max(Tmax));

fprintf('--- Lancement DDFVRichardIrrigationAPI (le calcul lourd) ---\n');
tic;
[solution, Erreur] = DDFVRichardIrrigationAPI(psi_old,JourJulien,culture,typeSol,lat,lon,Tmax,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
elapsed = toc;
fprintf('DDFVRichardIrrigationAPI: %.2fs, solution: %d valeurs, erreur finale=%.6f\n', ...
    elapsed, length(solution), Erreur(end));

fprintf('SPIKE OK — temps total solveur: %.2fs\n', elapsed);
