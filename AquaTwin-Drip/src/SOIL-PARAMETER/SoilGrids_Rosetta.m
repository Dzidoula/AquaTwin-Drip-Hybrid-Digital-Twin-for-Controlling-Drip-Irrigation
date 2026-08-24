function [theta_r,theta_s,alpha,n,Ks,Sand,Silt,Clay,BD] =SoilGrids_Rosetta(lat,lon)

% CACHE LOCAL (I/O only, pas un changement scientifique) : classifySoilType.m
% et vanMualemParametersValor.m appellent chacune cette fonction avec le meme
% (lat,lon) — deux requetes ISRIC identiques et redondantes dans un seul
% calcul — et le moteur est un process Octave neuf a chaque appel API, donc
% sans ca on recontacte ISRIC tous les jours pour un sol qui ne change pas.
% Cle arrondie a 3 decimales (~111m, plus grossier que la resolution de
% SoilGrids ~250m) pour absorber le bruit flottant. `round(x,n)` a 2
% arguments n'est pas supporte par cette version d'Octave (meme limitation
% que dans classifySoilType.m) — d'ou round(x*1000)/1000.
cache_path = fullfile(fileparts(mfilename('fullpath')), '.soilgrids_cache.json');
lat_key = round(lat*1000)/1000;
lon_key = round(lon*1000)/1000;

if exist(cache_path, 'file')
    try
        cache_data = jsondecode(fileread(cache_path));
        for i = 1:numel(cache_data)
            entry = cache_data(i);
            if abs(entry.lat - lat_key) < 1e-6 && abs(entry.lon - lon_key) < 1e-6
                theta_r = entry.theta_r; theta_s = entry.theta_s; alpha = entry.alpha;
                n = entry.n; Ks = entry.Ks; Sand = entry.Sand; Silt = entry.Silt;
                Clay = entry.Clay; BD = entry.BD;
                fprintf('SoilGrids/Rosetta : cache local pour (%.4f, %.4f), pas de requete ISRIC.\n', lat, lon);
                return;
            end
        end
    catch
        % Cache illisible/corrompu : on l'ignore et on retombe sur le reseau.
    end
end

% 1. SoilGrids API

fprintf('Recherche pour lat=%.4f, lon=%.4f\n', lat, lon);

url = sprintf([ ...
'https://rest.isric.org/soilgrids/v2.0/properties/query' ...
'?lon=%f&lat=%f' ...
'&property=sand' ...
'&property=silt' ...
'&property=clay' ...
'&property=bdod' ...
'&depth=0-5cm' ...
'&value=mean'], lon, lat);

% `webread`/`weboptions` are broken in this GNU Octave build (fails even on
% a plain, known-good JSON endpoint like api.github.com — not specific to
% this URL). Replaced with a curl + jsondecode equivalent, which round-trips
% to an identical struct. See branch README/PR description for details.
[curl_status, curl_output] = system(['curl -s --max-time 240 "' url '"']);
if curl_status ~= 0
    error('Echec de la requete SoilGrids (curl status=%d) pour (%.4f, %.4f)', curl_status, lat, lon);
end
data = jsondecode(curl_output);

% Extraction robuste
Sand = NaN; Silt = NaN; Clay = NaN; BD = NaN;

if isfield(data, 'properties') && isfield(data.properties, 'layers')
    layers = data.properties.layers;
    
    for k = 1:length(layers)
        name = lower(layers(k).name);
        
        if isfield(layers(k), 'depths') && isstruct(layers(k).depths)
            if isfield(layers(k).depths, 'values') && isfield(layers(k).depths.values, 'mean')
                value = layers(k).depths.values.mean;
                
                if ~isempty(value) && isnumeric(value) && ~isnan(double(value))
                    switch name
                        case 'sand'
                            Sand = double(value) / 10;
                        case 'silt'
                            Silt = double(value) / 10;
                        case 'clay'
                            Clay = double(value) / 10;
                        case 'bdod'
                            BD = double(value) / 100;
                    end
                end
            end
        end
    end
end

if any(isnan([Sand, Silt, Clay, BD]))
    error('Aucune donn?e pour (%.4f, %.4f) - point probablement oc?anique', lat, lon);
end

fprintf('Sable: %.1f%%, Limon: %.1f%%, Argile: %.1f%%, BD: %.3f g/cm3\n', ...
    Sand, Silt, Clay, BD);

% Normalisation
total = Sand + Silt + Clay;
if abs(total - 100) > 0.1
    Sand = Sand * 100 / total;
    Silt = Silt * 100 / total;
    Clay = Clay * 100 / total;
    fprintf('   Normalis?: %.1f%% + %.1f%% + %.1f%% = %.1f%%\n', Sand, Silt, Clay, Sand+Silt+Clay);
end


% 2. Appel Python Rosetta

% NOTE (portage Octave/Linux) : le chemin d'origine etait code en dur vers
% le PC Windows de l'auteur (C:\Users\DELL\Desktop\...), donc inexistant sur
% toute autre machine. Remplace par un chemin relatif a ce fichier .m, qui
% fonctionne quel que soit l'endroit ou le depot est clone.
%
% RESERVE SCIENTIFIQUE : rosetta_cli.py (ajoute par l'auteur le 2026-08-18)
% contient des "equations Rosetta approximatives - a remplacer par les
% vraies" (commentaire de l'auteur dans ce fichier) — ce n'est PAS le vrai
% modele Rosetta (reseau de neurones entraine), juste un calcul provisoire.
% Les resultats de cette fonction ne sont donc pas encore scientifiquement
% valides ; a mettre a jour des que la vraie estimation Rosetta est fournie.
scriptDir = fileparts(mfilename('fullpath'));
pythonFile = fullfile(scriptDir, 'rosetta_cli.py');

if ~exist(pythonFile, 'file')
    error('Fichier Python non trouv?: %s', pythonFile);
end

% Formater avec POINT decimal
fmt = @(x) strrep(sprintf('%.6f', x), ',', '.');
cmd = sprintf('python3 "%s" %s %s %s %s', ...
    pythonFile, fmt(Sand), fmt(Silt), fmt(Clay), fmt(BD));

[status, result] = system(cmd);

if status ~= 0
    warning('Erreur Python, utilisation valeurs par d?faut');
    theta_r = 0.05; theta_s = 0.45; alpha = 0.014; n = 1.5; Ks = 10;
    return;
end

% CRUCIAL: Extraire la DERNI?RE ligne qui contient 5 nombres
lines = strsplit(strtrim(result), '\n');
X = [];

for i = length(lines):-1:1  % Parcour de la fin vers le debut
    X = sscanf(lines{i}, '%f');
    if length(X) == 5
        break;  % Trouve ?
    end
end

if length(X) ~= 5
    warning('Sortie Python inattendue, utilisation valeurs par defaut');
    fprintf('Sortie brute: %s\n', result);
    theta_r = 0.05; theta_s = 0.45; alpha = 0.014; n = 1.5; Ks = 10;
    return;
end

% 3. Resultats

theta_r = X(1);
theta_s = X(2);
alpha   = X(3);
n       = X(4);
Ks      = X(5);

% Ecriture du cache — best-effort : un souci d'ecriture ne doit jamais faire
% echouer le calcul en cours, seulement priver les prochains appels du
% raccourci.
try
    new_entry = struct('lat', lat_key, 'lon', lon_key, 'theta_r', theta_r, ...
        'theta_s', theta_s, 'alpha', alpha, 'n', n, 'Ks', Ks, ...
        'Sand', Sand, 'Silt', Silt, 'Clay', Clay, 'BD', BD);
    if exist(cache_path, 'file')
        existing = jsondecode(fileread(cache_path));
        cache_data = [existing(:); new_entry];
    else
        cache_data = new_entry;
    end
    fid = fopen(cache_path, 'w');
    fprintf(fid, '%s', jsonencode(cache_data));
    fclose(fid);
catch
    % Ignoré délibérément — voir commentaire ci-dessus.
end

end