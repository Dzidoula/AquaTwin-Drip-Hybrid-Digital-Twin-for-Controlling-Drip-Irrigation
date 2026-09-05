function [should_irrigate, duration_s, volume, soil_moisture, severe_stress, psi_new, theta_infiltre_new, animation, eto_mm_jour, pluie_48h_mm] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien, psi_old, theta_infiltre, pas_heure, typeSol)

if nargin < 6 || isempty(theta_infiltre)
    theta_infiltre = 0; % meme valeur initiale que main.m avant sa boucle
end
if nargin < 7 || isempty(pas_heure)
    pas_heure = 1; % heures — meme valeur par defaut que les runs de main.m observes
end
if nargin < 8
    typeSol = [];
end

% Extraction, API-facing, de UNE seule iteration de la boucle de main.m —
% sans la boucle temps-reel, sans pause(pas_heure*3600), sans les
% animations/tracés (Trace2D, Animation*, figure(100) manuelle), qui sont
% pensés pour un affichage MATLAB interactif, pas pour un appel API.
%
% main.m original garde l'etat du sol (psi_old ET theta_infiltre) en RAM
% entre deux passages de boucle ; ici l'appelant (le backend) doit les
% persister et les repasser au prochain appel pour le meme champ. Passer
% psi_old=[] pour le tout premier appel (utilise InitialSolution comme
% dans main.m) ; theta_infiltre=[] ou omis vaut alors 0, comme dans
% main.m avant sa boucle.
%
% Cette fonction ne fait AUCUNE modification a la logique physique
% d'origine : elle reprend les memes appels, dans le meme ordre, que le
% corps de boucle de main.m.

% Meme motif que main.m (lignes 7-9) : si l'appelant fournit deja typeSol
% (ex. choisi par le fermier a l'inscription), on l'utilise directement et
% on evite l'appel reseau a ISRIC. Sinon, on le derive comme avant.
if isempty(typeSol)
    typeSol = classifySoilType(lat, lon);
end

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[T,RH,u2,Rs,P] = DataEvapotranspiration(lat,lon);
[alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s] = vanMualemParametersValor(lat,lon);

if isempty(psi_old)
    psi_old = InitialSolution(lat,lon,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
end

heure = datenum2hour();

% ETo/pluie pour l'affichage cote appli (cartes HUMIDITE/ETO/PLUIE 48H du
% Home) — calcules ici, avant le "return" anticipe ci-dessous, pour qu'ils
% soient toujours renvoyes meme un jour ou ce n'est pas encore l'heure
% d'irriguer. [] quand Open-Meteo est indisponible (T<0, meme convention
% que le reste du fichier) : l'appli affiche alors "-" plutot qu'une
% fausse valeur.
if (T < 0)
    eto_mm_jour = [];
else
    % Meme formule Penman-Monteith horaire (FAO-56) que
    % CalculEvapotranspirationJournaliere.m/PenmanMontheithParameter.m,
    % sans la conversion vers les unites internes du solveur (m/s) — ici
    % une estimation mm/jour pour affichage, en etendant le taux horaire
    % moyen sur 24h.
    %
    % BUG SUSPECTE (present dans PenmanMontheithParameter.m lui-meme, donc
    % aussi dans le calcul interne d'ETo/Tpot/ETr utilise par le solveur —
    % pas quelque chose introduit ici) : `Rn=(1-alpha)*Rs` traite Rs
    % (rayonnement Open-Meteo, en W/m^2) comme s'il etait deja en
    % MJ/m^2/heure, l'unite qu'attend la formule FAO-56 horaire
    % (coefficients 0.409 et 37). Sans conversion, Rn est surestime d'un
    % facteur ~278 (1 W/m^2 pendant 1h = 0.0036 MJ/m^2), ce qui donnait un
    % ETo affiche de l'ordre de 800 mm/jour au lieu de quelques mm/jour.
    % Corrige ICI (conversion Rs -> MJ/m^2/h avant l'appel) pour que la
    % carte ETO de l'appli montre une valeur plausible, SANS toucher
    % PenmanMontheithParameter.m ni le reste du solveur (meme fonction
    % partagee par TenseurSol/Tpot/ETr en production — la corriger en
    % place demande confirmation d'Alex, comme les autres bugs releves
    % cette session). A confirmer avec lui.
    Rs_MJ_par_m2_h = Rs * 0.0036;
    [Delta_disp, Gamma_disp, Rn_disp, G_disp, T_disp, VPD_disp, u2_disp] = PenmanMontheithParameter(T,RH,u2,Rs_MJ_par_m2_h);
    ET0_hourly_mm = max((0.409*Delta_disp.*(Rn_disp-G_disp)+Gamma_disp.*(37./(T_disp+273)).*abs(u2_disp).*VPD_disp)./(Delta_disp+Gamma_disp.*(1+0.208*abs(u2_disp))), 0);
    eto_mm_jour = mean(ET0_hourly_mm) * 24;
end
if isempty(P)
    pluie_48h_mm = [];
else
    pluie_48h_mm = sum(P(1:min(48, numel(P))));
end

if (T < 0)
    [Tmax,V] = TempsEtVolumeEauNecessaireIrrigationAbsolu(q_irr,total_dof,heure,culture,typeSol,lat,lon);
else
    [Tmax,V] = TempsEtVolumeEauNecessaireIrrigation(q_irr,total_dof,JourJulien,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s,psi_old);
end

[max_iter,tol,t] = valorsForSimulation(Tmax);
[h,r,zmax] = coordonnesPlot();
[dr,dz,ri,zi,zr,R] = coordonneesRacinaire(r,zmax,total_dof,JourJulien,culture);
Theta_r = zeros(length(zi),1);

% Meme construction que main.m juste avant son appel a
% TraceDeLaTeneurEnEauRacinaireVeri : une matrice [length(t) x total_dof],
% seule la 1ere ligne (l'etat courant) est renseignee.
Psi_solution = zeros(length(t), total_dof);
Psi_solution(1,:) = psi_old + CalculTheta(theta_infiltre, lat, lon, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s);

Theta_root = TraceDeLaTeneurEnEauRacinaireVeri(Theta_r,Psi_solution,heure,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
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
    theta_infiltre_new = theta_infiltre;
    animation = struct('frames', {{}});
    return;
end

if (T < 0)
    [solution,Tmax,V] = DDFVRichardIrrigation(psi_old,heure,culture,typeSol,lat,lon);
else
    [solution, Erreur] = DDFVRichardIrrigationAPI(psi_old,heure,culture,typeSol,lat,lon,Tmax,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
end

% Images de l'evolution du bulbe d'humectation pour l'animation cote appli
% — voir export_animation_frames.m. Ne depend que de `solution` (deja
% calcule ci-dessus) et des parametres de sol ; aucun impact sur le reste
% du calcul.
animation = export_animation_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, t);

% Grilles 12 images (debut/fin d'irrigation) demandees par Alexandre —
% voir Trace2D.m/Trace2DFin.m (portage headless : export_trace2d_frames.m/
% export_trace2dfin_frames.m). Meme `solution`/parametres, aucun nouveau
% calcul physique.
animation.trace_debut = export_trace2d_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, t);
animation.trace_fin = export_trace2dfin_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, t);

ETo = CalculEvapotranspirationJournaliere(heure,culture,typeSol,lat,lon,T,RH,u2,Rs);
Tpot = TranspirationPotentielle(max(ETo),heure,culture);
ETr = EvapotranspirationRelle(max(Tpot),max(ETo),SH,heure,culture);

[SH,Pt,l] = StresseHydriqueEtPotentielHydrique(Theta_root,heure,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
[SH, Pt,t_t,Theta_root] = TraceTeneurEnEauRacinaireStresseHydriqueEtPotentielHydrique_(lat,lon,culture,typeSol,Tmax+3600,solution,Tmax,heure,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s);
close all; % les fonctions ci-dessus ouvrent des figures meme en mode headless

% Series temporelles (teneur en eau racinaire, stress hydrique, potentiel
% hydrique) deja calculees ci-dessus par TraceTeneurEnEauRacinaireStresseHydriqueEtPotentielHydrique_
% pour son propre graphique 3-panneaux (figure ignoree en headless) —
% exportees ici telles quelles pour l'appli, sans nouveau calcul.
animation.trend_t_s = t_t(:)';
animation.trend_theta_root = Theta_root(:)';
animation.trend_stress_hydrique = SH(:)';
animation.trend_potentiel_hydrique = Pt(:)';

should_irrigate = true;
duration_s = max(Tmax);
volume = max(V);
soil_moisture = mean(Theta_root);
severe_stress = mean(SH) > 0.5; % a affiner avec Alex : seuil provisoire

% BUG (present tel quel dans main.m, hors de notre fork aussi) :
% `Temps = heure + pas_heure` est en heures (ex: 15), mais `t_t` couvre la
% fenetre d'un seul evenement d'irrigation en secondes (quelques
% centaines) — donc `interp1` interroge presque toujours hors plage et
% renvoie NaN. On ne sait pas encore quelle est la bonne conversion
% voulue par Alex, donc plutot que d'inventer un facteur d'echelle, on
% borne la requete a la derniere valeur connue (etat stationnaire en fin
% de fenetre modelisee) pour rester utilisable en attendant sa reponse.
% A REVOIR avec Alex.
Temps = heure + pas_heure;
Temps_clamped = min(max(Temps, min(t_t)), max(t_t));
theta_infiltre_new = interp1(t_t, Theta_root, Temps_clamped);
psi_new = psi_old + CalculTheta(theta_infiltre_new, lat, lon, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s);

end

function h = datenum2hour()
    % `hour(datetime('now'))` (utilise par main.m) a besoin du package
    % Octave optionnel 'datatypes', absent sur ce serveur — equivalent en
    % Octave core.
    c = clock();
    h = c(4);
end
