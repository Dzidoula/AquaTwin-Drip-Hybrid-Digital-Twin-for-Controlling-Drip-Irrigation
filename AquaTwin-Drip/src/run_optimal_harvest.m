% run_optimal_harvest.m
%
% CLI wrapper, callable from the backend as:
%   octave run_optimal_harvest.m <input.json> <output.json>
%
% Reads {lat, lon, culture, date_semence, max_iter?} from <input.json>,
% first predicts a baseline ETo series (EvapotranspirationCulture.py, same
% model as PredictSeasonYieldDataDriven.m's own first step), then searches
% for the best-yield ETo via OptimalHarvestDataDriven.m — the Octave-
% compatible, iteration-capped port of Alex's OptimalHarvest.m.

addpath(genpath(fileparts(mfilename('fullpath'))));

args = argv();
if length(args) < 2
    error('Usage: octave run_optimal_harvest.m <input.json> <output.json>');
end
input_path = args{1};
output_path = args{2};

input_json = jsondecode(fileread(input_path));

lat = input_json.lat;
lon = input_json.lon;
culture = input_json.culture;
date_semence = input_json.date_semence;

max_iter = 20;
if isfield(input_json, 'max_iter') && ~isempty(input_json.max_iter)
    max_iter = input_json.max_iter;
end

this_dir = fileparts(mfilename('fullpath'));
python_cmd = getenv('PYTHON_CMD');
if isempty(python_cmd)
    python_cmd = 'python3';
end

T = Croissance(culture);
eto_input = struct('lat', lat, 'lon', lon, 'date_semence', date_semence, 't_croissance', T);
eto_output = run_python_json(python_cmd, ...
    fullfile(this_dir, 'MOTEUR-DATA-DRIVEN-AI', 'evapotranspiration_culture_cli.py'), eto_input);
predict_evapo = eto_output.eto;

[Rendement, OptimalETo, Appreciation, NIterations] = ...
    OptimalHarvestDataDriven(culture, date_semence, predict_evapo, max_iter);

result = struct();
result.rendement = double(Rendement);
result.optimal_eto = double(OptimalETo);
result.appreciation = Appreciation;
result.n_iterations = double(NIterations);

fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(result));
fclose(fid);
