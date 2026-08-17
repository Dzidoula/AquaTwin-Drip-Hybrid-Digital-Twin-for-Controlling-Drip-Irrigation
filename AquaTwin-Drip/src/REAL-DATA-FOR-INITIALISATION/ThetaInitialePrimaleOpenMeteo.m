function thetaPrimale=ThetaInitialePrimaleOpenMeteo(zmax,h,lat,lon)

% MAILLAGE


vn=0:h:1;
n = round(length(vn)+(1/h^(2)));
z = zmax*(linspace(0,1,n))';
thetaPrimale = zeros(n,1);

% OPEN-METEO


url = sprintf([ ...
'https://api.open-meteo.com/v1/forecast?',...
'latitude=%f&longitude=%f&',...
'hourly=',...
'soil_moisture_0_to_1cm,',...
'soil_moisture_1_to_3cm,',...
'soil_moisture_3_to_9cm,',...
'soil_moisture_9_to_27cm,',...
'soil_moisture_27_to_81cm'],...
lat,lon);

% `webread`/`weboptions` are broken in this GNU Octave build — see
% SoilGrids_Rosetta.m for the same fix and details.
[curl_status, curl_output] = system(['curl -s --max-time 20 "' url '"']);
if curl_status ~= 0
    error('curl failed with status %d', curl_status);
end
json = jsondecode(curl_output);

SH0 =json.hourly.soil_moisture_0_to_1cm(1);

SH1 =json.hourly.soil_moisture_1_to_3cm(1);

SH2 =json.hourly.soil_moisture_3_to_9cm(1);

SH3 =json.hourly.soil_moisture_9_to_27cm(1);

SH4 =json.hourly.soil_moisture_27_to_81cm(1);

% AFFECTATION PAR COUCHE


for i=1:n

    profondeur = z(i)*100; % m -> cm

    if profondeur <= 1

        thetaPrimale(i)=SH0;

    elseif profondeur <= 3

        thetaPrimale(i)=SH1;

    elseif profondeur <= 9

        thetaPrimale(i)=SH2;

    elseif profondeur <= 27

        thetaPrimale(i)=SH3;

    elseif profondeur <= 81

        thetaPrimale(i)=SH4;

    else

        thetaPrimale(i)=SH4; % prolongement profondeur

    end

end

end