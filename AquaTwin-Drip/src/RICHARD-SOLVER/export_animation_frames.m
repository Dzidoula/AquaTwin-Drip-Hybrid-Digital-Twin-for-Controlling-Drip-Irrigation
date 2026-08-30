function animation = export_animation_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, n_frames_out, grid_res)
% Exporte des images pretes a etre affichees (grille reguliere de teneur en
% eau interpolee) pour l'animation du bulbe d'humectation cote appli.
%
% Meme donnee que Animation2DIrrigation.m (celle qui produit les GIFs deja
% dans le depot, AquaTwin-Drip/tests/.../Animation_Irrigation_*.gif) : meme
% reconstruction primal/dual -> theta_func -> interpolation sur une grille
% reguliere (r,z), sans figure ni GIF — juste les tableaux de nombres, pour
% etre serialises en JSON et rejoues cote appli.
%
% Deux differences deliberees avec Animation2DIrrigation.m, pour rester
% utilisable en Octave headless et sur un reseau mobile :
%   1. scatteredInterpolant (MATLAB-only, absent d'Octave) remplace par
%      griddata (equivalent, disponible nativement en Octave).
%   2. Resolution de grille et nombre d'images reduits (grid_res, n_frames_out)
%      — Alex utilise 100x100 et jusqu'a 50 images pour un affichage MATLAB
%      interactif ; un telephone n'a besoin ni de cette resolution ni de ce
%      nombre d'images pour donner une impression fluide.
%
% Ne change RIEN a la physique : `solution` (sortie du solveur de Richards,
% DDFVRichardIrrigationAPI/DDFVRichardIrrigation) est prise telle quelle.

if nargin < 8 || isempty(n_frames_out)
    n_frames_out = 12;
end
if nargin < 9 || isempty(grid_res)
    grid_res = 32;
end

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[h,r,zmax] = coordonnesPlot();
[Capacite_hydrique, theta_func, kr_func, K_func] = VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);

r_max = max(X_all);
z_max = max(Y_all);
[Xplot, Yplot] = meshgrid(linspace(0, r_max, grid_res), linspace(0, z_max, grid_res));

n_total_frames = size(solution, 1);
n_frames_out = min(n_frames_out, n_total_frames);
indices = unique(round(linspace(1, n_total_frames, n_frames_out)));

frames = cell(1, numel(indices));
times = zeros(1, numel(indices));

for k = 1:numel(indices)
    nt = indices(k);

    % Meme reconstruction que Animation2DIrrigation.m : decoupage
    % primal/dual, theta_func applique separement puis concatene.
    psi_solution_ = solution(nt,:)';
    psi_prim = psi_solution_(1:n_prim);
    psi_dual = psi_solution_(n_prim+1:end);
    teneur_prim = theta_func(psi_prim);
    teneur_dual = theta_func(psi_dual);
    Teneur_eau = [teneur_prim; teneur_dual];

    Teneur_interp = griddata(X_all, Y_all, Teneur_eau, Xplot, Yplot, 'linear');

    % griddata renvoie NaN hors de l'enveloppe convexe des noeuds (pas de
    % mode 'nearest' comme scatteredInterpolant) — on rebouche avec la
    % teneur residuelle, la valeur la plus proche physiquement plausible
    % pour ces points hors domaine echantillonne.
    Teneur_interp(isnan(Teneur_interp)) = theta_r;

    frames{k} = Teneur_interp;
    times(k) = nt; % index de pas de temps ; le vecteur t (secondes) est deja connu de l'appelant
end

animation = struct();
animation.r_max = r_max;
animation.z_max = z_max;
animation.r_emitter = r_emitter;
animation.theta_r = theta_r;
animation.theta_s = theta_s;
animation.grid_res = grid_res;
animation.frame_time_indices = times;
animation.frames = frames;

end
