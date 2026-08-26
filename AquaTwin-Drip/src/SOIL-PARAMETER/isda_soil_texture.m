function [Sand, Silt, Clay, BD] = isda_soil_texture(lat, lon)
% Recupere Sand/Silt/Clay/BD (couche 0-20cm) via l'API iSDA Africa.
%
% RAISON DE CE FICHIER : SoilGrids_Rosetta.m appelait ISRIC pour ces 4
% valeurs, mais ISRIC renvoie systematiquement "mean": null pour TOUTE
% coordonnee africaine testee (Benin, Nigeria, Ghana, RDC, Kenya, Egypte),
% ainsi que pour l'Espagne et l'Inde — teste le 2026-08-26, de facon
% reproductible et non intermittente (retester la meme coordonnee ne
% change rien). iSDA Africa (https://api.isda-africa.com), un service de
% donnees de sol construit specifiquement pour l'Afrique (30m de
% resolution), a ete teste sur les memes coordonnees beninoises (nord et
% sud) et repond de facon fiable avec de vraies valeurs. Voir la memoire
% de session "isric_reliability" / "engine_bugs_for_alex" (bug #17) pour
% le detail des tests et le lien avec vanMualemParametersValor.m, qui
% appelle cette chaine sans condition meme quand l'agriculteur a
% renseigne son type de sol a l'inscription.
%
% A DISCUTER AVEC ALEX : iSDA (30m, methodologie propre) n'est pas la
% meme source que SoilGrids (250m, methodologie ISRIC) — les valeurs
% numeriques peuvent legerement differer d'un point. C'est un changement
% de source de donnees, pas seulement un correctif de robustesse ; a
% valider avec lui avant de le considerer definitif, meme si le calcul
% en aval (Rosetta, dans SoilGrids_Rosetta.m) ne change pas.
%
% Necessite les variables d'environnement ISDA_USERNAME / ISDA_PASSWORD
% (jamais commitees dans ce depot — meme convention que DATABASE_URL,
% voir deploy/).

token = isda_token();

props = {'sand_content', 'clay_content', 'silt_content', 'bulk_density'};
values = struct('sand_content', NaN, 'clay_content', NaN, ...
                 'silt_content', NaN, 'bulk_density', NaN);

% iSDA ne renvoie qu'UNE SEULE propriete meme si plusieurs "property=" sont
% passes dans la meme requete (teste manuellement le 2026-08-26) —
% contrairement a l'API ISRIC. D'ou 4 requetes separees plutot qu'une
% requete groupee.
for i = 1:numel(props)
    prop = props{i};
    url = sprintf(['https://api.isda-africa.com/isdasoil/v2/soilproperty' ...
        '?lat=%f&lon=%f&property=%s&depth=0-20'], lat, lon, prop);
    cmd = sprintf('curl -s --max-time 30 -H "Authorization: Bearer %s" "%s"', token, url);
    [status, output] = system(cmd);
    if status ~= 0
        error('Echec de la requete iSDA Africa (curl status=%d) pour %s a (%.4f, %.4f)', ...
            status, prop, lat, lon);
    end
    data = jsondecode(output);
    if isfield(data, 'property') && isfield(data.property, prop)
        entries = data.property.(prop);
        if ~isempty(entries) && isfield(entries(1), 'value') && isfield(entries(1).value, 'value')
            values.(prop) = double(entries(1).value.value);
        end
    end
end

Sand = values.sand_content;
Silt = values.silt_content;
Clay = values.clay_content;
BD   = values.bulk_density;

end

% --- Fonction locale : authentification iSDA, avec cache/renouvellement ---
function token = isda_token()
cache_path = fullfile(fileparts(mfilename('fullpath')), '.isda_token_cache.json');

% Les tokens iSDA sont valides 1h (verifie sur un token reel obtenu le
% 2026-08-26 : exp - iat = 3600s) ; marge de securite de 5 min avant de
% redemander un nouveau token plutot que de decoder le JWT pour lire sa
% propre date d'expiration exacte.
ttl_s = 3600 - 300;

if exist(cache_path, 'file')
    try
        cached = jsondecode(fileread(cache_path));
        if (time() - cached.issued_at) < ttl_s
            token = cached.access_token;
            return;
        end
    catch
        % Cache illisible/corrompu : on l'ignore et on redemande un token.
    end
end

username = getenv('ISDA_USERNAME');
password = getenv('ISDA_PASSWORD');
if isempty(username) || isempty(password)
    error(['ISDA_USERNAME/ISDA_PASSWORD non definies (variables d''environnement) - ' ...
        'impossible de s''authentifier auprès d''iSDA Africa.']);
end

body = sprintf('grant_type=password&username=%s&password=%s&scope=&client_id=string&client_secret=string', ...
    isda_url_encode(username), isda_url_encode(password));
cmd = sprintf(['curl -s --max-time 30 -X POST "https://api.isda-africa.com/login" ' ...
    '-H "accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" ' ...
    '-d "%s"'], body);
[status, output] = system(cmd);
if status ~= 0
    error('Echec de connexion a iSDA Africa (curl status=%d)', status);
end
data = jsondecode(output);
if ~isfield(data, 'access_token')
    error('Reponse iSDA Africa inattendue lors du login: %s', output);
end
token = data.access_token;

try
    entry = struct('access_token', token, 'issued_at', time());
    fid = fopen(cache_path, 'w');
    fprintf(fid, '%s', jsonencode(entry));
    fclose(fid);
catch
    % Ecriture du cache best-effort — meme convention que le cache
    % SoilGrids_Rosetta.m : un souci d'ecriture ne doit jamais faire
    % echouer le calcul en cours.
end
end

% --- Fonction locale : percent-encoding minimal pour un corps
% application/x-www-form-urlencoded (identifiants pouvant contenir @, ., etc.) ---
function encoded = isda_url_encode(s)
encoded = '';
for i = 1:length(s)
    c = s(i);
    if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || ...
            any(c == '-_.~')
        encoded = [encoded c];
    else
        encoded = [encoded sprintf('%%%02X', double(c))];
    end
end
end
