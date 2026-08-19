function soil_type = classifySoilType(lat,lon)
    
    [theta_r,theta_s,alpha,n,Ks,sand,silt,clay,BD]=SoilGrids_Rosetta(lat,lon)
    
    % Arrondir pour eviter les problemes de precision
    % `round(x, n)` (arrondi a n decimales) n'est pas supporte par cette
    % version d'Octave, seule la forme a 1 argument l'est — meme famille
    % d'incompatibilite que webread/weboptions (voir SoilGrids_Rosetta.m).
    sand = round(sand * 10) / 10;
    silt = round(silt * 10) / 10;
    clay = round(clay * 10) / 10;
    
    % Verifier que les pourcentages sont valides
    total = sand + silt + clay;
    if abs(total - 100) > 1e-6
        warning('Les pourcentages ne totalisent pas 100% : Erreur, normalisation si necessaire');
        
        % Normalisation si necessaire
        sand = 100 * sand / total;
        silt = 100 * silt / total;
        clay = 100 * clay / total;
    end
    
    % Classification USDA 
    
    % 1. Sableux (Sand)
    if sand >= 85 && (silt + 1.5*clay) <= 15
        soil_type = 'Sableux';%(Sand)
    
    % 2. Sable limoneux (Loamy Sand)
    elseif sand >= 70 && sand < 85 && (silt + 2*clay) <= 30
        soil_type = 'Sable limoneux';%(Loamy Sand)
    
    % 3. Limon sableux (Sandy Loam)
    elseif sand >= 50 && sand < 70 && clay >= 0 && clay <= 20 && silt <= 50
        soil_type = 'Limon sableux';%(Sandy Loam)
    
    % 4. Limon (Loam)
    elseif sand >= 23 && sand < 50 && clay >= 7 && clay <= 27 && silt >= 28 && silt < 50
        soil_type = 'Limon ';%(Loam)
    
    % 5. Limon limoneux (Silt Loam)
    elseif sand < 23 && silt >= 50 && clay >= 12 && clay <= 27
        soil_type = 'Limon limoneux ';%(Silt Loam)
    
    % 6. Limon (Silt)
    elseif sand < 23 && silt >= 80 && clay < 12
        soil_type = 'Limon'; %(Silt)
    
    % 7. Limon argileux sableux (Sandy Clay Loam)
    elseif sand >= 45 && sand < 60 && clay >= 20 && clay < 35
        soil_type = 'Limon argileux sableux';%(Sandy Clay Loam)
    
    % 8. Limon argileux (Clay Loam)
    elseif sand >= 20 && sand < 45 && clay >= 27 && clay < 40
        soil_type = 'limoneux-argileux';%(Clay Loam)
    
    % 9. Limon argileux limoneux (Silty Clay Loam)
    elseif sand < 20 && clay >= 27 && clay < 40 && silt >= 40
        soil_type = 'Limon argileux limoneux';%(Silty Clay Loam)
    
    % 10. Argile sableuse (Sandy Clay)
    elseif sand >= 45 && clay >= 35
        soil_type = 'Argile sableuse';%(Sandy Clay)
    
    % 11. Argile limoneuse (Silty Clay)
    elseif sand < 45 && clay >= 40 && silt >= 40
        soil_type = 'limoneux-argileux'; %(Silty Clay)
    
    % 12. Argile (Clay)
    elseif clay >= 40
        soil_type = 'argileux';%(Clay)
    
    % cas par defaut (si aucun crit?re n'est rempli)
    else
        soil_type = 'Non classifi? (V?rifier les valeurs)';
    end
end