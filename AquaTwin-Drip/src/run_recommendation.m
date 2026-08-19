% run_recommendation.m
%
% CLI wrapper, callable from the backend as:
%   octave run_recommendation.m <input.json> <output.json>
%
% Reads field/engine state from <input.json>, calls
% dailyIrrigationRecommendation (the API-facing extraction of main.m's loop
% body — see that file's header comment for context), writes the result to
% <output.json>. Exists only to give the backend a stable file-based
% interface instead of parsing Octave stdout.

addpath(genpath(fileparts(mfilename('fullpath'))));

args = argv();
if length(args) < 2
    error('Usage: octave run_recommendation.m <input.json> <output.json>');
end
input_path = args{1};
output_path = args{2};

input_json = jsondecode(fileread(input_path));

culture = input_json.culture;
lat = input_json.lat;
lon = input_json.lon;
JourJulien = input_json.jour_julien;

if isfield(input_json, 'psi_old') && ~isempty(input_json.psi_old)
    psi_old = input_json.psi_old(:);
else
    psi_old = [];
end

if isfield(input_json, 'theta_infiltre') && ~isempty(input_json.theta_infiltre)
    theta_infiltre = input_json.theta_infiltre;
else
    theta_infiltre = 0;
end

[should_irrigate, duration_s, volume, soil_moisture, severe_stress, psi_new, theta_infiltre_new] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien, psi_old, theta_infiltre);

result = struct();
result.should_irrigate = logical(should_irrigate);
result.duration_s = double(duration_s);
result.volume = double(volume);
result.soil_moisture = double(soil_moisture);
result.severe_stress = logical(severe_stress);
result.psi_old = psi_new(:)';
result.theta_infiltre = double(theta_infiltre_new);
result.jour_julien = JourJulien + 1;

fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(result));
fclose(fid);
