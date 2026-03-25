clc; clear; close all;

%% 初始化

% 读取参数 
config = config_params(); 

% 建立参数网格
task_list = build_task_grid(config.sweep);
num_conditions = height(task_list); 

% 数据集规模预估
if strcmp(config.static.save_precision, 'single')
    bytes_per_elem = 8; % complex single
else
    bytes_per_elem = 16; % complex double
end

elements_per_chunk = config.static.samples_per_cond * config.static.num_snapshots * ...
                     config.static.N_sc * config.static.N_rx * config.static.N_tx;
chunk_raw_MB = (elements_per_chunk * bytes_per_elem) / (1024^2);
total_raw_MB = chunk_raw_MB * num_conditions;


fprintf('数据规模: 单个块约 %.2f MB | 总计约 %.2f MB\n\n', chunk_raw_MB, total_raw_MB);
disp('任务清单:');
disp(task_list(1:height(task_list), :)); 

% 创建保存文件夹
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
dataset_dir = sprintf('CSI_Dataset_%s', time_stamp);
if ~exist(dataset_dir, 'dir'); mkdir(dataset_dir); end


%% QuaDRiGa 初始化

% Tx 初始化
a_tx = qd_arrayant.generate( ...
    config.static.tx_array_type, ...                  % 模型
    config.static.tx_M, ...                           % Ain: 垂直阵子数
    config.static.tx_N, ...                           % Bin: 水平阵子数
    config.static.center_freq_Hz, ...                 % Cin: 中心频率
    config.static.tx_pol, ...                         % Din: 极化模式
    config.static.tx_tilt, ...                        % Ein: 电下倾角 
    config.static.tx_Vspc, ...                        % Fin: 垂直阵子间距
    config.static.tx_Mg, ...                          % Gin: 垂直面板数
    config.static.tx_Ng, ...                          % Hin: 水平面板数
    config.static.tx_Vspc * config.static.tx_M, ...   % Iin: 垂直面板间距
    config.static.tx_Hspc * config.static.tx_N);      % Jin: 水平面板间距

% Rx 初始化
a_rx = qd_arrayant.generate( ...
    config.static.rx_array_type, ...                  % 模型
    config.static.rx_M, ...                           % Ain: 垂直阵子数
    config.static.rx_N, ...                           % Bin: 水平阵子数
    config.static.center_freq_Hz, ...                 % Cin: 中心频率
    config.static.rx_pol, ...                         % Din: 极化模式
    config.static.rx_tilt, ...                        % Ein: 电下倾角 
    config.static.rx_Vspc, ...                        % Fin: 垂直阵子间距
    config.static.rx_Mg, ...                          % Gin: 垂直面板数
    config.static.rx_Ng, ...                          % Hin: 水平面板数
    config.static.rx_Vspc * config.static.rx_M, ...   % Iin: 垂直面板间距
    config.static.rx_Hspc * config.static.rx_N);      % Jin: 水平面板间距

% 端口检查
assert(a_tx.no_elements == config.static.N_tx, ...
    'Tx 构建失败：实际端口数 (%d) 与 N_tx (%d) 不符', a_tx.no_elements, config.static.N_tx);
assert(a_rx.no_elements == config.static.N_rx, ...
    'Rx 构建失败：实际端口数 (%d) 与 N_rx (%d) 不符', a_rx.no_elements, config.static.N_rx);

%% 画图设置
% figure('Name', 'UE 轨迹图', 'Position', [100, 100, 700, 700]);
% plot(0, 0, '^r', 'MarkerSize', 12, 'MarkerFaceColor', 'r'); hold on; grid on; % 基站
% plot(config.static.ue_center_dist_m, 0, 'kx', 'MarkerSize', 10, 'LineWidth', 2); % 覆盖中心
% axis equal; xlabel('X (m)'); ylabel('Y (m)'); title('UE 轨迹');
% 
% % 画扇区边界参考线
% th = linspace(deg2rad(config.static.ue_drop_angle_min_deg+180), deg2rad(config.static.ue_drop_angle_max_deg+180), 50);
% plot(config.static.ue_center_dist_m + config.static.ue_drop_radius_min_m*cos(th), config.static.ue_drop_radius_min_m*sin(th), 'k--');
% plot(config.static.ue_center_dist_m + config.static.ue_drop_radius_max_m*cos(th), config.static.ue_drop_radius_max_m*sin(th), 'k--');

%% 主循环
for cond = 1 : num_conditions
    current_scen_str = task_list.scenario{cond}; 
    current_v_kmh    = task_list.velo_kmh(cond);
    current_v_ms     = current_v_kmh / 3.6;
    
    fprintf('\n>> %d/%d: [%s | %d km/h] ...\n', cond, num_conditions, current_scen_str, current_v_kmh);
            
    chunk_sz = [config.static.samples_per_cond, ... % 样本数
                config.static.num_ue, ...           % 用户数
                config.static.num_snapshots, ...    % 时间快照数
                config.static.N_sc, ...             % 子载波数
                config.static.N_tx];                % 发射天线数

    H_compute_chunk = complex(zeros(chunk_sz, config.static.compute_precision), 0);
    
    % 仿真参数实例化
    sim_params = qd_simulation_parameters;    
    sim_params.show_progress_bars = 0; % 关闭内置进度条
    sim_params.center_frequency = config.static.center_freq_Hz;
    sim_params.set_speed(current_v_kmh, config.static.t_step_s);
    sim_params.use_random_initial_phase = true; % 随机初始相位
    sim_params.use_3GPP_baseline = 1;   % 启用 3GPP 基线规范  

    % 拓扑静态配置
    bs_location = [0; 0; config.static.bs_height_m];  % 基站坐标
    ue_center   = [config.static.ue_center_dist_m; 0; config.static.ue_height_m]; % 覆盖中心
    
    % UE 轨迹: 运动总时长 = 采样间隔 * (快拍数 - 1)
    time_length = config.static.t_step_s * (config.static.num_snapshots - 1);
    ue_track_length = current_v_ms * time_length;
    
    reverseStr = '';
    for iter_s = 1 : config.static.samples_per_cond
        % 进度条
        msg = sprintf('   >>>> [%d / %d]  %.1f%%', iter_s, config.static.samples_per_cond, (iter_s/config.static.samples_per_cond)*100);
        fprintf('%s', [reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));

        % 子种子
        sub_seed = config.static.base_seed + cond * 1000000 + iter_s;
        rng(sub_seed, 'twister');
      
        % 空间随机撒点
        rho_min = config.static.ue_drop_radius_min_m;
        rho_max = config.static.ue_drop_radius_max_m;
        rho = rho_min + (rho_max - rho_min) * rand(1, config.static.num_ue);
        a_min = config.static.ue_drop_angle_min_deg; 
        a_max = config.static.ue_drop_angle_max_deg; 
        phi = a_min + (a_max - a_min) * rand(1, config.static.num_ue);                 
        
        % 生成 UE 坐标和线性轨迹
        ue_location = zeros(3, config.static.num_ue);
        for iter_ue = 1 : config.static.num_ue
            rho_i = rho(iter_ue);
            phi_i = phi(iter_ue);
            ue_location(:, iter_ue) = [-rho_i*cosd(phi_i); rho_i*sind(phi_i); 0] + ue_center;

            ue_track(iter_ue) = qd_track.generate('linear', ue_track_length);
            % 将轨迹初始位置绑定到 ue 位置
            ue_track(iter_ue).initial_position = ue_location(:, iter_ue); 
            % 轨迹线性插值
            ue_track(iter_ue).interpolate('distance', 1/sim_params.samples_per_meter, [], [], 1);            
            % 命名
            ue_track(iter_ue).name = sprintf('%d', iter_ue);
        end
        
        % ue 轨迹监控
        % hold on; 
        % for iter_ue = 1 : length(ue_track)
        %     abs_pos = ue_track(iter_ue).positions + ue_track(iter_ue).initial_position; 
        %     plot(abs_pos(1,1), abs_pos(2,1), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');
        %     plot(abs_pos(1,:), abs_pos(2,:), 'b-', 'LineWidth', 1.5);
        % end
        % drawnow;
        % hold off

        % Layout 实例化
        layout = qd_layout(sim_params); 
    
        % Tx 配置
        layout.no_tx = 1; 
        layout.tx_array = a_tx;            
        layout.tx_position = bs_location;
    
        % Rx 配置
        layout.no_rx = config.static.num_ue; 
        layout.rx_array = a_rx;
        layout.rx_track = ue_track;
        layout.rx_position = ue_location; 
        
        % 注入场景
        layout.set_scenario(current_scen_str); 

        % 信道生成
        [channel, ~] = layout.get_channels();

        clear ue_track; % 重置 ue_track

        % 提取频域响应
        for iter_ue = 1 : config.static.num_ue
            % channel.fr 默认输出维度: [Rx, Tx, Subcarriers, Snapshots]
            h = channel(iter_ue).fr(config.static.bw_Hz, config.static.N_sc);
            
            % 压缩 Rx=1 维度: [Tx, Subcarriers, Snapshots]
            h = shiftdim(h, 1);
            
            % 维度重排 [Snapshots(3), Subcarriers(2), Tx(1)]
            h = permute(h, [3, 2, 1]);
            
            % 转换精度
            h = cast(h, config.static.compute_precision);

            % 维度检查
            expected_dim = [config.static.num_snapshots, ...
                            config.static.N_sc, ...
                            config.static.N_tx];
            assert(isequal(size(h), expected_dim), ...
                   'Error: 维度 %s 与预期 %s 不符！', mat2str(size(h)), mat2str(expected_dim));
            
            % 保存当前条件的当前样本
            H_compute_chunk(iter_s, iter_ue, :, :, :) = h;
        end
    end
    
    fprintf('\n');

    H_chunk = cast(H_compute_chunk, config.static.save_precision);
    
    % 文件名
    safe_scen_str = strrep(current_scen_str, '3GPP_38.901_', ''); 
    safe_scen_str = strrep(safe_scen_str, ' ', '_');
    safe_scen_str = strrep(safe_scen_str, '/', '_');
    safe_scen_str = strrep(safe_scen_str, '\', '_');
    safe_scen_str = strrep(safe_scen_str, ':', '_');
    
    chunk_filename = sprintf('cond%03d_data_%s_v%dkmh.mat', cond, safe_scen_str, current_v_kmh);
    chunk_filepath = fullfile(dataset_dir, chunk_filename);
    
    chunk_info = table2struct(task_list(cond, :));
    chunk_info.samples_generated = config.static.samples_per_cond;
    chunk_info.precision = config.static.save_precision;
    
    save(chunk_filepath, 'H_chunk', 'chunk_info', '-v7.3');
    fprintf('\n\n   已保存: %s \n', chunk_filename);
end

%% 保存
master_filepath = fullfile(dataset_dir, 'config_params.mat');
master_info.Total_Conditions = num_conditions;
master_info.Total_Samples = num_conditions * config.static.samples_per_cond;
master_info.Task_List = task_list; 
master_info.Creation_Time = time_stamp;

save(master_filepath, 'config', 'master_info');
fprintf('\n数据集已保存在目录: %s\n', dataset_dir);

%% 函数
function task_table = build_task_grid(sweep_struct)
    % BUILD_TASK_GRID - 动态多维参数网格生成器
    % 输入: sweep_struct，每个字段代表一个扫描维度（该字段的取值列表）
    % 输出: task_table，每一行对应一个扫描组合（笛卡尔积的一点）

    fields = fieldnames(sweep_struct);
    num_dims = length(fields);

    % 无扫描维度：返回空任务表
    if num_dims == 0
        task_table = table();
        return;
    end

    % 对每个维度做规范化，并构造索引域 1..N
    idx_args = cell(1, num_dims);
    for i = 1:num_dims
        fName = fields{i};
        val = sweep_struct.(fName);

        % 文本规范化：统一为 cellstr，避免 table 列赋值的方向/类型歧义
        % char   -> 1x1 cell（cell of char）
        % string -> cellstr 向量（cell of char）
        if ischar(val);   val = {val};        end
        if isstring(val); val = cellstr(val); end

        % 约束：扫描维度必须为标量或一维向量
        assert(isvector(val) || isscalar(val), ...
            'Sweep 参数 "%s" 必须是标量或 1D 向量。', fName);

        % 强制列向量化：消除行/列方向不一致导致的表格行数错误
        sweep_struct.(fName) = val(:);

        % 当前维度的索引集合
        idx_args{i} = 1:length(sweep_struct.(fName));
    end

    % 构造 N 维索引网格（笛卡尔积坐标系）
    grid_out = cell(1, num_dims);
    if num_dims == 1
        grid_out{1} = idx_args{1}(:);
    else
        [grid_out{:}] = ndgrid(idx_args{:});
    end

    % 将索引网格展平并映射回原始取值，生成任务清单表
    task_table = table();
    for i = 1:num_dims
        fName = fields{i};
        orig_values = sweep_struct.(fName);
        flattened_idx = grid_out{i}(:);                 % 展平后的线性索引
        task_table.(fName) = orig_values(flattened_idx);% 保证为 Nx1 列，行数一致
    end
end