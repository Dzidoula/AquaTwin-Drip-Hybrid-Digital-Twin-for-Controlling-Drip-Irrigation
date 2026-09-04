function [Rendement, OptimalETo, Appreciation, NIterations] = OptimalHarvestDataDriven(culture, dateSemis, predictEvapo, maxIter)
% Port Octave de OptimalHarvest.m — meme logique de recherche, mais
% utilisable sous Octave et sans risque de boucle infinie.
%
% Trois differences deliberees avec OptimalHarvest.m :
%
%   1. `datetime(DateSemis, 'InputFormat', ...)` et `datetime('today')`
%      (types MATLAB, absents du coeur d'Octave — voir le meme probleme
%      deja documente dans dailyIrrigationRecommendation.m pour
%      `hour(datetime('now'))`) sont remplaces par `datenum`/`now()`,
%      qui font partie du coeur d'Octave.
%
%   2. Les appels `py.*` vers PredictionRendementTest sont remplaces par
%      un appel `system()` (via le meme helper run_python_json.m que
%      PredictSeasonYieldDataDriven.m) vers prediction_rendement_cli.py —
%      meme logique Python, sans interop MATLAB-Python.
%
%   3. LA PLUS IMPORTANTE : `while 0<1` (boucle infinie) devient
%      `while n_iter < maxIter`. Ce n'est pas juste une precaution :
%      OptimalHarvest.m ne peut MATERIELLEMENT PAS s'arreter seul.
%      Sa condition d'arret est `strcmpi(appreciation, 'Excellent')`,
%      mais EvaluerRendement.m (verifie) ne renvoie jamais cette chaine —
%      seulement 'Faible', 'Bon' ou 'Exceptionnel'. C'etait donc deja une
%      boucle infinie chez Alex, meme sous MATLAB, meme sans notre limite.
%      On corrige ici la comparaison vers 'Exceptionnel' (la seule valeur
%      qu'EvaluerRendement.m peut effectivement renvoyer en haut de
%      gamme) pour que l'arret anticipe fonctionne enfin comme prevu —
%      a confirmer avec Alex que c'est bien l'intention (sinon, retirer
%      cette correction et ne garder que la limite d'iterations).
%
%   4. BUG DECOUVERT A L'EXECUTION (pas un artefact du portage) :
%      OptimalHarvest.m ecrit `PredictEvapo(AgePlante+1) = BestETo`, et
%      ETEND le vecteur (`PredictEvapo = [PredictEvapo, BestETo]`) si
%      `AgePlante+1` depasse sa longueur actuelle — ce qui arrive dans la
%      pratique dans tous les cas ou le champ est plus vieux que la duree
%      du cycle de la culture (`Croissance(culture)`), un cas tres courant.
%      Mais `PredictPreviousHarvest` renvoie TOUJOURS un vecteur de
%      longueur fixe T = Croissance(culture), quelle que soit la longueur
%      de son entree ETo — donc apres extension, `PredictEvapo` et
%      `Rendement_` (qui alimentent tous deux le modele Python suivant)
%      ont des longueurs differentes, ce qui fait planter
%      PredictionRendementTest.py (`pd.DataFrame` exige des colonnes de
%      meme longueur). Corrige ici en bornant l'indice a
%      `min(AgePlante+1, length(PredictEvapo))` au lieu d'etendre le
%      vecteur — sans objet de toute facon puisque PredictPreviousHarvest
%      ignore tout ce qui depasse T. A confirmer avec Alex.
%
%   5. AUTRE BUG DECOUVERT A L'EXECUTION : `choice2 = max(0, mean - k*variance)`
%      peut valoir exactement 0 (arrive en pratique avec une vraie serie
%      ETo issue de la meteo reelle, moyenne/variance faibles). Si ce 0
%      est retenu, `PredictPreviousHarvest` divise ensuite par cette
%      valeur nulle (`Tpot/v` avec `v=ETo(i)=0`) -> NaN, que
%      EvaluerRendement.m classe alors, a tort, en 'Exceptionnel' (une
%      comparaison avec NaN est toujours fausse, donc on tombe dans le
%      dernier "else"). Corrige ici par un plancher strictement positif
%      (`1e-3`) au lieu de 0 — une ETo nulle n'a pas de sens physique de
%      toute facon. A confirmer avec Alex.
%
% Entrees :
%   culture      : 'mais' | 'tomate' | 'coton'
%   dateSemis    : chaine 'YYYY-MM-DD'
%   predictEvapo : vecteur ETo (mm/jour) deja connu/predit, un point par
%                  jour du cycle (meme entree que l'ETo_py d'OptimalHarvest.m)
%   maxIter      : optionnel, defaut 20 — limite de securite
%
% Sorties :
%   Rendement    : rendement final (kg/ha), somme journaliere
%   OptimalETo   : derniere valeur d'ETo retenue par la recherche
%   Appreciation : 'Faible' | 'Bon' | 'Exceptionnel'
%   NIterations  : nombre d'iterations reellement effectuees (pour
%                  distinguer un arret naturel d'un arret par la limite)

    if nargin < 4 || isempty(maxIter)
        maxIter = 20;
    end

    this_dir = fileparts(mfilename('fullpath'));
    python_cmd = getenv('PYTHON_CMD');
    if isempty(python_cmd)
        python_cmd = 'python3';
    end

    pas_choix = 1e-3;

    age_plante = floor(now() - datenum(dateSemis, 'yyyy-mm-dd'));

    predict_evapo = predictEvapo(:)';
    variance = var(predict_evapo);
    vect_choice = min(predict_evapo):pas_choix:max(predict_evapo);

    [rendement_, biomasse] = PredictPreviousHarvest(culture, predict_evapo);
    rendement_ = rendement_(:)';

    Rendement = sum(rendement_);
    OptimalETo = NaN;
    Appreciation = EvaluerRendement(culture, Rendement);
    n_iter = 0;

    while n_iter < maxIter && ~strcmpi(Appreciation, 'Exceptionnel')
        n_iter = n_iter + 1;

        k = vect_choice(randi(numel(vect_choice)));
        choice1 = mean(predict_evapo) + k * variance;
        % Plancher strictement positif, pas 0 — voir la note 5 ci-dessus.
        choice2 = max(1e-3, mean(predict_evapo) - k * variance);

        yield_input = struct( ...
            'eto', predict_evapo, ...
            'rendement', rendement_, ...
            'v_a_predire', [choice1 choice2]);
        yield_output = run_python_json(python_cmd, fullfile(this_dir, 'prediction_rendement_cli.py'), yield_input);
        yield = yield_output.yield_predicted(:)';

        [~, idx] = max(yield);
        if idx == 1
            best_eto = choice1;
        else
            best_eto = choice2;
        end

        % Indice borne, jamais etendu — voir la note 4 ci-dessus.
        update_idx = min(age_plante + 1, length(predict_evapo));
        predict_evapo(update_idx) = best_eto;

        [rendement_, biomasse] = PredictPreviousHarvest(culture, predict_evapo);
        rendement_ = rendement_(:)';

        Rendement = sum(rendement_);
        OptimalETo = best_eto;
        Appreciation = EvaluerRendement(culture, Rendement);
    end

    NIterations = n_iter;

end
