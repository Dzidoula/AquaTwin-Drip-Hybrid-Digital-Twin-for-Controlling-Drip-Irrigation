function trace = export_trace2dfin_frames(solution, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s, t, grid_res)
% Portage headless de Trace2DFin.m — grille de 12 images (les 12 DERNIERS
% pas de temps de la simulation, comme l'original : `l=11:-1:0` indexant
% `psi_solution(length(t)-l,:)`) montrant la FIN de l'irrigation pas de
% temps par pas de temps. Meme adaptation Octave/JSON qu'
% export_animation_frames.m/export_trace2d_frames.m : griddata au lieu de
% scatteredInterpolant, pas de figure/GIF/PNG.
%
% Contrairement a Trace2D.m (voir export_trace2d_frames.m), Trace2DFin.m
% n'ajoute PAS l'etat initial a chaque pas — `psi_k` est utilise directement,
% ce qui est correct puisque `solution` contient deja des valeurs absolues.
% Rien a signaler ici.
%
% Sorties : meme forme que export_trace2d_frames.m.

if nargin < 9 || isempty(grid_res)
    grid_res = 32;
end

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof] = MeshGrid();
[r_emitter, q_irr, Efficience] = parameterGoutteur();
[Capacite_hydrique, theta_func, kr_func, K_func] = VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);

r_max = max(X_all);
z_max = max(Y_all);
[Xplot, Yplot] = meshgrid(linspace(0, r_max, grid_res), linspace(0, z_max, grid_res));

n_total = length(t);
n_plot = min(12, n_total);

frames = cell(1, n_plot);
times = zeros(1, n_plot);

for idx = 1:n_plot
    l = n_plot - idx; % 11:-1:0 quand n_plot=12, comme l'original
    nt = n_total - l;

    psi_k = solution(nt,:)';
    psi_prim = psi_k(1:n_prim);
    psi_dual = psi_k(n_prim+1:end);
    theta_prim = theta_func(psi_prim);
    theta_dual = theta_func(psi_dual);
    Theta_all = [theta_prim; theta_dual];

    Theta_interp = griddata(X_all, Y_all, Theta_all, Xplot, Yplot, 'linear');
    Theta_interp(isnan(Theta_interp)) = theta_r;

    frames{idx} = Theta_interp;
    times(idx) = t(nt);
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
