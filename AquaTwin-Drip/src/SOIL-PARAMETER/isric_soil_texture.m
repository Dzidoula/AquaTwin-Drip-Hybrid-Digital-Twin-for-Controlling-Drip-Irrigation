function [Sand, Silt, Clay, BD] = isric_soil_texture(lat, lon)
% Recupere Sand/Silt/Clay/BD (0-5cm) via ISRIC SoilGrids v2.0 — la source
% d'origine de ce depot, restauree ici comme repli quand iSDA Africa
% (isda_soil_texture.m, la source principale depuis le 2026-08-26) n'a
% aucune donnee pour un point donne. Le constat du 2026-08-26 ("ISRIC
% renvoie systematiquement null pour toute coordonnee africaine testee")
% ne s'est pas confirme pour toutes les coordonnees : voir la memoire de
% session "isric_reliability" (corrigee le 2026-08-27) — le null d'ISRIC
% est un trou ponctuel par coordonnee, pas une panne totale sur l'Afrique.
% iSDA lui-meme a ses propres trous (ex. zones saheliennes hors de son
% jeu de donnees agricole) — les deux sources se completent.
%
% Contrat identique a isda_soil_texture.m : NaN (pas d'erreur) quand
% ISRIC n'a rien pour ce point, pour que l'appelant (SoilGrids_Rosetta.m)
% puisse essayer l'autre source avant d'abandonner.

Sand = NaN; Silt = NaN; Clay = NaN; BD = NaN;

url = sprintf([ ...
'https://rest.isric.org/soilgrids/v2.0/properties/query' ...
'?lon=%f&lat=%f' ...
'&property=sand' ...
'&property=silt' ...
'&property=clay' ...
'&property=bdod' ...
'&depth=0-5cm' ...
'&value=mean'], lon, lat);

% `webread`/`weboptions` sont casses sur cette version d'Octave (voir
% SoilGrids_Rosetta.m pour le meme constat) — curl + jsondecode a la place.
% max-time genereux (90s, pas les 30s habituels) : mesure en conditions
% reelles depuis le serveur de prod, rest.isric.org peut prendre >50s a
% repondre (contre <1s pour iSDA) — lent mais fiable, pas casse. Ce repli
% n'est appele qu'en dernier recours (iSDA a deja echoue), donc le cout
% en est acceptable dans le budget de 30 min du job.
[curl_status, curl_output] = system(['curl -s --max-time 90 "' url '"']);
if curl_status ~= 0
    return; % reseau indisponible : NaN, comme "pas de donnee"
end

try
    data = jsondecode(curl_output);
catch
    return; % reponse illisible : idem
end

if ~isfield(data, 'properties') || ~isfield(data.properties, 'layers')
    return;
end

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
