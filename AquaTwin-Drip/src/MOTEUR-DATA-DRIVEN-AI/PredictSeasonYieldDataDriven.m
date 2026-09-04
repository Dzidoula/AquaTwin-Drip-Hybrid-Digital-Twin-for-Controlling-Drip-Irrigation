function [Rendement, Biomasse, Appreciation, RendementParJour, BiomasseParJour] = PredictSeasonYieldDataDriven(lat, lon, culture, dateSemence, joursTest, etoTest)
% Port Octave de rendementPredictionGood.m — meme logique, meme resultat,
% mais utilisable depuis notre pipeline serveur headless.
%
% Deux differences deliberees avec rendementPredictionGood.m, aucune ne
% change la logique de prediction elle-meme :
%   1. Les trois `input()` interactifs (date de semis, jours a tester,
%      valeurs ETo a tester) deviennent de vrais parametres — un `input()`
%      bloquerait indefiniment un `octave --no-gui` lance sans terminal
%      attache (notre backend l'appelle via subprocess), jusqu'au timeout
%      de 30 min.
%   2. Les appels `py.*` (interop MATLAB-Python, absent d'Octave) sont
%      remplaces par des appels `system()` vers deux scripts Python en
%      ligne de commande (evapotranspiration_culture_cli.py,
%      prediction_rendement_cli.py) — meme convention JSON-fichier-en/
%      JSON-fichier-sortie que le moteur Octave utilise deja vis-a-vis du
%      backend FastAPI (voir engine_runner.py). Ces deux scripts
%      n'enveloppent que EvapotranspirationCulture.py et
%      PredictionRendementTest.py tels quels, sans toucher a leur logique.
%
% NOTE : rendementPredictionGood.m importe le module Python
% 'PredictionRendement' mais appelle en realite
% 'PredictionRendementTest.PredictionRendementTest' — deux fonctions
% differentes (PredictionRendement.py vs PredictionRendementTest.py). On
% reprend ici exactement ce que le script execute reellement
% (PredictionRendementTest), pas ce que son import laisse croire — a
% confirmer avec Alex si c'est bien le modele voulu.
%
% Entrees :
%   lat, lon      : coordonnees du champ
%   culture       : 'mais' | 'tomate' | 'coton'
%   dateSemence   : chaine 'YYYY-MM-DD' (etait un input() texte)
%   joursTest     : vecteur des indices de jours a tester, ex. [6 9 12]
%                   (etait le vecteur A saisi au clavier)
%   etoTest       : vecteur des valeurs ETo a tester pour ces jours,
%                   meme longueur que joursTest (etait saisi jour par jour)
%
% Sorties : Rendement, Biomasse — identiques a celles de
% rendementPredictionGood.m pour les memes entrees.

    this_dir = fileparts(mfilename('fullpath'));
    python_cmd = getenv('PYTHON_CMD');
    if isempty(python_cmd)
        python_cmd = 'python3';
    end

    T = Croissance(culture);

    %% Evapotranspiration (Python, EvapotranspirationCulture.py)
    eto_input = struct('lat', lat, 'lon', lon, 'date_semence', dateSemence, 't_croissance', T);
    eto_output = run_python_json(python_cmd, fullfile(this_dir, 'evapotranspiration_culture_cli.py'), eto_input);
    ETo_all = eto_output.eto(:);

    %% Rendement AquaCrop (Octave pur, deja compatible)
    [Rendement_, Biomasse_] = PredictPreviousHarvest_(culture, ETo_all);

    % Copie pristine (avant la mise a zero des jours testes ci-dessous) —
    % c'est celle-ci qui sert de courbe jour-par-jour pour l'affichage,
    % voir la note plus bas pres de RendementParJour/BiomasseParJour.
    RendementParJour = Rendement_;
    BiomasseParJour = Biomasse_;

    A = joursTest(:)';
    for k = 1:length(A)
        if A(k) <= length(Rendement_)
            Rendement_(A(k)) = 0;
        end
    end

    ET_A_Mod = etoTest(:)';

    %% Prediction du rendement aux jours testes (Python, PredictionRendementTest.py)
    yield_input = struct('eto', ETo_all(:)', 'rendement', Rendement_(:)', 'v_a_predire', ET_A_Mod);
    yield_output = run_python_json(python_cmd, fullfile(this_dir, 'prediction_rendement_cli.py'), yield_input);
    Yield = yield_output.yield_predicted(:)';

    [WP, Hi] = parameterAquaCrop(culture);
    Rendement = sum(Rendement_) + sum(Yield);
    Biomasse = Rendement / Hi;
    Appreciation = EvaluerRendement(culture, Rendement);
    disp(Appreciation);

    % RendementParJour/BiomasseParJour (voir plus haut, captures avant la
    % mise a zero des jours testes) : la courbe jour-par-jour pour
    % l'affichage cote appli. C'est deja une courbe plus realiste que celle
    % du moteur physique affiche a cote (qui, lui, utilise une ETo fixe de
    % 5 mm/j) puisqu'elle suit l'ETo prevue reelle jour par jour
    % (EvapotranspirationCulture.py). On n'y substitue PAS la valeur
    % predite par le modele ML aux jours testes (comme le fait le calcul
    % du total scalaire ci-dessus) : ca creerait un pic visuel absurde sur
    % la courbe (le ML predit une grandeur qui n'est pas sur la meme
    % echelle qu'un increment journalier — voir la note sur
    % `sum(Rendement_) + sum(Yield)` plus haut). Le resultat du scenario
    % teste (avec ces jours) reste visible dans les cartes Rendement/
    % Biomasse sous le graphique, pas sur la courbe elle-meme.

end
