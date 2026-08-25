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

if isfield(input_json, 'size_hectares') && ~isempty(input_json.size_hectares)
    size_hectares = input_json.size_hectares;
else
    size_hectares = [];
end

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

% Farmer-supplied at onboarding (one of the 6 values TenseurSol.m switches
% on); absent/empty means "je ne sais pas" — dailyIrrigationRecommendation
% then falls back to classifySoilType (ISRIC) exactly as before this was
% added.
if isfield(input_json, 'type_sol') && ~isempty(input_json.type_sol)
    typeSol = input_json.type_sol;
else
    typeSol = [];
end

[should_irrigate, duration_s, volume, soil_moisture, severe_stress, psi_new, theta_infiltre_new] = ...
    dailyIrrigationRecommendation(culture, lat, lon, JourJulien, psi_old, theta_infiltre, 1, typeSol);

% `volume` (from TempsEtVolumeEauNecessaireIrrigation, via
% parametresSource's `A = d_r*dl`) is the water volume for ONE emitter/plant,
% in m^3 — q_irr (parameterGoutteur.m) is documented as a single dripper's
% flow rate in m^3/s, so everything derived from it is per-plant, not per
% field. Scaled here, not in the AQUACROP-FAO formula files themselves,
% since those are shared by main.m's own (per-plant-oriented) use and we
% don't want to change their contract. `duration_s` is NOT rescaled: every
% emitter in a drip system runs for the same duration simultaneously, so a
% single plant's irrigation time already is the field's irrigation time.
volume_m3_per_plant = double(volume);
if isempty(size_hectares)
    volume_liters = volume_m3_per_plant * 1000;
else
    [d_r, dl] = EspacementCulture(culture);
    area_per_plant_m2 = d_r * dl;
    num_plants = (size_hectares * 10000) / area_per_plant_m2;
    volume_liters = volume_m3_per_plant * 1000 * num_plants;
end

result = struct();
result.should_irrigate = logical(should_irrigate);
result.duration_s = double(duration_s);
result.volume = double(volume_liters);
result.soil_moisture = double(soil_moisture);
result.severe_stress = logical(severe_stress);
result.psi_old = psi_new(:)';
result.theta_infiltre = double(theta_infiltre_new);
result.jour_julien = JourJulien + 1;

fid = fopen(output_path, 'w');
fprintf(fid, '%s', jsonencode(result));
fclose(fid);
