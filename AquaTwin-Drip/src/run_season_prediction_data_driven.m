% run_season_prediction_data_driven.m
%
% CLI wrapper, callable from the backend as:
%   octave run_season_prediction_data_driven.m <input.json> <output.json>
%
% Reads {lat, lon, culture, date_semence, jours_test, eto_test} from
% <input.json>, calls PredictSeasonYieldDataDriven (see
% MOTEUR-DATA-DRIVEN-AI/PredictSeasonYieldDataDriven.m — the Octave-compatible
% port of Alex's rendementPredictionGood.m), writes the final rendement/
% biomasse/appreciation to <output.json>.

addpath(genpath(fileparts(mfilename('fullpath'))));

args = argv();
if length(args) < 2
    error('Usage: octave run_season_prediction_data_driven.m <input.json> <output.json>');
end
input_path = args{1};
output_path = args{2};

input_json = jsondecode(fileread(input_path));

lat = input_json.lat;
lon = input_json.lon;
culture = input_json.culture;
date_semence = input_json.date_semence;
jours_test = input_json.jours_test;
eto_test = input_json.eto_test;

[Rendement, Biomasse, Appreciation, RendementParJour, BiomasseParJour] = PredictSeasonYieldDataDriven( ...
    lat, lon, culture, date_semence, jours_test, eto_test);

result = struct();
result.rendement = double(Rendement);
result.biomasse = double(Biomasse);
result.appreciation = Appreciation;
% Meme forme que run_season_prediction.m ({day, biomass, rendement}) pour
% que l'appli puisse tracer les deux courbes (physique/IA) avec le meme
% widget.
result.points = struct('day', num2cell(1:length(RendementParJour))', ...
                        'biomass', num2cell(BiomasseParJour), ...
                        'rendement', num2cell(RendementParJour));

fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(result));
fclose(fid);
