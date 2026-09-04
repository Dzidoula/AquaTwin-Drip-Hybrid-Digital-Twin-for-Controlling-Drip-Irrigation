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

% 1. Texture du sol (Sand/Silt/Clay/BD)
%
% SOURCE PRINCIPALE : iSDA Africa, malgre le nom de ce fichier (conserve
% pour eviter de casser classifySoilType.m/vanMualemParametersValor.m qui
% l'appellent par ce nom) — voir isda_soil_texture.m pour le detail des
% tests du 2026-08-26 qui ont motive ce choix. REPLI : ISRIC SoilGrids
% (isric_soil_texture.m) quand iSDA n'a rien pour un point donne (constate
% en pratique sur des coordonnees hors de sa couverture, ex. Sahel) — les
% deux sources se completent plutot que de faire echouer tout le calcul.
% A VALIDER AVEC ALEX : changement de source de donnees (30m/iSDA vs
% 250m/SoilGrids selon la source utilisee), pas seulement un correctif de
% robustesse — le calcul Rosetta en aval, lui, ne change pas.

fprintf('Recherche pour lat=%.4f, lon=%.4f (iSDA Africa)\n', lat, lon);

[Sand, Silt, Clay, BD] = isda_soil_texture(lat, lon);

% REPLI ISRIC : iSDA Africa a ses propres trous de couverture (constate en
% pratique sur des coordonnees saheliennes, hors de son jeu de donnees
% agricole) — avant d'abandonner, on retente via ISRIC SoilGrids
% (isric_soil_texture.m), qui peut avoir une valeur la ou iSDA n'en a pas
% (couverture mondiale, methodologie differente). Si les DEUX sources
% n'ont rien, message clair pour l'utilisateur plutot qu'une trace Octave.
if any(isnan([Sand, Silt, Clay, BD]))
    fprintf('iSDA Africa : aucune donnee pour (%.4f, %.4f), tentative ISRIC SoilGrids.\n', lat, lon);
    [Sand, Silt, Clay, BD] = isric_soil_texture(lat, lon);
end

if any(isnan([Sand, Silt, Clay, BD]))
    error(['Aucune donnee de sol disponible pour ces coordonnees (%.4f, %.4f) ' ...
        '— ni iSDA Africa, ni ISRIC SoilGrids. Verifiez la position choisie.'], lat, lon);
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