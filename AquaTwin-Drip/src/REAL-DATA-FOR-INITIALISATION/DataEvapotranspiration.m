function [T,RH,u2,Rs]=DataEvapotranspiration(lat,lon)

    try

        url = sprintf(['https://api.open-meteo.com/v1/forecast?',...
        'latitude=%f&longitude=%f&',...
        '&hourly=',...
        'temperature_2m,',...
        'relative_humidity_2m,',...
        'wind_speed_10m,',...
        'shortwave_radiation'],...
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

        % Conversion vent 10m -> 2m
        u2 =u10*4.87./log(67.8*10-5.42);
        
    catch
        warning('Open-Meteo unavailable, using default initial pressure head');
        T=-28;
        RH=-70;
        u2=-2;
        Rs=-18;
    end

end