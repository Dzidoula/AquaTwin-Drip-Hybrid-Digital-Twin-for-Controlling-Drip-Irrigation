function result = run_python_json(python_cmd, script_path, input_struct)
% Ecrit `input_struct` en JSON, lance `python_cmd script_path in out`,
% relit la sortie JSON — meme convention que engine_runner.py cote
% backend vis-a-vis d'Octave, en miroir ici pour qu'Octave appelle Python
% (remplace l'interop py.* de MATLAB, absente d'Octave). Partage entre
% PredictSeasonYieldDataDriven.m et OptimalHarvestDataDriven.m.

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
