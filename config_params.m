function config = config_params()
    % CONFIG_PARAMS - 数据集参数配置
    
    %% 1. 静态参数 (Static) 
    % 仿真参数
    config.static.base_seed = 42;                       % 主种子                                                      
    config.static.samples_per_cond = 1000;              % 每个组合的样本数
    
    config.static.t_step_s = 0.5e-3;                    % 时域采样间隔
    config.static.num_snapshots = 20;                   % 每个样本的时间快照数
    config.static.num_ue = 10;                          % 用户数量
    
    config.static.compute_precision = 'double';         % 仿真精度
    config.static.save_precision = 'single';            % 保存精度
    
    % 信号参数
    config.static.center_freq_Hz = 2.4e9;               % 载波中心频率
    config.static.N_sc = 48;                            % 子载波数量
    config.static.sc_spacing_Hz = 180e3;                % OFDM 子载波间隔
    config.static.bw_Hz = config.static.N_sc ...        % 有效带宽
                        * config.static.sc_spacing_Hz;  
    
    % 拓扑参数
    config.static.bs_height_m = 25;                     % 基站高度 [m]
    config.static.ue_height_m = 1.5;                    % 用户终端高度 [m]
    config.static.ue_center_dist_m = 200;               % 撒点中心距基站的水平距离 [m]
    config.static.ue_drop_radius_min_m = 20;            % 撒点范围：内圈半径 [m]
    config.static.ue_drop_radius_max_m = 50;            % 撒点范围：外圈半径 [m]
    config.static.ue_drop_angle_min_deg = -60;          % 撒点扇区：起始角度 [deg]
    config.static.ue_drop_angle_max_deg = 60;           % 撒点扇区：结束角度 [deg]

    % 天线阵列
    % Tx
    config.static.tx_array_type = '3gpp-mmw';           % 天线类型
    config.static.tx_M = 4;                             % 垂直方向阵子数
    config.static.tx_N = 4;                             % 水平方向阵子数
    config.static.tx_pol = 2;                           % Tx 极化配置
    config.static.tx_tilt = 7;                          % 电下倾角
    config.static.tx_Vspc = 0.5;                        % 垂直阵子间距 (波长)
    config.static.tx_Hspc = 0.5;                        % 水平阵子间距 (波长)
    config.static.tx_Mg = 1;                            % 垂直面板数
    config.static.tx_Ng = 1;                            % 水平面板数
    
    % Rx
    config.static.rx_array_type = '3gpp-mmw';           % 天线类型
    config.static.rx_M = 1;                             % 垂直方向阵子数
    config.static.rx_N = 1;                             % 水平方向阵子数
    config.static.rx_pol = 1;                           % 1 = 垂直单极化, 独立端口
    config.static.rx_tilt = 0;                          % 电下倾角
    config.static.rx_Vspc = 0.5;                        % 垂直阵子间距
    config.static.rx_Hspc = 0.5;                        % 水平阵子间距
    config.static.rx_Mg = 1;                            % 垂直面板数
    config.static.rx_Ng = 1;                            % 水平面板数

    % Tx 端口数
    tx_pol_factor = 2;
    config.static.N_tx = config.static.tx_M * config.static.tx_N * tx_pol_factor * config.static.tx_Mg * config.static.tx_Ng; 
    
    % Rx 端口数
    rx_pol_factor = 1;
    config.static.N_rx = config.static.rx_M * config.static.rx_N * rx_pol_factor * config.static.rx_Mg * config.static.rx_Ng; 
    
    %% 2. 扫描参数 (Sweep)
    % 文本用 Cell {}，数值用数组 []
    config.sweep.scenario = {'3GPP_38.901_UMa_LOS', '3GPP_38.901_UMa_NLOS'};

    config.sweep.velo_kmh = [10, 30, 60, 100];          % 用户速度 [km/h]

end