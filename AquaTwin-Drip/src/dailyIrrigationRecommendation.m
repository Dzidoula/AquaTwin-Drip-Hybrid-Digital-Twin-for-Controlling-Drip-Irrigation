function [should_irrigate, duration_s, volume, soil_moisture, severe_stress, psi_new] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien, psi_old, pas_heure)

if nargin < 6 || isempty(pas_heure)
    pas_heure = 1; % heures — meme valeur par defaut que les runs de main.m observes
end

% Extraction, API-facing, de UNE seule iteration de la boucle de main.m —
% sans la boucle temps-reel, sans pause(pas_heure*3600), sans les
% animations/tracés (Trace2D, Animation*, figure(100) manuelle), qui sont
% pensés pour un affichage MATLAB interactif, pas pour un appel API.
%
% main.m original garde l'etat du sol (psi_old) en RAM entre deux passages
% de boucle ; ici l'appelant (le backend) doit le persister et le
% repasser au prochain appel pour le meme champ. Passer [] pour le tout
% premier appel (utilise InitialSolution comme dans main.m).
%
% Cette fonction ne fait AUCUNE modification a la logique physique
% d'origine : elle reprend les memes appels, dans le meme ordre, que le
% corps de boucle de main.m.

typeSol = classifySoilType(lat, lon);

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[T,RH,u2,Rs] = DataEvapotranspiration(lat,lon);
[alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s] = vanMualemParametersValor(lat,lon);

if isempty(psi_old)
    psi_old = InitialSolution(lat,lon,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
end

heure = datenum2hour();

if (T < 0)
    [Tmax,V] = TempsEtVolumeEauNecessaireIrrigationAbsolu(q_irr,total_dof,heure,culture,typeSol,lat,lon);
else
    [Tmax,V] = TempsEtVolumeEauNecessaireIrrigation(q_irr,total_dof,JourJulien,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
end

[max_iter,tol,t] = valorsForSimulation(Tmax);
[h,r,zmax] = coordonnesPlot();
[dr,dz,ri,zi,zr,R] = coordonneesRacinaire(r,zmax,total_dof,JourJulien,culture);
Theta_r = zeros(length(zi),1);

Theta_root = TraceDeLaTeneurEnEauRacinaireVeri(Theta_r,repmat(psi_old,1,1),heure,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
[SH,Pt,k] = StresseHydriqueEtPotentielHydriqueVeri(Theta_root,heure,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);

if k ~= 1
    % Pas encore le moment d'irriguer aujourd'hui (meme logique que
    % main.m : rien ne se passe dans ce cas, on avance au jour suivant).
    should_irrigate = false;
    duration_s = 0;
    volume = 0;
    soil_moisture = mean(Theta_root);
    severe_stress = false;
    psi_new = psi_old;
    return;
end

if (T < 0)
    [solution,Tmax,V] = DDFVRichardIrrigation(psi_old,heure,culture,typeSol,lat,lon);
else
    [solution, Erreur] = DDFVRichardIrrigationAPI(psi_old,heure,culture,typeSol,lat,lon,Tmax,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
end

ETo = CalculEvapotranspirationJournaliere(heure,culture,typeSol,lat,lon,T,RH,u2,Rs);
Tpot = TranspirationPotentielle(max(ETo),heure,culture);
ETr = EvapotranspirationRelle(max(Tpot),max(ETo),SH,heure,culture);

[SH,Pt,l] = StresseHydriqueEtPotentielHydrique(Theta_root,heure,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
[SH, Pt,t_t,Theta_root] = TraceTeneurEnEauRacinaireStresseHydriqueEtPotentielHydrique_(lat,lon,culture,typeSol,Tmax+3600,solution,Tmax,heure,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
close all; % les fonctions ci-dessus ouvrent des figures meme en mode headless

should_irrigate = true;
duration_s = max(Tmax);
volume = max(V);
soil_moisture = mean(Theta_root);
severe_stress = mean(SH) > 0.5; % a affiner avec Alex : seuil provisoire

Temps = heure + pas_heure;
theta_infiltre = interp1(t_t, Theta_root, Temps);
psi_new = psi_old + CalculTheta(theta_infiltre, lat, lon, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s);

end

function h = datenum2hour()
    % `hour(datetime('now'))` (utilise par main.m) a besoin du package
    % Octave optionnel 'datatypes', absent sur ce serveur — equivalent en
    % Octave core.
    c = clock();
    h = c(4);
end
