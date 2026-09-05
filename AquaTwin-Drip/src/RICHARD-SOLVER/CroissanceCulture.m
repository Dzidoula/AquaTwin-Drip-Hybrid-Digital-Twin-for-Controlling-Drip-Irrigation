function [hauteur, nbFeuilles,profondeurRacine, fruits,largeurFeuille]=CroissanceCulture(Jour,JourSemis,JourRecolte,culture)

% AGE

age=Jour-JourSemis;
duree=max(1,JourRecolte-JourSemis);
x=age/duree;

% COURBE LOGISTIQUE

k=10;
x0=0.5;
g=1./(1+exp(-k*(x-x0)));

% MAIS

if strcmpi(culture,'mais')

    hauteur=0.05+2.4*g;
    nbFeuilles=2+round(16*g);
    profondeurRacine=0.10+1.5*g;
    largeurFeuille=0.02+0.08*g;

    if x<0.70

        fruits=0;

    elseif x<0.90

        fruits=1;

    else

        fruits=2;

    end

% TOMATE

elseif strcmpi(culture,'tomate')

    hauteur=0.08+1.3*g;
    nbFeuilles=4+round(30*g);
    profondeurRacine=0.05+0.8*g;
    largeurFeuille=0.03+0.05*g;
    fruits=max(0,round(25*(x-0.5)));

% COTON


else

    hauteur=0.10+1.6*g;
    nbFeuilles=4+round(20*g);
    profondeurRacine=0.10+1.2*g;
    largeurFeuille=0.03+0.06*g;
    fruits=max(0,round(15*(x-0.6)));

end

end
