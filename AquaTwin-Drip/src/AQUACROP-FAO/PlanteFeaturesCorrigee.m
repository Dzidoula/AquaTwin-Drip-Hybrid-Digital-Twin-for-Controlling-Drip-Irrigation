function KcTr = PlanteFeaturesCorrigee(JJ, culture)
% Copie de PlanteFeatures.m (memes constantes par culture, verifiees a
% l'identique) avec un seul changement : le seuil de stade compare JJ
% directement (JJ est deja un compte de jours) au lieu de JJ/24, qui
% bloquait la plante au stade initial pendant ~24x trop longtemps.
% Utilisee uniquement par PredictSeasonYield.m — voir son commentaire
% d'entete pour le detail du bug evite ici.

switch lower(culture)

    case 'tomate'
        Lini = 25;
        Ldev = 40;
        Lmid = 35;
        Lend = 25;

        Kc_ini = 0.60;
        Kc_mid = 1.15;
        Kc_end = 0.80;

    case 'coton'
        Lini = 30;
        Ldev = 50;
        Lmid = 60;
        Lend = 40;

        Kc_ini = 0.35;
        Kc_mid = 1.15;
        Kc_end = 0.60;

    case 'mais'
        Lini = 20;
        Ldev = 30;
        Lmid = 40;
        Lend = 30;

        Kc_ini = 0.40;
        Kc_mid = 1.20;
        Kc_end = 0.60;

    otherwise
        error('Culture inconnue');

end

if JJ <= Lini
    KcTr = Kc_ini;
elseif JJ <= (Lini + Ldev)
    KcTr = Kc_ini + (Kc_mid - Kc_ini) * (JJ - Lini) / Ldev;
elseif JJ <= (Lini + Ldev + Lmid)
    KcTr = Kc_mid;
elseif JJ <= (Lini + Ldev + Lmid + Lend)
    KcTr = Kc_mid - (Kc_mid - Kc_end) * (JJ - Lini - Ldev - Lmid) / Lend;
else
    KcTr = Kc_end;
end

end
