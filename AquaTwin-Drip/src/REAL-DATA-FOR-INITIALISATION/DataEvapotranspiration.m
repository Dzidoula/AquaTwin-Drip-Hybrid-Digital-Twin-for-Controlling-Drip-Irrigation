function [T,RH,u2,Rs,P]=DataEvapotranspiration(lat,lon)
% `P` (precipitation horaire, mm) — 5e sortie optionnelle ajoutee pour
% l'affichage "Pluie 48h" cote appli ; ne change rien pour les appelants
% existants qui ne recuperent que [T,RH,u2,Rs] (Octave n'exige pas que
% l'appelant capture toutes les sorties definies par la fonction).

    try

        url = sprintf(['https://api.open-meteo.com/v1/forecast?',...
        'latitude=%f&longitude=%f&',...
        '&hourly=',...
        'temperature_2m,',...
        'relative_humidity_2m,',...
        'wind_speed_10m,',...
        'shortwave_radiation,',...
        'precipitation'],...
        lat,...
        lon);

        % `webread`/`weboptions` are broken in this GNU Octave build — see
        % SoilGrids_Rosetta.m for the same fix and details.
        [curl_status, curl_output] = system(['curl -s --max-time 30 "' url '"']);
        if curl_status ~= 0
            error('curl failed with status %d', curl_status);
        end
        json = jsondecode(curl_output);

        % VARIABLES HORAIRES
        
        T =json.hourly.temperature_2m;
        RH =json.hourly.relative_humidity_2m;
        u10 =json.hourly.wind_speed_10m;
        Rs =json.hourly.shortwave_radiation;
        P =json.hourly.precipitation;

        % Conversion vent 10m -> 2m
        u2 =u10*4.87./log(67.8*10-5.42);

    catch
        warning('Open-Meteo unavailable, using default initial pressure head');
        T=-28;
        RH=-70;
        u2=-2;
        Rs=-18;
        P=[]; % pas de sentinelle numerique ici : P n'entre dans aucun branchement T<0/T>=0, un tableau vide suffit a signaler "pas de donnee" a l'appelant.
    end

end