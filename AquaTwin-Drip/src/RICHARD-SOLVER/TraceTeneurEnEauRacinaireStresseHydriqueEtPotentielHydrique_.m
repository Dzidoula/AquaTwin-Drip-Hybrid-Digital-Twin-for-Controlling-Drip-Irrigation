function [SH, Pt, t, Theta_root] = TraceTeneurEnEauRacinaireStresseHydriqueEtPotentielHydrique_(lat, lon, culture, typeSol, Tmax, Psi_solution, tr, J, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s)
% NOTE (fork) : main.m appelle cette fonction en demandant 4 valeurs de
% retour ([SH, Pt, t_t, Theta_root]), mais elle n'en definissait que 2 —
% alors que t et Theta_root sont deja calcules en interne (lignes
% ci-dessous). Ce chemin de main.m n'avait donc jamais pu s'executer
% jusqu'au bout. Expose simplement ce qui existait deja, sans changer le
% calcul.

    [Hcc, RU, p_s, theta_actuel] = Solfeatures(J, culture, typeSol, lat, lon, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s);
    [X_all, Y_all, Xp, Yp, n_prim, n_dual, total_dof] = MeshGrid();
    [max_iter, tol, t] = valorsForSimulation(max(Tmax));
    [h, r, zmax] = coordonnesPlot();
    
    % Parametres de van Genuchten-Mualem
    [Capacite_hydrique, theta_func, kr_func, K_func] = VanMualemParameter(theta_s, theta_r, alpha_vg, n_vg, m_vg, k_s);
    [dr, dz, ri, zi, zr, R] = coordonneesRacinaire(r,zmax,total_dof,J,culture);
    
    % Calcul de la teneur en eau initiale
    Theta = theta_func(Psi_solution);
    Theta_root = zeros(length(zi), 1);
    t = t + tr;

    % Calcul de la teneur en eau moyenne racinaire
    %
    % BUG CORRIGE (verifie numeriquement sur un vrai calcul, voir NOTES-POUR-
    % ALEX.md) : `theta_mean` inclut un facteur `dz` (ligne du dessous),
    % mais l'ancienne normalisation `2/(R^2*max(zr))` ne le compense pas —
    % dz ne s'annule jamais. De plus `zr` (profondeur racinaire) n'a pas sa
    % place ici : cette boucle calcule une moyenne radiale a UNE profondeur
    % z fixee (theta_func(:,j) pour cette ligne i seulement, jamais cumulee
    % sur z), pas une moyenne sur toute la zone racinaire.
    % theta_func(psi) est bornee mathematiquement dans [theta_r, theta_s]
    % (van Genuchten), donc toute vraie moyenne ponderee de valeurs de ce
    % champ doit aussi y rester — l'ancienne formule sortait de cette plage
    % (0.0044 mesure pour theta_r=0.0114), ce qui est mathematiquement
    % impossible pour une moyenne ponderee a poids positifs. En divisant
    % par la somme reelle des poids utilises (`weight_sum`) au lieu d'une
    % constante analytique qui ne correspond pas a ce qui est reellement
    % somme, `theta_root` redevient une vraie moyenne ponderee — garantie
    % dans [theta_r, theta_s] par construction, quels que soient le
    % maillage ou la resolution.
    for i = 1:length(zi)
        theta_mean = 0;
        weight_sum = 0;
        for j = 1:length(ri)-1
            w = ri(j) * dr * dz;
            theta_mean = theta_mean + Theta(i, j) * w;
            weight_sum = weight_sum + w;
        end
        theta_root = theta_mean / weight_sum;
        Theta_root(i) = theta_root;
    end

    % Creation de la figure
    figure;
    
    % 1. Teneur en eau
    subplot(3, 1, 1);
    plot(t, Theta_root, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('\theta_{root} (m^3/m^3)');
    title('Teneur en eau moyenne racinaire apres irrigation');
    grid on;

    % 2. Calcul du stress hydrique
    SH = (Hcc - Theta_root) / RU;
    
    % Stress hydrique
    subplot(3, 1, 2);
    plot(t, SH, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('Stress hydrique Ks');
    title('Stress hydrique apres irrigation');
   
    % 3. Potentiel hydrique du sol
    % Verifions que Theta_root est un vecteur colonne

    if size(Theta_root, 1) == 1
        Theta_root = Theta_root';
    end
    
    
    % Potentiel hydrique
    phi_s=modeleRawlsSaxton(lat,lon,theta_r, theta_s, alpha_vg, n_vg, k_s);
    Pt=phi_s(Theta_root);
    
    subplot(3, 1, 3);
    plot(t, Pt, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('Potentiel hydrique \psi (Pa)');
    title('Potentiel hydrique apres irrigation');
    grid on;
    

end