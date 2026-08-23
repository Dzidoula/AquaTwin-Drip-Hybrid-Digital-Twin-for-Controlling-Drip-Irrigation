function [Rendement, Biomasse] = PredictSeasonYield(culture, irrigationCoverage, EToBase)
% PredictSeasonYield — prevision de rendement sur tout le cycle de culture,
% formule standard AquaCrop-FAO (biomasse = WP x transpiration cumulee,
% rendement = biomasse x indice de recolte).
%
% Cette fonction n'est PAS un correctif en place de PredictPreviousHarvest.m /
% PlanteFeatures.m : ces deux fichiers restent tels quels car ils sont aussi
% utilises par le moteur de recommandation quotidienne deja en production
% (TranspirationPotentielle.m -> TempsEtVolumeEauNecessaireIrrigation.m), et
% les corriger en place changerait ce moteur sans tests dedies pour ca.
%
% Deux bugs confirmes dans ces fichiers, evites ici plutot que reproduits :
%   1. PlanteFeatures.m compare `JJ/24 <= Lini` alors que JJ est deja un
%      compte de jours (1..T) et Lini aussi — division par 24 en trop, qui
%      bloque quasiment tout le cycle au stade initial.
%   2. PredictPreviousHarvest.m calcule `Tr = Tr + Tpot/ETo` alors que
%      `Tpot = ETo*Kc` — la division annule l'ETo, la "transpiration"
%      accumulee n'est plus en mm reels.
% A signaler a Alex ; formule standard appliquee correctement ci-dessous en
% attendant.
%
% irrigationCoverage : 0.3 a 1.0 — fraction du besoin en eau couverte par
% l'irrigation (le levier de scenario de l'ecran Previsions). Absent de
% PredictPreviousHarvest.m d'origine (qui suppose toujours une couverture
% totale) ; ajoute ici pour le meme usage que crop_simulator.dart.
% EToBase : evapotranspiration de reference fixe (mm/j) — pas de meteo
% reelle jour par jour a cet horizon (hors perimetre, cf. spec previsions).

    T = Croissance(culture);
    [WP, Hi] = parameterAquaCrop(culture);

    Rendement = zeros(T, 1);
    Biomasse = zeros(T, 1);
    Tr = 0;

    for jour = 1:T
        KcTr = PlanteFeaturesCorrigee(jour, culture);
        Tpot = EToBase * KcTr;
        Tr = Tr + irrigationCoverage * Tpot;
        B = WP * Tr;
        Biomasse(jour) = B;
        Rendement(jour) = B * Hi;
    end

end
