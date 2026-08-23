% run_season_prediction.m
%
% CLI wrapper, callable from the backend as:
%   octave run_season_prediction.m <input.json> <output.json>
%
% Reads {culture, irrigation_coverage} from <input.json>, calls
% PredictSeasonYield (see AQUACROP-FAO/PredictSeasonYield.m for why this is
% a new function rather than a fix of PredictPreviousHarvest.m in place),
% writes the day-by-day biomass/rendement series plus the final yield and
% appreciation to <output.json>.

addpath(genpath(fileparts(mfilename('fullpath'))));

args = argv();
if length(args) < 2
    error('Usage: octave run_season_prediction.m <input.json> <output.json>');
end
input_path = args{1};
output_path = args{2};

input_json = jsondecode(fileread(input_path));

culture = input_json.culture;
irrigation_coverage = input_json.irrigation_coverage;

eto_base = 5.0;
if isfield(input_json, 'eto_base') && ~isempty(input_json.eto_base)
    eto_base = input_json.eto_base;
end

[rendement, biomasse] = PredictSeasonYield(culture, irrigation_coverage, eto_base);

appreciation = EvaluerRendement(culture, rendement(end));

result = struct();
result.points = struct('day', num2cell(1:length(rendement))', 'biomass', num2cell(biomasse), 'rendement', num2cell(rendement));
result.final_rendement = double(rendement(end));
result.appreciation = appreciation;

fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(result));
fclose(fid);
