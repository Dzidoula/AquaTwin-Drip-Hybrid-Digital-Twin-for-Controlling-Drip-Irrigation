function trace = export_trace2d_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, t, grid_res)
% Portage headless de Trace2D.m — grille de 12 images (fixe, comme
% l'original : `min(12, size(psi_solution,1))`) montrant le DEBUT de
% l'irrigation pas de temps par pas de temps, plutot qu'un sous-echantillon
% etale sur toute la duree comme export_animation_frames.m. Meme
% adaptation Octave/JSON que ce fichier : griddata au lieu de
% scatteredInterpolant, pas de figure/GIF/PNG.
%
% BUG REPRODUIT TEL QUEL (a confirmer avec Alexandre) : Trace2D.m calcule
% `psi_total = psi_k + psi0` pour CHAQUE image, y compris pour k>=2 —
% or `psi_solution` (la sortie de DDFVRichardIrrigationAPI/
% DDFVRichardIrrigation) contient deja des valeurs ABSOLUES de psi a
% chaque pas de temps, pas des increments par rapport a l'etat initial.
% Ajouter psi0 une seconde fois a un psi deja absolu double artificiellement
% la contribution de l'etat initial dans theta_func(psi_total) pour
% k>=2 — la teneur en eau affichee sur ces images n'est donc pas la teneur
% en eau reelle a cet instant. On reproduit ce calcul exactement (pas une
% simple lecture de theta(psi_k) sans l'ajout), fidele a ce que Trace2D.m
% affiche reellement, et on le signale ici plutot que de le corriger
% silencieusement.
%
% Sorties (meme forme que export_animation_frames.m, pour reutiliser le
% meme rendu cote appli) : r_max, z_max, r_emitter, theta_r, theta_s,
% grid_res, frame_times_s (t(k), 0 pour la 1ere image = etat initial),
% frames (theta interpole sur une grille reguliere r/z).

if nargin < 9 || isempty(grid_res)
    grid_res = 32;
end

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[Capacite_hydrique, theta_func, kr_func, K_func] = VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);

r_max = max(X_all);
z_max = max(Y_all);
[Xplot, Yplot] = meshgrid(linspace(0, r_max, grid_res), linspace(0, z_max, grid_res));

n_plot = min(12, size(solution, 1));
psi0 = solution(1,:)';

frames = cell(1, n_plot);
times = zeros(1, n_plot);

for k = 1:n_plot
    psi_k = solution(k,:)';

    % Reproduction exacte de Trace2D.m — voir la note ci-dessus.
    psi_total = psi_k + psi0;

    psi_prim = psi_total(1:n_prim);
    psi_dual = psi_total(n_prim+1:end);
    theta_prim = theta_func(psi_prim);
    theta_dual = theta_func(psi_dual);
    Theta_all = [theta_prim; theta_dual];

    Theta_interp = griddata(X_all, Y_all, Theta_all, Xplot, Yplot, 'linear');
    Theta_interp(isnan(Theta_interp)) = theta_r;

    frames{k} = Theta_interp;
    times(k) = t(k);
end

trace = struct();
trace.r_max = r_max;
trace.z_max = z_max;
trace.r_emitter = r_emitter;
trace.theta_r = theta_r;
trace.theta_s = theta_s;
trace.grid_res = grid_res;
trace.frame_times_s = times;
trace.frames = frames;

end
