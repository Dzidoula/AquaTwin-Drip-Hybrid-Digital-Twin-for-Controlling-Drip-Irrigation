function [Rendement, Biomasse] = PredictSeasonYieldDataDriven(lat, lon, culture, dateSemence, joursTest, etoTest)
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
    disp(EvaluerRendement(culture, Rendement));

end

function result = run_python_json(python_cmd, script_path, input_struct)
% Ecrit `input_struct` en JSON, lance `python_cmd script_path in out`,
% relit la sortie JSON — meme convention que engine_runner.py cote
% backend vis-a-vis d'Octave, en miroir ici pour qu'Octave appelle Python.

    input_path = tempname();
    output_path = tempname();

    fid = fopen(input_path, 'w');
    fprintf(fid, '%s', jsonencode(input_struct));
    fclose(fid);

    [status, cmdout] = system(sprintf('%s %s %s %s', python_cmd, script_path, input_path, output_path));
    if status ~= 0
        error('run_python_json: %s a echoue (code %d): %s', script_path, status, cmdout);
    end
    if exist(output_path, 'file') ~= 2
        error('run_python_json: %s n''a produit aucune sortie', script_path);
    end

    result = jsondecode(fileread(output_path));

    delete(input_path);
    delete(output_path);
end
